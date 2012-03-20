package App::Wubot::Reactor;
use Moose;

# VERSION

use Class::Load qw/load_class/;
use Sys::Hostname qw//;

use App::Wubot::Logger;
use App::Wubot::Conditions;

=head1 NAME

App::Wubot::Reactor - runs reactive rules on a message


=head1 SYNOPSIS

    use App::Wubot::Reactor;

    my $reactor = App::Wubot::Reactor->new();

    # run rules on message hash
    $reactor->react( $message_h, $rules_h );

=head1 DESCRIPTION

App::Wubot::Reactor is the 'reactive' component of the wubot project.
Given a message that was generated by a monitor, the reactor walks
through a rule tree, and executes any rules whose conditions evaluate
to true for the message.

=cut

has 'config'     => ( is => 'ro',
                      isa => 'HashRef',
                  );

has 'logger'     => ( is => 'ro',
                      isa => 'Log::Log4perl::Logger',
                      lazy => 1,
                      default => sub {
                          return Log::Log4perl::get_logger( __PACKAGE__ );
                      },
                  );

has 'plugins'    => ( is => 'ro',
                      isa => 'HashRef',
                      default => sub { return {} },
                  );

has 'monitors'   => ( is => 'ro',
                      isa => 'HashRef',
                      default => sub { return {} },
                  );

has 'conditions' => ( is => 'ro',
                      isa => 'App::Wubot::Conditions',
                      lazy => 1,
                      default => sub {
                          return App::Wubot::Conditions->new();
                      }
                  );

# global cache for external rules file contents.  this is shared
# between all objects.
my $cache;

my $hostname = Sys::Hostname::hostname();
$hostname =~ s|\..*$||;

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $rules, $depth )

Given a rule tree, check the condition at the root of the tree against
the message.  If no condition is set in the rule, or if there is a
condition that evaluates as true, the plugin and/or rules defined on
the rule will be evaluated.

This method is recursive.  When a rule fires, if that rule contains a
child 'rules' section, then the react() method will be called to
process the child rules, and the 'depth' will be incremented.  There
is no need to pass in the 'depth' option when calling this method.

If the rule fires, and the 'last_rule' param is set on the rule, then
the 'last_rule' field will be set on the message to prevent any
further rules from being processed.

For more information, see L<App::Wubot::Guide::Rules>.

=cut

sub react {
    my ( $self, $message, $rules, $depth ) = @_;

    return $message if $message->{last_rule};

    $depth = $depth || 1;
    unless ( $rules ) {
        unless ( $self->config ) {
            $self->logger->logconfess( "ERROR: no reactor rules found!" );
        }
        $rules = $self->config->{rules};
    }

  RULE:
    for my $rule ( @{ $rules } ) {

        return $message if $message->{last_rule};

        if ( $rule->{condition} ) {
            next RULE unless $self->conditions->istrue( $rule->{condition}, $message );
        }

        $self->logger->debug( " " x $depth, "- rule matched: $rule->{name}" );

        eval {
            push @{ $message->{wubot_rulelog}->{$hostname} }, $rule->{name};
        };

        if ( $rule->{rules} ) {
            $self->react( $message, $rule->{rules}, $depth+1 );
        }

        if ( $rule->{rulesfile} || $rule->{rulesfile_field} ) {

            my $rulesfile;
            if ( $rule->{rulesfile} ) {
                $rulesfile = $rule->{rulesfile};
            }
            elsif ( $rule->{rulesfile_field} ) {
                $rulesfile = $message->{ $rule->{rulesfile_field} };
                unless ( $rulesfile ) {
                    $self->logger->error( "ERROR: rulesfile_field $rule->{rulesfile_field} not found on message" );
                    next RULE;
                }
            }

            unless ( $cache->{ $rulesfile } ) {
                unless ( -r $rulesfile ) {
                    $self->logger->error( "ERROR: rules file does not exist: $rulesfile" );
                    next RULE;
                }
                $self->logger->warn( "Loading rules file: $rulesfile" );
                my $rules = YAML::XS::LoadFile( $rulesfile );
                $cache->{ $rulesfile } = $rules->{rules};
                $self->logger->debug( "Loaded rules file into cache" );
            }

            $self->logger->debug( "Processing rules in $rulesfile" );
            $self->react( $message, $cache->{ $rulesfile }, $depth+1 );
        }

        if ( $rule->{plugin} ) {
            $message = $self->run_plugin( $rule->{name}, $message, $rule->{plugin}, $rule->{config} );
        }

        if ( $rule->{last_rule} ) {
            $message->{last_rule} = 1;
            $self->logger->debug( " " x $depth, "- last_rule set" );
        }
    }

    return $message;
}


=item initialize_plugin( $plugin )

Given the name of a reactor plugin, load the plugin's class and create
an instance of the plugin.

=cut

sub initialize_plugin {
    my ( $self, $plugin ) = @_;

    return if $self->{plugins}->{ $plugin };

    $self->logger->info( "Creating instance of reactor plugin $plugin" );
    my $reactor_class = join( "::", 'App', 'Wubot', 'Reactor', $plugin );
    load_class( $reactor_class );
    $self->{plugins}->{ $plugin } = $reactor_class->new();

    if ( $self->{plugins}->{ $plugin }->can( "monitor" ) ) {
        $self->monitors->{ $plugin } = 1;
    }

    return 1;
}

=item run_plugin( $rulename, $message, $plugin, $config )

Given a rule name, a message, the plugin class configured on the rule,
and any plugin configuration defined in the rule, call the 'react'
method on the plugin and return the results.

=cut

sub run_plugin {
    my ( $self, $rule, $message, $plugin, $config ) = @_;

    unless ( $message ) {
        $self->logger->logconfess( "ERROR: run_plugin called without a message" );
    }
    unless ( $plugin ) {
        $self->logger->logconfess( "ERROR: run_plugin called without a plugin" );
    }

    unless ( $self->{plugins}->{ $plugin } ) {

        $self->initialize_plugin( $plugin );
    }

    my $return = $self->{plugins}->{ $plugin }->react( $message, $config );

    unless ( $return ) {
        $self->logger->error( "ERROR: plugin $plugin returned no message!" );
    }
    unless ( ref $return eq "HASH" ) {
        $self->logger->error( "ERROR: plugin $plugin returned something other than a message!" );
    }

    return $return;
}

=item find_plugins( $rules )

Recurse through the rule tree to find a list of all unique plugin
classes that are referenced.  This makes it possible to initialize
each plugin without having to wait for a rule that references the
plugin to fire.

This was created for reactor plugins that contain a 'monitor' method
that should be run at regular intervals.  Without initializing the
reactor class on startup, the 'monitor' method would not get called
until a message came through that caused the a rule referencing the
plugin to fire.

=cut

sub find_plugins {
    my ( $self, $rules ) = @_;

    my %plugins;

    for my $rule ( @{ $rules } ) {
        if ( $rule->{plugin} ) {
            $self->logger->debug( "Found rule: $rule->{name}: $rule->{plugin}" );
            $plugins{ $rule->{plugin} } = 1;
        }

        if ( $rule->{rules} ) {
            for my $plugin ( $self->find_plugins( $rule->{rules} ) ) {
                $plugins{ $plugin } = 1;
            }
        }
    }

    my @keys = sort keys %plugins;
    return @keys;
}

=item monitor()

Calls the monitor() method on every reactor plugin referenced in the
rule tree that has a 'monitor' method.

=cut

sub monitor {
    my ( $self ) = @_;

    $self->logger->debug( "Checking reactor monitors" );

    unless ( $self->{initialized_monitors} ) {
        $self->logger->warn( "Initializing monitors" );

        my @plugins = $self->find_plugins( $self->{config}->{rules} );

        for my $plugin ( @plugins ) {
            $self->initialize_plugin( $plugin );
        }

        $self->{initialized_monitors} = 1;
    }

    my @react;

    for my $plugin ( sort keys %{ $self->{monitors} } ) {

        $self->logger->debug( "Checking monitor for $plugin" );
        push @react, $self->{plugins}->{$plugin}->monitor();
    }

    return @react;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

package App::Wubot::Config;
use Moose;

# VERSION

use Sys::Hostname qw();
use YAML::XS;

use App::Wubot::Logger;

has 'hostname' => ( is => 'ro',
                    isa => 'Str',
                    lazy => 1,
                    default => sub {
                        my $hostname = Sys::Hostname::hostname();
                        $hostname =~ s|\..*$||;
                        return $hostname;
                    },
                );

has 'root'   => ( is      => 'ro',
                  isa     => 'Str',
                  required => 1,
              );

has 'config' => ( is      => 'ro',
                  isa     => 'HashRef',
                  default => sub { $_[0]->read_config() },
              );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub read_config {
    my ( $self ) = @_;

    $self->logger->info( "Reading configuration!" );

    my $config = {};

    my $hostname = $self->hostname;

    # monitor plugins
    {
        my $directory = join( "/", $self->root, "plugins" );

        unless ( -d $directory ) {
            die "ERROR: config root directory does not exist: $directory\n";
        }

        my $mod_dir_h;
        opendir( $mod_dir_h, $directory ) or die "Can't opendir $directory: $!";

      MODULES:
        while ( defined( my $plugin = readdir( $mod_dir_h ) ) ) {
            next unless $plugin;
            next if $plugin =~ m|^\.|;

            my $plugin_dir = "$directory/$plugin";

            next unless -d $plugin_dir;

            $self->logger->debug( "Reading plugin directory: $plugin" );

            my $instance_dir_h;

            opendir( $instance_dir_h, $plugin_dir ) or die "Can't opendir $plugin_dir: $!";

            my $instance_count = 0;

          INSTANCE:
            while ( defined( my $instance_entry = readdir( $instance_dir_h ) ) ) {
                next unless $instance_entry;

                next unless $instance_entry =~ m|.yaml(?:\.$hostname)?$|;
                next if -d "$plugin_dir/$instance_entry";
                next if $instance_entry =~ m|^\.|;

                $self->logger->debug( "\tReading instance config: $instance_entry" );

                my $key = join( "-", $plugin, $instance_entry );
                $key =~ s|\.yaml.*$||;

                my $instance_config;
                eval {                          # try
                    $instance_config = YAML::XS::LoadFile( "$plugin_dir/$instance_entry" );
                    1;
                } or do {                       # catch
                    $self->logger->fatal( "ERROR loading: $plugin_dir/$instance_entry\n$@" );
                    next INSTANCE;

                };

                $instance_config->{plugin} = "App::Wubot::Plugin::$plugin";

                $config->{$key} = { file   => $instance_entry,
                                    dir    => $plugin,
                                    config => $instance_config,
                                    key    => $key,
                                };

                $instance_count++;
            }

            if ( $instance_count ) {
                $self->logger->info( "Config: loaded $instance_count instance(s) of $plugin" );
            }

            closedir( $instance_dir_h );
        }

        closedir( $mod_dir_h );
    }

    return $config;
}

sub get_plugins {
    my ( $self ) = @_;

    my @plugins;

    for my $plugin ( sort keys %{ $self->config } ) {

        push @plugins, $self->config->{$plugin}->{key};
    }

    return @plugins;
}

sub get_plugin_config {
    my ( $self, $plugin, $param ) = @_;

    unless ( $self->config->{$plugin} ) {
        die "ERROR: no config found for plugin $plugin";
    }

    unless ( $param ) {
        return $self->config->{$plugin}->{config};
    }

    unless ( $self->config->{$plugin}->{config}->{$param} ) {
        warn "ERROR: config param $param not found for plugin $plugin";
        return;
    }

    return $self->config->{$plugin}->{config}->{$param};
}

1;

__END__


=head1 NAME

App::Wubot::Config - read wubot plugin configuration


=head1 SYNOPSIS

    use App::Wubot::Config

=head1 DESCRIPTION

Reads configuration files for plugins for wubot-monitor from
~/wubot/config/plugins.

Each config file should live in a directory named after the plugin.
For example, the configuration files for the App::Wubot::Plugin::RSS plugin
will be read from ~/wubot/config/plugins/RSS.

Within each plugin directory, any files that end in .yaml will be
read.  The combination of the plugin directory and the filename will
be used to build a unique 'key' for each plugin.  For example, within
the RSS directory, a file named 'slashdot.yaml' would be given the
unique key 'RSS-slashdot'.

In additional to loading all .yaml files in the plugin directory, any
files that end in the short hostname will also be loaded.  For
example, on a host named host1, the file slashdot.yaml.host1 would
also be loaded.  This makes it easy to sync a single configuration
tree between multiple machines, but have some monitors only active on
some machines.  For more information, see also
L<App::Wubot::Guide::MultipleBots>.

=head1 SUBROUTINES/METHODS

=over 8

=item read_config()

Read all plugin configuration files from the config directories and
load all config files ending in .yaml or .yaml.hostname into memory.

Config files are not automatically re-read on change.  It is necessary
to restart wubot-monitor to pick up a plugin configuration change.

=item get_plugins()

Get a list of all plugin instance keys that are configured to run on
the current machine.

=item get_plugin_config( $plugin_key, $param )

Given a plugin key and a config param, return the configuration for
that plugin instance.

=back

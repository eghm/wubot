package App::Wubot::Reactor::Status;
use Moose;

# VERSION

use YAML::XS;

use App::Wubot::Logger;
use App::Wubot::SQLite;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'dbfile' => ( is      => 'rw',
                  isa     => 'Str',
                  lazy    => 1,
                  default => sub {
                      return join( "/", $ENV{HOME}, "wubot", "sqlite", "status.sql" );
                  },
              );

has 'sqlite'  => ( is => 'ro',
                   isa => 'App::Wubot::SQLite',
                   lazy => 1,
                   default => sub {
                       my $self = shift;
                       return App::Wubot::SQLite->new( { file => $self->dbfile } );
                   },
               );

has 'schema'    => ( is => 'ro',
                     isa => 'HashRef',
                     lazy => 1,
                     default => sub {
                         return { key          => 'VARCHAR( 64 )',
                                  status       => 'VARCHAR( 16 )',
                                  status_count => 'INTEGER',
                                  status_since => 'INTEGER',
                                  constraints  => [ 'UNIQUE( key ) ON CONFLICT REPLACE' ],
                              };
                     },
                 );

my %statuses      = ( OK => 1,
                      WARNING => 1,
                      CRITICAL => 1,
                      UNKNOWN => 1,
                  );

my %status_colors = ( CRITICAL => 'red',
                      WARNING  => 'yellow',
                      UNKNOWN  => 'orange',
                  );

my $phi = 0.5 + 0.5 * sqrt(5.0);

sub react {
    my ( $self, $message, $config ) = @_;

    unless ( $message->{status}              ) { $message->{status} = "OK" }
    unless ( $statuses{ $message->{status} } ) { return $message           }

    my $status;
    $status->{key}    = $message->{key};
    $status->{status} = $message->{status};

    # fetch the cached status data for this key
    my ( $cache ) = $self->sqlite->select( { tablename => 'status',
                                             where     => { key => $message->{key} },
                                             schema    => $self->schema,
                                         } );

    if ( $cache->{status} && $status->{status} eq $cache->{status} ) {
        $status->{status_count} = $cache->{status_count} + 1;
        $status->{status_since} = $cache->{status_since};
    }
    else {
        if ( $cache->{status} ) {
            $message->{status_previous} = $cache->{status};
        }
        $status->{status_count} = 1;
        $status->{status_since} = $message->{lastupdate};
    }
    $message->{status_count}    = $status->{status_count};
    $message->{status_since}    = $status->{status_since};

    if (    $message->{subject}
         && $message->{status_count}
         && $message->{status_count} > 1
         && $message->{status} ne "OK"
     ) {

        if ( $self->_is_fibonacci( $message->{status_count} ) ) {
            $message->{subject} = join( " ", $message->{subject}, "[$message->{status_count}x $message->{status}]" );
        }
        else {
            $message->{status_subject} = $message->{subject};
            delete $message->{subject};
        }
    }

    if ( $status_colors{ $message->{status} } ) {
        $message->{color} = $status_colors{ $message->{status} };
    }

    # update the status
    $self->sqlite->insert( 'status',
                           $status,
                           $self->schema
                       );

    return $message;
}

sub _is_fibonacci {
    my ( $self, $number ) = @_;

    # return 1 if $number == 0;

    my $a = $phi * $number;

    my $a_rounded = sprintf("%.0f", $a);

    if ( abs( $a_rounded - $a ) < 1.0 / $number ) {
        return 1;
    }

    return;
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::Wubot::Reactor::Status - keep track of check statuses


=head1 SYNOPSIS

  - name: track status
    plugin: Status


=head1 DESCRIPTION

Monitors the 'status' field of messages, and keeps track of how long
plugin instances have been in a WARNING or CRITICAL state.

If a plugin instance is consistently reporting a problem state,
subject fields will get suppressed.  The Fibonacci sequence is used
for suppression, so notifications are only sent on the 1st, 2nd, 3rd,
5th, 8th, 13th, etc. messages.  On messages where the subject is
suppressed, the subject field will be renamed to status_subject.

When the status is in a problem state, the notification subjects will
also be updated to include the plugin status, and the number of
notifications that have been sent with the notification in that state.
For example:

  CRITICAL: No content retrieved! [21x CRITICAL]

The message color will also be updated to correspond to the status, i.e.:

  CRITICAL: red
  WARNING: yellow
  UNKNOWN: orange

This reactor plugin is brand new in 0.3.8.  More updates will follow.

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back

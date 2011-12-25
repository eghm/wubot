package App::Wubot::Web::Obj::Roles::Obj;
use Moose::Role;

# VERSION

use Date::Manip;
use POSIX qw(strftime);

use App::Wubot::Logger;
use App::Wubot::SQLite;
use App::Wubot::Util::Colors;
use App::Wubot::Util::TimeLength;

has 'id' => ( is => 'ro',
              isa => 'Str',
              lazy => 1,
              default => sub {
                  my $self = shift;
                  return $self->db_hash->{id};
              }
          );

has 'sql'    => ( is      => 'ro',
                  isa     => 'App::Wubot::SQLite',
                  required => 1,
              );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'timelength' => ( is => 'ro',
                      isa => 'App::Wubot::Util::TimeLength',
                      lazy => 1,
                      default => sub {
                          return App::Wubot::Util::TimeLength->new( { space => 1 } );
                      },
                  );

has 'colors'     => ( is => 'ro',
                      isa => 'App::Wubot::Util::Colors',
                      lazy => 1,
                      default => sub {
                          return App::Wubot::Util::Colors->new();
                      },
                  );

has 'color' => ( is => 'ro',
                 isa => 'Str',
                 lazy => 1,
                 default => sub {
                     my $self = shift;
                     return $self->db_hash->{color} || "blue";
                 }
             );

has 'display_color' => ( is => 'ro',
                         isa => 'Str',
                         lazy => 1,
                         default => sub {
                             my $self = shift;
                             return $self->colors->get_color( $self->color );
                         }
                     );

has 'link' => ( is => 'ro',
                isa => 'Maybe[Str]',
                lazy => 1,
                default => sub {
                    my $self = shift;
                    return $self->db_hash->{link};
                }
            );


has 'lastupdate' => ( is => 'ro',
                      isa => 'Str',
                      lazy => 1,
                      default => sub {
                          my $self = shift;
                          return $self->db_hash->{lastupdate};
                      }
                  );

has 'lastupdate_color' => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return $self->color unless $self->age;
                                return $self->timelength->get_age_color( abs( $self->lastupdate - time ) );
                            }
                        );

has 'age' => ( is => 'ro',
               isa => 'Str',
               lazy => 1,
               default => sub {
                   my $self = shift;
                   return unless $self->lastupdate;
                   return $self->timelength->get_human_readable( time - $self->lastupdate );
               }
           );


1;

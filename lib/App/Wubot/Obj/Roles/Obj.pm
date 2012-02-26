package App::Wubot::Obj::Roles::Obj;
use Moose::Role;

# VERSION

use Date::Manip;
use HTML::Strip;
use POSIX qw(strftime);
use Text::Wrap;
use URI::Find;

use App::Wubot::Logger;
use App::Wubot::SQLite;
use App::Wubot::Util::Colors;
use App::Wubot::Util::TimeLength;

requires 'dbfile';


has logger       => ( is => 'ro',
                      isa => 'Log::Log4perl::Logger',
                      lazy => 1,
                      default => sub {
                          return Log::Log4perl::get_logger( __PACKAGE__ );
                      },
                  );

has sql          => ( is      => 'ro',
                      isa     => 'App::Wubot::SQLite',
                      lazy    => 1,
                      default => sub {
                          return App::Wubot::SQLite->new( { file => $_[0]->dbfile } );
                      },
                  );

has 'colors'           => ( is => 'ro',
                            isa => 'App::Wubot::Util::Colors',
                            lazy => 1,
                            default => sub {
                                return App::Wubot::Util::Colors->new();
                            },
                        );

has id            => ( is       => 'ro',
                       isa      => 'Num',
                       lazy     => 1,
                       default  => sub {
                           my $self = shift;
                           my $id;
                           my ( $entry ) = $self->sql->select(
                               { tablename => 'contacts',
                                 field     => 'id',
                                 where     => { username => $self->username },
                             } );

                           return $entry->{id};
                       }
                   );

has display_color => ( is       => 'ro',
                       isa      => 'Str',
                       lazy     => 1,
                       default  => sub {
                           my $self = shift;
                           return $self->colors->get_color( $self->color );
                       }
                   );

1;

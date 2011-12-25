package App::Wubot::Web::Obj::TaskObj;
use Moose;

# VERSION

use Date::Manip;
use POSIX qw(strftime);

use App::Wubot::Logger;
use App::Wubot::SQLite;
use App::Wubot::Util::Taskbot;
use App::Wubot::Util::TimeLength;

has 'taskbot'    => ( is => 'ro',
                      isa => 'App::Wubot::Util::Taskbot',
                      lazy => 1,
                      default => sub {
                          return App::Wubot::Util::Taskbot->new();
                      },
                  );


has 'db_hash' => ( is => 'ro',
                   isa => 'HashRef',
                   lazy => 1,
                   default => sub {
                       my $self = shift;
                       unless ( $self->{taskid} ) {
                           $self->logger->logdie( "ERROR: no data provided and no taskid set" );
                       }
                       my ( $task_h ) = $self->sql->select( { tablename => 'taskbot',
                                                              where     => { taskid => $self->taskid },
                                                          } );
                       return $task_h;
                   },
               );

has 'status' => ( is => 'ro',
                  isa => 'Str',
                  lazy => 1,
                  default => sub {
                      my $self = shift;
                      return $self->db_hash->{status} || "TODO";
                  }
              );


has 'status_pretty' => ( is => 'ro',
                         isa => 'Str',
                         lazy => 1,
                         default => sub {
                             my $self = shift;
                             my $status = $self->status;
                             if ( $status eq "TODO" ) {
                                 my $color = $self->colors->get_color( 'red' );
                                 $status = "<font color='$color'>TODO</font>";
                             }
                             elsif ( $status eq "DONE" ) {
                                 my $color = $self->colors->get_color( 'green' );
                                 $status = "<font color='green'>DONE</font>";
                             }
                             return $status;
                         }
                     );

has 'scheduled' => ( is => 'ro',
                     isa => 'Maybe[Str]',
                     lazy => 1,
                     default => sub {
                         my $self = shift;
                         return $self->db_hash->{scheduled};
                     }
                 );

has 'scheduled_color' => ( is => 'ro',
                           isa => 'Maybe[Str]',
                           lazy => 1,
                           default => sub {
                               my $self = shift;

                               return $self->display_color unless $self->scheduled;

                               my $now = time;

                               if ( $now > $self->scheduled ) {
                                   return $self->colors->get_color( "red" );
                               }

                               return $self->timelength->get_age_color( abs( $now - $self->scheduled ) );
                           }
                       );

has 'scheduled_pretty' => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                my $scheduled = $self->scheduled;
                                return "" unless $scheduled;
                                return strftime( '%Y-%m-%d %H:%M', localtime( $scheduled ) );
                            }
                        );

has 'scheduled_time' => ( is => 'ro',
                          isa => 'Str',
                          lazy => 1,
                          default => sub {
                              my $self = shift;
                              my $scheduled = $self->scheduled;
                              return "" unless $scheduled;
                              return strftime( '%l:%M %p', localtime( $scheduled ) );
                          }
                      );

has 'scheduled_age' => ( is => 'ro',
                         isa => 'Str',
                         lazy => 1,
                         default => sub {
                             my $self = shift;
                             my $scheduled = $self->scheduled;
                             return "" unless $scheduled;
                             return $self->timelength->get_human_readable( time - $scheduled );
                         }
                     );

has 'title' => ( is => 'ro',
                 isa => 'Str',
                 lazy => 1,
                 default => sub {
                     my $self = shift;
                     return $self->db_hash->{title};
                 }
             );

has 'priority' => ( is => 'ro',
                    isa => 'Num',
                    lazy => 1,
                    default => sub {
                        my $self = shift;
                        return $self->db_hash->{priority} || 50;
                    }
                );

has 'priority_display' => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;

                                my $redir = $self->redir;

                                my $link = join( "/", "/taskbot", "item", $self->taskid );
                                $link .= "?redir=$redir&priority";

                                my $link_minus = join( "=", $link, $self->priority - 5 );
                                my $link_plus  = join( "=", $link, $self->priority + 5 );

                                my $return = join( "\n",
                                                   $self->priority,
                                                   "<a href='$link_minus'>-</a>",
                                                   "<a href='$link_plus'>+</a>",
                                               );

                                return $return;
                            }
                        );

has 'category' => ( is => 'ro',
                    isa => 'Maybe[Str]',
                    lazy => 1,
                    default => sub {
                        my $self = shift;
                        return $self->db_hash->{category};
                    }
                );

has 'duration' => ( is => 'ro',
                    isa => 'Maybe[Str]',
                    lazy => 1,
                    default => sub {
                        my $self = shift;
                        return $self->db_hash->{duration};
                    }
                );

has 'recurrence' => ( is => 'ro',
                      isa => 'Maybe[Str]',
                      lazy => 1,
                      default => sub {
                          my $self = shift;
                          return $self->db_hash->{recurrence};
                      }
                  );

has 'body' => ( is => 'ro',
                isa => 'Maybe[Str]',
                lazy => 1,
                default => sub {
                    my $self = shift;

                    return unless $self->taskid;

                    return $self->taskbot->read_body( $self->taskid );
                }
            );

has 'taskid' => ( is => 'ro',
                  isa => 'Maybe[Str]',
                  lazy => 1,
                  default => sub {
                      my $self = shift;
                      return $self->db_hash->{taskid};
                  }
              );

has 'timer' => ( is => 'ro',
                 isa => 'Str',
                 lazy => 1,
                 default => sub {
                     my $self = shift;
                     return "" unless $self->scheduled;
                     return $self->timelength->get_human_readable( $self->scheduled - time );
                 }
              );

has 'redir' => ( is => 'ro',
                 isa => 'Str',
                 default => "list",
             );

has 'timer_color' => ( is => 'ro',
                       isa => 'Str',
                       lazy => 1,
                       default => sub {
                           my $self = shift;
                           return $self->display_color unless $self->scheduled;

                           if ( $self->scheduled < time ) {
                               return $self->colors->get_color( "red" );
                           }

                           return $self->timelength->get_age_color( abs( $self->scheduled - time ) );
                       }
                   );

has 'timer_display' => ( is => 'ro',
                         isa => 'Str',
                         lazy => 1,
                         default => sub {
                             my $self = shift;

                             return "" unless $self->timer;

                             my $redir = $self->redir;

                             my $link = join( "/", "/taskbot", "item", $self->taskid );
                             $link .= "?redir=$redir&scheduled";

                             my $link_minus = join( "=", $link, $self->scheduled - 24*60*60 );
                             my $link_plus  = join( "=", $link, $self->scheduled + 24*60*60 );

                             my $return = join( "\n",
                                                $self->timer,
                                                "<a href='$link_minus'>-</a>",
                                                "<a href='$link_plus'>+</a>",
                                            );

                             return $return;
                         }
                     );

with 'App::Wubot::Web::Obj::Roles::Obj';

1;

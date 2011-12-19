package App::Wubot::Web::Taskbot;
use strict;
use warnings;

# VERSION

use Mojo::Base 'Mojolicious::Controller';

use Data::ICal;
use Data::ICal::Entry::Alarm::Audio;
use Data::ICal::Entry::Alarm::Display;
use Data::ICal::Entry::Event;
use Date::ICal;
use Date::Manip;
use DateTime;
use Digest::MD5 qw( md5_hex );
use File::Path;
use POSIX qw(strftime);
use URI::Escape;
use YAML;

use App::Wubot::Util::Colors;
use App::Wubot::Util::Taskbot;
use App::Wubot::Util::TimeLength;
use App::Wubot::Util::WebUtil;

my $util    = App::Wubot::Util::WebUtil->new( { type => 'taskbot',
                                                idname => 'taskid',
                                                fields => [ qw( cmd color title body status priority duration category recurrence deadline scheduled ) ],
                                            } );

my $taskbot      = App::Wubot::Util::Taskbot->new();
my $colors       = App::Wubot::Util::Colors->new();
my $timelength   = App::Wubot::Util::TimeLength->new( { space => 1 } );

my $task_defaults = { color => 'blue',
                      status => 'TODO',
                      priority => 50,
                  };

sub get_submit_item_postproc {
    my ( $item ) = @_;

    return unless defined $item;

    for my $param ( qw( deadline scheduled ) ) {
        my $value = $item->{$param};
        next unless $value;
        if ( $value =~ m|^\d+$| ) {
            $item->{$param} = $value;
        } else {
            $item->{ $param } = UnixDate( ParseDate( $value ), "%s" );
        }
    }
}

sub get_item_postproc {
    my ( $item, $id ) = @_;

    my $body = $taskbot->read_body( $id );
    if ( $body ) {
        $item->{body} = $body;
    }

    return $item;
}

sub cmd {
    my ( $self, $taskid, $cmdlist ) = @_;

    print "TASKID: $taskid\n";

    my ( $item ) = $util->get_item( $taskid, \&get_item_postproc );

    for my $cmd ( split /\s*,\s*/, $cmdlist ) {

        if ( $cmd =~ m/(\+|\-)(\d+)(\w)/ ) {
            print "Updating task time to $1 $2 $3\n";
            my $seconds = $timelength->get_seconds( "$1$2$3" );
            $item->{scheduled} = time + $seconds;
        }
        elsif ( $cmd =~ m/(\+|\-)\.(\d+)(\w)/ ) {
            print "Updating task time to relative $1 $2 $3\n";
            my $seconds = $timelength->get_seconds( "$1$2$3" );
            $item->{scheduled} = $item->{scheduled} + $seconds;
        }
        elsif ( $cmd =~ m/s\.(.*)/ ) {
            my $time = $1;
            $item->{scheduled} = UnixDate( ParseDate( $time ), "%s" );
        }
        elsif ( $cmd =~ m/p.(\d+)/ ) {
            $item->{priority} = $1;
        }
        elsif ( $cmd =~ m/d.(\d+\w?)/ ) {
            if ( $1 eq "0" ) {
                $item->{duration} = undef;
            }
            else {
                $item->{duration} = $1;
            }
        }
        elsif ( $cmd eq "done" ) {
            $item->{status} = "DONE";
        }
    }

    $util->update_item( $item, $taskid, \&update_task_preproc, $self );
}

sub update_task_preproc {
    my ( $self, $task_h ) = @_;

    if ( $task_h->{status} && $task_h->{status} eq "DONE" ) {

        my ( $task_orig ) = $util->get_item( $task_h->{taskid}, \&get_item_postproc );

        if ( $task_orig->{recurrence} ) {
            $task_h->{status} = "TODO";

            my $next = $timelength->get_seconds( $task_h->{recurrence} );

            if ( $task_orig->{deadline} ) {
                $task_h->{deadline} = $task_orig->{deadline} + $next;
            }
            if ( $task_orig->{scheduled} ) {
                $task_h->{scheduled} = $task_orig->{scheduled} + $next;
            }
        }
    }

    if ( $task_h->{body} ) {
        $taskbot->write_body( $task_h->{taskid}, $task_h->{body} );
    }
}

sub item {
    my $self = shift;

    my $taskid = $self->stash( 'taskid' );

    my $got_item = $util->get_submit_item( $self, \&get_submit_item_postproc, $taskid );

    if ( $got_item ) {
        $util->update_item( $got_item, $taskid, \&update_task_preproc, $self );

        if ( $got_item->{cmd} ) {
            $self->cmd( $taskid, $got_item->{cmd} );
        }

        my $redir = $self->param('redir');
        if ( $redir ) {
            $self->redirect_to( "/taskbot/$redir" );
            return;
        }
        $self->redirect_to( "/taskbot/item/$taskid" );
        return;
    }

    my $now = time;

    # get
    my ( $item ) = $util->get_item( $taskid, \&get_item_postproc );
    $item->{display_color} = $colors->get_color( $item->{color} );

    $item->{lastupdate_color} = $timelength->get_age_color( $now - $item->{lastupdate} );

    if ( $item->{scheduled} ) {
        $item->{scheduled_color} = $timelength->get_age_color( abs( $now - $item->{scheduled} ) );
    }
    else {
        $item->{scheduled_color} = $item->{display_color};
    }

    if ( $item->{deadline} ) {
        $item->{deadline_color} = $timelength->get_age_color( abs( $now - $item->{deadline} ) );
    }
    else {
        $item->{deadline_color} = $item->{display_color};
    }

    $self->stash( item => $item );
    $self->render( template => 'taskbot.item' );
}

sub newtask {
    my $self = shift;

    if ( $self->param( 'title' ) ) {
        $self->create_task();
    }

    my $item = { color    => 'blue',
                 title    => 'insert title',
                 body     => 'insert body',
                 status   => 'TODO',
                 priority => 50,
             };

    $item->{display_color} = $colors->get_color( $item->{color} );

    $self->stash( "item" => $item );

    $self->render( template => 'taskbot.item' );
}

sub create_task {
    my $self = shift;

    my $item = $util->get_submit_item( $self, \&get_submit_item_postproc );

    $self->stash( "item" => $item );

    my $task = $taskbot->create_task( $item );

    $self->redirect_to( "/taskbot/item/$task->{taskid}" );
}

sub tasks {
    my ( $self ) = @_;

    my $params = $self->req->params->to_hash;
    for my $param ( sort keys %{ $params } ) {
        next unless $params->{$param};
        next unless $param =~ m|^cmd_([\w\d\-]+)|;
        my $id = $1;

        my $cmd = $params->{$param};

        $self->cmd( $id, $cmd );
    }

    $self->stash( 'headers', [qw/timer cmd status time dur title launch priority rec category lastupdate/ ] );

    my $now = time;
    my $start = $now + 15*60;

    my @tasks;

    my $query = { tablename => 'taskbot',
                  order     => [ 'deadline', 'scheduled', 'priority DESC', 'lastupdate DESC' ],
                  limit     => 100,
              };

    $query->{where}->{status}    = "TODO";

    my $status = $util->check_session( $self, 'status' );
    if ( $status ) {
        $query->{where}->{status} = uc( $status );
    }

    my $category = $util->check_session( $self, 'category' );
    if ( $category ) {
        $query->{where}->{category} = { LIKE => "%" . $category . "%" };
    }

    my $is_not_null = "IS NOT NULL";

    my $deadline = $util->check_session( $self, 'deadline' );
    if ( $deadline eq "false" ) {
        $query->{where}->{deadline}  = undef;
    }
    elsif ( $deadline eq "true" ) {
        $query->{where}->{deadline}  = \$is_not_null;
    }
    elsif ( $deadline eq "future" ) {
        $query->{where}->{deadline}  = { ">=" => $now };
        $query->{order} = [ 'deadline', 'scheduled', 'priority DESC', 'lastupdate DESC' ];
    }
    elsif ( $deadline eq "past" ) {
        $query->{where}->{deadline}  = { "<=" => $start };
        $query->{order} = [ 'deadline', 'scheduled', 'priority DESC', 'lastupdate DESC' ];
    }

    my $scheduled = $util->check_session( $self, 'scheduled' );
    if ( $scheduled eq "false" ) {
        $query->{where}->{scheduled}  = undef;
    }
    elsif ( $scheduled eq "true" ) {
        $query->{where}->{scheduled}  = \$is_not_null;
        $query->{order} = [ 'scheduled ASC', 'deadline', 'priority DESC', 'lastupdate DESC' ];
    }
    elsif ( $scheduled eq "future" ) {
        $query->{where}->{scheduled}  = { ">=" => $now };
        $query->{order} = [ 'scheduled ASC', 'deadline', 'priority DESC', 'lastupdate DESC' ];
    }
    elsif ( $scheduled eq "past" ) {
        $query->{where}->{scheduled}  = { "<=" => $now };
        $query->{order} = [ 'scheduled ASC', 'deadline', 'priority DESC', 'lastupdate DESC' ];
    }

    $query->{callback} = sub {
        my $task = shift;

        my $age =  $now - $task->{lastupdate};
        $task->{age} = $timelength->get_human_readable( $age );
        $task->{lastupdate_color} = $timelength->get_age_color( $age );

        $task->{timer} = $task->{scheduled} ?
                         $timelength->get_human_readable( $task->{scheduled} - time ) :
                         "";

        $task->{color} = $colors->get_color( $task->{color} );

        if ( ! $task->{scheduled} ) {
            $task->{timer_color} = $task->{color};
        }
        elsif ( $task->{scheduled} > time ) {
            $task->{timer_color} = $timelength->get_age_color( abs( $task->{scheduled} - time ) );
        }
        else {
            $task->{timer_color} = $colors->get_color( "red" );
        }

        if ( $task->{scheduled} ) {
            if ( $now > $task->{scheduled} ) {
                $task->{scheduled_color} = $colors->get_color( "red" );
            }
            else {
                $task->{scheduled_color} = $timelength->get_age_color( abs( $now - $task->{scheduled} ) );
            }
        } else {
            $task->{scheduled_color} = $task->{color};
        }

        if ( $task->{deadline} ) {
            if ( $now > $task->{deadline} ) {
                $task->{deadline_color} = $colors->get_color( "red" );
            }
            else {
                $task->{deadline_color} = $timelength->get_age_color( abs( $now - $task->{deadline} ) );
            }
        } else {
            $task->{deadline_color} = $task->{color};
        }

        push @tasks, $task;
    };

    $taskbot->sql->select( $query );

    $self->stash( body_data => \@tasks );

    $self->render( template => 'taskbot.list' );

}

sub open {
    my $self = shift;

    my $taskid = $self->stash( 'taskid' );

    $taskbot->open( $taskid );

    $self->redirect_to( "/taskbot/item/$taskid" );


}


sub ical {
    my $self = shift;

    my $calendar = Data::ICal->new();

    my $callback = sub {
        my $entry = shift;

        return unless $entry->{duration};

        my @due;

        if ( $entry->{scheduled} ) {
            push @due, $entry->{scheduled};

            if ( $entry->{recurrence} ) {
                my $seconds = $timelength->get_seconds( $entry->{recurrence} );

                for my $count ( 1 .. 3 ) {
                    push @due, $entry->{scheduled} + $seconds;
                }
            }
        }
        else {
            return;
        }

        my $duration = $timelength->get_seconds( $entry->{duration} );

        for my $due ( @due ) {

            my $dt_start = DateTime->from_epoch( epoch => $due );
            my $start    = $dt_start->ymd('') . 'T' . $dt_start->hms('') . 'Z';

            my $dt_end   = DateTime->from_epoch( epoch => $due + $duration );
            my $end      = $dt_end->ymd('') . 'T' . $dt_end->hms('') . 'Z';

            my $id = join "-", 'WUBOT', md5_hex( $entry->{taskid} ), $start;

            my %event_properties = ( summary     => $entry->{title},
                                     dtstart     => $start,
                                     dtend       => $end,
                                     uid         => $id,
                                 );

            if ( $entry->{body} ) {
                $event_properties{description} = $entry->{body};
                utf8::encode( $event_properties{description} );
            }

            my $vevent = Data::ICal::Entry::Event->new();
            $vevent->add_properties( %event_properties );

            if ( $entry->{status} eq "TODO" ) {
                for my $alarm ( 10 ) {

                    my $alarm_time = $due - 60*$alarm;

                    my $valarm_sound = Data::ICal::Entry::Alarm::Audio->new();
                    $valarm_sound->add_properties(
                        trigger   => [ Date::ICal->new( epoch => $alarm_time )->ical, { value => 'DATE-TIME' } ],
                    );
                    $vevent->add_entry($valarm_sound);
                }
            }

            $calendar->add_entry($vevent);
        }
    };

    # last 30 days worth of data
    my $time = time - 60*60*24*30;

    my $select = { tablename => 'taskbot',
                   callback  => $callback,
                   where     => { scheduled => { '>', $time } },
                   order     => 'scheduled',
               };

    if ( $self->param( 'status' ) ) {
        $select->{where} = { status => $self->param( 'status' ) };
    }

    $taskbot->sql->select( $select );

    $self->stash( calendar => $calendar->as_string );

    $self->render( template => 'calendar', format => 'ics', handler => 'epl' );
}


# sub tasks {
#     my $self = shift;

#     my $due = $self->param( 'due' );
#     if ( $due ) {
#         $self->session( due => 1 );
#         $self->redirect_to( "/tasks" );
#     }
#     elsif ( defined $due ) {
#         $self->session( due => 0 );
#         $self->redirect_to( "/tasks" );
#     }
#     else {
#         $due = $self->session( 'due' );
#     }

#     my $tag = $self->param( 'tag' );
#     if ( $tag ) {
#         $self->session( tag => $tag );
#         $self->redirect_to( "/tasks" );
#     }
#     else {
#         $tag = $self->session( 'tag' );
#     }
#     if ( $tag eq "none" ) {
#         undef $tag;
#     }

#     my @tasks = $taskutil->get_tasks( $due, $tag );

#     my $now = time;

#     for my $task ( @tasks ) {

#         $task->{lastupdate_color} = $timelength->get_age_color( $now - $task->{lastupdate} );

#         $task->{lastupdate} = strftime( "%Y-%m-%d %H:%M", localtime( $task->{lastupdate} ) );

#         if ( $colors->get_color( $task->{color} ) ) {
#             $task->{color} = $colors->get_color( $task->{color} );
#             $task->{deadline_color} = $task->{color};
#             $task->{scheduled_color} = $task->{color};
#         }

#         for my $type ( qw( deadline scheduled ) ) {
#             next unless $task->{"$type\_utime"};

#             my $diff = abs( $task->{"$type\_utime"} - $now );
#             if ( $diff < 3600 ) {
#                 $task->{color} = "green";
#             } elsif ( $diff < 900 ) {
#                 $task->{color} = "pink";
#             }
#             $task->{$type} = $task->{"$type\_text"};

#             $task->{"$type\_color"} = $timelength->get_age_color( $now - $task->{"$type\_utime"} );
#         }

#         if ( $task->{duration} ) {
#             $task->{emacs_link} = join( "%20", $task->{duration}, $task->{title} );
#         }
#         else {
#             $task->{emacs_link} = $task->{title};
#         }
#         $task->{emacs_link} =~ s|\/|__SLASH__|g;
#         $task->{emacs_link} = uri_escape( $task->{emacs_link} );
#     }

#     $self->stash( 'headers', [qw/count lastupdate tag file title priority scheduled deadline/ ] );

#     my $tagcolors = { 'null' => 'black', chores => 'blue', work => 'orange', geektank => 'purple' };
#     for my $tag ( keys %{ $tagcolors } ) {
#         $tagcolors->{$tag} = $colors->get_color( $tagcolors->{$tag} );
#     }
#     $self->stash( 'tagcolors', $tagcolors );

#     $self->stash( 'body_data', \@tasks );

#     $self->render( template => 'tasks' );

# }

1;

__END__

=head1 NAME

App::Wubot::Web::Tasks - wubot tasks web interface

=head1 CONFIGURATION

   ~/wubot/config/webui.yaml

    ---
    plugins:
      tasks:
        '/tasks': tasks
        '/ical': ical
        '/open/org/(.file)/(.link)': open


=head1 DESCRIPTION

The wubot web interface is still under construction.  There will be
more information here in the future.

TODO: finish docs

=head1 SUBROUTINES/METHODS

=over 8

=item tasks

Display the tasks web ui.

=item ical

Export tasks as an ical.

=item open

Open the specified file to a specific link in emacs using emacsclient.

=back

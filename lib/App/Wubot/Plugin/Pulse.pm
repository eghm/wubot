package App::Wubot::Plugin::Pulse;
use Moose;

# VERSION

use POSIX qw(strftime);

use App::Wubot::Logger;

with 'App::Wubot::Plugin::Roles::Cache';
with 'App::Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my @messages;

    my $cache = $inputs->{cache} || {};

    my $now = $inputs->{now} || time;

    my $lastupdate = $cache->{lastupdate} || $now;

    # defaults to 1 week, 60 * 24 * 7 = 10080
    my $maxpulses = $inputs->{config}->{max_pulses} || 10080;

    # number of seconds past the current minute
    my $seconds = strftime( "%S", localtime( $now ) );

    # minute
    my $minute = strftime( "%M", localtime( $now ) );

    if ( $cache->{lastminute} && $cache->{lastminute} eq $minute ) {
        $self->logger->info( "Already sent a pulse this minute: $minute" );
        return {};
    }
    $cache->{lastminute} = $minute;

    # the number of minutes that have occurred on the clock since the
    # last notification.

    my $diff = $now - $lastupdate;
    my $minutes_passed = int( $diff / 60 );
    $self->logger->debug( "minutes old: $minutes_passed => $diff diff seconds, $seconds seconds past minute" );

    my @minutes;
    if ( ! $cache->{lastupdate} ) {
        $self->logger->warn( "Pulse: no pulse cache data found, first pulse" );
        @minutes = ( 0 );
        $minutes_passed = 0;
    }
    elsif ( $minutes_passed ) {
        if ( $minutes_passed > 10 ) {
            $self->logger->error( "Minutes since last pulse: $minutes_passed" );
        }
        elsif ( $minutes_passed > 1 ) {
            $self->logger->info( "Minutes since last pulse: $minutes_passed" );
        }

        my $num_pulses = $minutes_passed > $maxpulses ? $maxpulses : $minutes_passed;
        @minutes = reverse ( 0 .. $num_pulses - 1 );

        $self->logger->trace( "updating lastupdate to: ", scalar localtime $now );
    }
    else {
        # we have already sent my the pulse for this minute
        @minutes = ( 0 );
    }

    # set the 'lastupdate' time to be the beginning of the current minute
    $cache->{lastupdate} = $now - $seconds;

    for my $age ( @minutes ) {
        my $pulse_time = $now - $age * 60;

        my $date = strftime( "%Y-%m-%d", localtime( $pulse_time ) );

        my $time = strftime( "%H:%M", localtime( $pulse_time ) );

        #print "Pulse: $date: $time\n";

        my $weekday = lc( strftime( "%A", localtime( $pulse_time ) ) );

        $self->logger->debug( "Sending pulse for: $date $time" );

        my $message = { date => $date,
                        time => $time,
                        day  => $weekday,
                        age  => $age,
                        coalesce => $self->key,
                    };

        push @messages, $message;
    }

    # attempt to sync up pulses with the minute
    my $second = strftime( "%S", localtime() );
    my $delay = 60 - $second;

    return { react => \@messages, cache => $cache, delay => $delay };
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

App::Wubot::Plugin::Pulse - send a message once per minute


=head1 SYNOPSIS

  # The plugin configuration lives here:
  ~/wubot/config/plugins/Pulse/myhostname.yaml

  # There is no actual configuration for this plugin.  All that is
  # needed is that a minimal configuration file exist:
  ---
  enable: 1

  # an example message:

  age: 0
  checksum: ae947857531889e0fb55a517c4e0fc94
  date: 2011-07-31
  day: sunday
  hostname: myhostname
  key: Pulse-myhostname
  lastupdate: 1312158327
  plugin: App::Wubot::Plugin::Pulse
  time: 17:25


=head1 DESCRIPTION


The 'pulse' plugin sends a message once per minute.  The message
contains the following fields:

  date: yyyy-mm-dd
  time: hh:mm
  day: xday

The 'day' field will contain the full weekday name in lower case.

The message can be used within the reactor to trigger jobs to start at
certain times or dates.

Each time the Pulse plugin runs, it will reschedule itself to run
again at the minute change.

There is no guarantee that the pulse will occur on time, but there is
a guarantee that no minutes will be skipped.  When the Pulse plugin
runs, it checks the cache to find the last time it was run.  If any
pulses were missed (e.g. because wubot was not running or was unable
to run the Pulse for a minute), then the Pulse check will immediately
send messages for all the missed minutes.  If the pulse was triggered
late, then the 'age' field on the message will indicate the number of
minutes old that the message was at the time it was generated.  If the
'age' field is false, that indicates that the message was sent during
the minute that was indicated on the message.

=head1 SCHEDULED TASKS

You can trigger a reaction to take place at a specific time by
creating a rule that triggers from the pulse.  The reaction might be
as simple as setting a 'subject' on the pulse message itself so that a
notification occurs (assuming you have reactions set up to perform
notifications for messages with subjects).

  - name: hourly announcements
    condition: key matches ^Pulse AND time matches :00 AND age < 60
    plugin: Template
    config:
      template: the time is {$time}
      target_field: subject

Notice that the condition contains an 'age' field--this is because a
pulse is guaranteed to be delivered for every minute, even if wubot
has not been running for a few days.  Without this condition, if you
start up wubot after it has not been running for a while (or enable
the pulse plugin after it has been disabled for a while) it will spam
you with a notification for every hour since the plugin last ran.
With the condition


=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back

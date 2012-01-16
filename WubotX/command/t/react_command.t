#!/perl
use strict;
use warnings;

use Test::Differences;
use Test::More tests => 33;

use File::Temp qw/ tempdir /;

BEGIN {
    if ( $ENV{HARNESS_ACTIVE} ) {
        $ENV{WUBOT_SCHEMAS} = "config/schemas";
    }
}

use App::Wubot::Logger;
use App::Wubot::Reactor::Command;

my $tempdir  = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
$tempdir .= "/tmp";

my $queuedir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
$queuedir .= "/queue";

my $queuedb = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
$queuedb .= "/commands.sql";

{
    ok( my $command = App::Wubot::Reactor::Command->new( { logdir => $tempdir, queuedb => $queuedb } ),
        "Creating new command reactor object"
    );

    my $pwd = `pwd`;
    chomp $pwd;

    is_deeply( $command->react( { abc => 'xyz' }, { command => 'pwd' } ),
               { command_output => $pwd, command_signal => 0, command_status => 0, abc => 'xyz' },
               "Checking react() run with a configured command"
           );

    is( $command->react( { test => 'pwd' }, { command_field => 'test' } )->{command_output},
        $pwd,
        "Checking react() run with a command from a field"
    );

    is( $command->react( { test => 'pwd' },
                         { command_field => 'test', output_field => 'test_output' }
                     )->{test_output},
        $pwd,
        "Checking react() with specified output field"
    );
}

{
    ok( my $command = App::Wubot::Reactor::Command->new( { logdir => $tempdir, queuedb => $queuedb } ),
        "Creating new command reactor object"
    );

    is_deeply( $command->react( { abc => 'xyz' }, { command => 'false' } ),
               { command_output => '', command_signal => 0, command_status => 1, abc => 'xyz' },
               "Checking react() run with a command that fails"
           );
}

{
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $id = 'forker';

    my $command = App::Wubot::Reactor::Command->new( { logdir => $tempdir, queuedb => $queuedb } );

    my $queue_results_h = $command->react( { foo => 'abc' }, { command => 'sleep 4 && echo finished', fork => $id } );

    is( $queue_results_h->{foo},
        'abc',
        "Checking react() returned original message after forking"
    );

    is( $queue_results_h->{command_queued},
        $id,
        "Checking that command was queued"
    );

    ok( ! $command->monitor(),
        "Calling monitor method to start task, no message sent"
    );

    sleep 3;

    ok( ! $command->monitor(),
        "Calling monitor method while task is still running, no message sent"
    );

    my $lockfile    = join( "/", $command->logdir, "$id.pid" );
    my $logfile     = join( "/", $command->logdir, "$id.log" );
    my $resultsfile = join( "/", $command->logdir, "$id.yaml" );

    ok( -r $lockfile,
        "Checking that pidfile was created"
    );

    ok( -r $logfile,
        "Checking that log file was created"
    );

    sleep 3;

    ok( ! -r $lockfile,
        "Checking that pidfile was removed when process exited"
    );

    # ok( -r $resultsfile,
    #     "Checking that results file was created"
    # );

    my $results_a = $command->monitor();

    is( scalar @{ $results_a },
        1,
        "Calling monitor method got 1 result"
    );

    my ( $results_h ) = @{ $results_a };

    ok( $results_h->{lastupdate},
        "Checking that lastupdate time is set"
    );

    delete $results_h->{lastupdate};

    is_deeply( \$results_h,
               \{ command_output => 'finished',
               command_signal    => 0,
               command_queue     => 'forker',
               command_status    => 0,
               foo               => 'abc',
               subject           => "Command succeeded: $id",
               status            => 'OK',
           },
                     "Checking background command results"
                 );

    ok( ! -r $logfile,
        "Checking that logfile was removed"
    );

    ok( ! -r $resultsfile,
        "Checking that results file was removed"
    );
}

{
    my $id = 'separate';

    my $command = App::Wubot::Reactor::Command->new( { logdir => $tempdir, queuedir => $queuedir, queuedb => $queuedb } );

    my $results1_h = $command->react( { foo => 'abc' }, { command => 'sleep 1 && echo finished1', fork => "$id.1" } );
    my $results2_h = $command->react( { foo => 'def' }, { command => 'sleep 1 && echo finished2', fork => "$id.2" } );

    ok( $results1_h->{command_queued},
        "Checking react() for first process was not queued"
    );

    ok( $results2_h->{command_queued},
        "Checking react() for second process was queued"
    );

    ok( ! $command->monitor(),
        "calling monitor() method to start first command in queue"
    );

    sleep 3;

    my $results3_h = $command->monitor();

    ok( $results3_h->[0]->{lastupdate},
        "Checking that lastupdate field is set in first message"
    );
    ok( $results3_h->[1]->{lastupdate},
        "Checking that lastupdate field is set in second message"
    );

    delete $results3_h->[0]->{lastupdate};
    delete $results3_h->[1]->{lastupdate};

    is_deeply( \$results3_h,
                \[
                   { command_output => 'finished1',
                     command_queue  => 'separate.1',
                     command_signal => 0,
                     command_status => 0,
                     foo            => 'abc',
                     subject        => "Command succeeded: $id.1",
                     status         => 'OK',
                 },
                   { command_output => 'finished2',
                     command_queue  => 'separate.2',
                     command_signal => 0,
                     command_status => 0,
                     foo            => 'def',
                     subject        => "Command succeeded: $id.2",
                     status         => 'OK',
                 },
               ],
               "Checking background command results"
           );
}

{
    ok( my $command = App::Wubot::Reactor::Command->new( { logdir => $tempdir, queuedb => $queuedb, fork => 'cache' } ),
        "Creating new command reactor object"
    );

    my $config = { command_array => [ 'echo', '{$abc}' ], fork => 'commandarray' };

    $command->react( { abc => 'xyz' }, $config );

    ok( ! $command->monitor(),
        "calling monitor() method to start first command in queue"
    );

    sleep 1;

    is_deeply( $command->monitor()->[0]->{command_output},
               "xyz",
               "Checking react() run with a configured_array command"
           );

    $command->react( { abc => 'def' }, $config );

    ok( ! $command->monitor(),
        "calling monitor() method to start first command in queue"
    );

    sleep 1;

    is_deeply( $command->monitor()->[0]->{command_output},
               "def",
               "Checking react() run with a configured_array command"
           );


}

{
    my $tempdir  = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $queuedir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $queuedb = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 ) . "command.sql";

    ok( my $command = App::Wubot::Reactor::Command->new( { logdir => $tempdir, queuedb => $queuedb } ),
        "Creating new command reactor object"
    );

    my $string = 'x \ > \> y';

    ok( $command->react( { abc => "echo $string" }, { command_field => 'abc', fork => 'safechar' } ),
        "Queueing command"
    );

    ok( ! $command->monitor(),
        "calling monitor() method to start first command in queue"
    );

    sleep 1;

    is( $command->monitor()->[0]->{command_output},
        $string,
        "Checking react() removed unsafe characters"
    );



}

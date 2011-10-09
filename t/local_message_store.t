#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Sys::Hostname;
use Test::More 'no_plan';

BEGIN {
    if ( $ENV{HARNESS_ACTIVE} ) {
        $ENV{WUBOT_SCHEMAS} = "config/schemas";
    }
}

use App::Wubot::LocalMessageStore;
use App::Wubot::Logger;

my $hostname = hostname();
$hostname =~ s|\..*$||;

{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                    lastupdate => time,
                    hostname   => $hostname,
                };

    ok( my $messenger = App::Wubot::LocalMessageStore->new(),
        "Creating a new messenger"
    );

    ok( $messenger->store( { %{ $message } }, $directory ),
        "Storing message"
    );

    ok( my $got_message = $messenger->get( $directory ),
        "Retrieving only message in queue"
    );

    is_deeply( $got_message,
               $message,
               "Checking that retrieved message matches sent message"
           );

    is( scalar $messenger->get( $directory ),
        undef,
        "Checking that no messages left in queue"
    );

}


{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                    hostname   => $hostname,
                };

    my $timestamp = time - 10000;

    ok( my $messenger = App::Wubot::LocalMessageStore->new(),
        "Creating a new messenger"
    );

    for my $message_number ( 1 .. 9 ) {

        ok( $messenger->store( { %{ $message, },
                                 number => $message_number,
                                 lastupdate => $timestamp+$message_number*100,
                             }, $directory ),
            "Storing message number $message_number"
        );
    }

    for my $message_number ( 1 .. 9 ) {

        is_deeply( [ scalar $messenger->get( $directory ) ],
                   [ { %{ $message },
                     number     => $message_number,
                     lastupdate => $timestamp+$message_number*100,
                 } ],
                   "Checking retrieved message order sorts properly with different dates"
               );
    }

    is( scalar $messenger->get( $directory ),
        undef,
        "Checking that no messages left in queue"
    );

}


{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                    hostname   => $hostname,
                };

    my $timestamp = time - 10000;

    my $messenger = App::Wubot::LocalMessageStore->new();

    for my $message_number ( 1 .. 19 ) {
        $messenger->store( { %{ $message, },
                             number     => $message_number,
                             lastupdate => $timestamp,
                         }, $directory );
    }

    my @message_order;
    for my $message_number ( 1 .. 19 ) {
        push @message_order, scalar $messenger->get( $directory )->{number};
    }

    is_deeply( [ @message_order ],
               [ 1 .. 19 ],
               "Checking sort order on message in queue where timestamp is identical"
           );
}



{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $messenger = App::Wubot::LocalMessageStore->new();

    is( scalar $messenger->get( $directory ),
        undef,
        "Calling get() when 'new' sub-directory does not exist"
    );

}

# callback to delete message
{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                    lastupdate => time,
                    hostname   => $hostname,
                };

    ok( my $messenger = App::Wubot::LocalMessageStore->new(),
        "Creating a new messenger"
    );

    ok( $messenger->store( { %{ $message } }, $directory ),
        "Storing message"
    );

    {
        ok( my ( $got_message, $callback ) = $messenger->get( $directory ),
            "Retrieving only message in queue with a callback to delete the message"
        );

        is_deeply( $got_message,
                   $message,
                   "Checking that retrieved message matches sent message"
               );
    }

    {
        ok( my ( $got_message, $callback ) = $messenger->get( $directory ),
            "Retrieving message from queue with having used callback to delete message"
        );

        is_deeply( $got_message,
                   $message,
                   "Checking that retrieved message matches sent message"
               );

        ok( $callback->(),
            "Calling callback to delete message from the queue"
        );
    }

    is( scalar $messenger->get( $directory ),
        undef,
        "Checking that no messages left in queue"
    );

}

# message with UTF-8 data
{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                    lastupdate => time,
                    hostname   => $hostname,
                    body       => "foo \x{263A} bar",
                };

    ok( my $messenger = App::Wubot::LocalMessageStore->new(),
        "Creating a new messenger"
    );

    ok( $messenger->store( { %{ $message } }, $directory ),
        "Storing message"
    );

    ok( my $got_message = $messenger->get( $directory ),
        "Retrieving only message in queue"
    );

    is_deeply( $got_message,
               $message,
               "Checking that retrieved message matches sent message"
           );

    is( scalar $messenger->get( $directory ),
        undef,
        "Checking that no messages left in queue"
    );

}



{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                    hostname   => $hostname,
                };

    my $timestamp = time - 10000;

    my $messenger = App::Wubot::LocalMessageStore->new();

    for my $message_number ( 1 .. 19 ) {
        $messenger->store( { %{ $message, },
                             number     => $message_number,
                             lastupdate => $timestamp,
                         }, $directory );

    }

    is_deeply( [ $messenger->get_counts( $directory ) ],
               [ 0, 19, 19 ],
               "Checking message counts"
           );

    for my $message_number ( 1 .. 10 ) {
        my ( $message, $callback ) = $messenger->get( $directory );

        $callback->();
    }

    is_deeply( [ $messenger->get_counts( $directory ) ],
               [ 10, 9, 19 ],
               "Checking message counts"
           );

    sleep 1;

    ok( $messenger->delete_seen( $directory, 24*60*60 ),
        "Deleting messages marked seen that are older than 24 hours old"
    );

    is_deeply( [ $messenger->get_counts( $directory ) ],
               [ 10, 9, 19 ],
               "Checking that there are still 10 messages marked 'seen' in the queue"
           );

    ok( $messenger->delete_seen( $directory ),
        "Deleting messages marked seen older than now"
    );

    is_deeply( [ $messenger->get_counts( $directory ) ],
               [ 0, 9, 9 ],
               "Checking that there are no messages marked 'seen' in the queue"
           );

    for my $message_number ( 1 .. 9 ) {
        my ( $message, $callback ) = $messenger->get( $directory );

        $callback->();
    }

    is_deeply( [ $messenger->get_counts( $directory ) ],
               [ 9, 0, 9 ],
               "Checking that last 9 messages marked 'seen' in the queue"
           );

    sleep 1;

    ok( $messenger->delete_seen( $directory ),
        "Deleting messages marked seen"
    );

    is_deeply( [ $messenger->get_counts( $directory ) ],
               [ 0, 0, 0 ],
               "Checking that there are no messages marked 'seen' in the queue"
           );

}

{
    my $directory = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    my $timestamp = time - 10000;

    my $message = { foo        => 1,
                    checksum   => 1234,
                    key        => 'testcase',
                    hostname   => $hostname,
                    lastupdate => $timestamp,
                };

    my $messenger = App::Wubot::LocalMessageStore->new();

    $messenger->store( { %{ $message, },
                     }, $directory );


    my $sqlite = App::Wubot::SQLite->new( { file => "$directory/queue.sqlite" } );

    my ( $row ) = $sqlite->select( { tablename => 'message_queue' } );

    is( $row->{id},
        1,
        "Checking that 'id' was set to 1 in message_queue table"
    );

    is( $row->{lastupdate},
        $timestamp,
        "Checking that lastupdate column was populated"
    );

    is( $row->{key},
        'testcase',
        "Checking that key column was populated"
    );

}

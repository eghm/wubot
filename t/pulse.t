#!/perl
use strict;

use Test::More tests => 36;

use File::Temp qw/ tempdir /;

use App::Wubot::Logger;
use App::Wubot::Plugin::Pulse;

BEGIN {
    $ENV{TZ} = "America/Los_Angeles";
}


{
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    ok( my $check = App::Wubot::Plugin::Pulse->new( { class      => 'App::Wubot::Plugin::Pulse',
                                                      cache_file => "$tempdir/Pulse.cache.yaml",
                                                      key        => 'Pulse-navi',
                                             } ),
        "Creating a new Pulse check instance"
    );

    {
        ok( my $results_h = $check->check( ),
            "Calling check() method for first check"
        );

        is( scalar @{ $results_h->{react} },
            1,
            "Checking that only one message was sent"
        );

        is( $results_h->{react}->[0]->{age},
            0,
            "Checking that the 'age' field on the message was set to 0, indicating it is now"
        );
    }

    {
        my $time = time - 300;

        ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
            "Calling check() method after 5 minutes of no checks"
        );

        is( scalar @{ $results_h->{react} },
            5,
            "Checking that 5 messages were sent"
        );

        is( $results_h->{react}->[0]->{age},
            4,
            "Checking that the 'age' field on the oldest message is 4"
        );

        is( $results_h->{react}->[1]->{age},
            3,
            "Checking that the 'age' field on the 2nd message is 3"
        );

        is( $results_h->{react}->[2]->{age},
            2,
            "Checking that the 'age' field on the 3rd message is 2"
        );

        is( $results_h->{react}->[3]->{age},
            1,
            "Checking that the 'age' field on the 4th message is 1"
        );

        is( $results_h->{react}->[4]->{age},
            0,
            "Checking that the 'age' field on the message was set to 0, indicating it is now"
        );
    }


    {
        my $time = time;

        ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
            "Calling check() method after 0 minutes of no checks"
        );

        is( scalar @{ $results_h->{react} },
            0,
            "Checking that 0 messages were sent when pulse ran again in the same second"
        );
    }


    {
        my $time = time - 30;

        ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
            "Calling check() method after less than 1 minute since last check"
        );

        is( scalar @{ $results_h->{react} },
            0,
            "Checking that 0 messages were sent when pulse ran again in the same second"
        );
    }


    {
        my $time = time - 59;

        ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
            "Calling check() method 59 seconds since last check"
        );

        is( scalar @{ $results_h->{react} },
            0,
            "Checking that no messages were sent when pulse ran again in 59 seconds"
        );

    }

    {
        my $time = time - 60;

        ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
            "Calling check() method 60 seconds since last check"
        );

        is( scalar @{ $results_h->{react} },
            1,
            "Checking that 1 messages were sent when pulse ran again in 60 seconds"
        );

        is( $results_h->{react}->[0]->{age},
            0,
            "Checking that the 'age' field on the message was set to 0, indicating it is now"
        );
    }

    {
        my $time = time - 61;

        ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
            "Calling check() method 61 seconds since last check"
        );

        is( scalar @{ $results_h->{react} },
            1,
            "Checking that 1 messages were sent when pulse ran again in 61 seconds"
        );

        is( $results_h->{react}->[0]->{age},
            0,
            "Checking that the 'age' field on the message was set to 0, indicating it is now"
        );
    }

    {
        my $time = time - 90;

        ok( my $results_h = $check->check( { cache => { lastupdate => $time } } ),
            "Calling check() method 90 seconds since last check"
        );

        is( scalar @{ $results_h->{react} },
            1,
            "Checking that 1 messages were sent when pulse ran again in 90 seconds"
        );

        is( $results_h->{react}->[0]->{age},
            0,
            "Checking that the 'age' field on the message was set to 0, indicating it is now"
        );
    }
}

# missing time
{
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    ok( my $check = App::Wubot::Plugin::Pulse->new( { class      => 'App::Wubot::Plugin::Pulse',
                                                 cache_file => "$tempdir/Pulse.cache.yaml",
                                                 key        => 'Pulse-navi',
                                             } ),
        "Creating a new Pulse check instance"
    );

    # Fri Aug 26 16:48:40 2011 PDT
    my $time = 1314402471;

    # Fri Aug 26 16:43:40 2011 PDT
    my $cache = { lastupdate => $time - 300 };

    my $check1 = $check->check( { cache => $cache, now => $time - 200 } );
    is( scalar @{ $check1->{react} },
        1,
        "Checking that only pulse was sent"
    );
    is( $check1->{react}->[0]->{time},
        "16:44",
        "Checking 16:44"
    );

    my $check2 = $check->check( { cache => $cache, now => $time - 100 } );
    is( scalar @{ $check2->{react} },
        2,
        "Checking that two pulses were sent"
    );
    is( $check2->{react}->[0]->{time},
        "16:45",
        "Checking 16:45"
    );
    is( $check2->{react}->[1]->{time},
        "16:46",
        "Checking 16:46"
    );

    my $check3 = $check->check( { cache => $cache, now => $time - 30 } );
    is( scalar @{ $check3->{react} },
        1,
        "Checking that two pulses were sent"
    );
    is( $check3->{react}->[0]->{time},
        "16:47",
        "Checking 16:47"
    );
}

# missing times
{
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    ok( my $check = App::Wubot::Plugin::Pulse->new( { class      => 'App::Wubot::Plugin::Pulse',
                                                 cache_file => "$tempdir/Pulse.cache.yaml",
                                                 key        => 'Pulse-navi',
                                             } ),
        "Creating a new Pulse check instance"
    );

    # Fri Aug 26 16:48:40 2011 PDT
    my $time = 1314402471;

    # Fri Aug 26 16:43:40 2011 PDT
    my $cache = { lastupdate => $time - 6000 };

    my @results;

    for my $minute ( reverse ( 0 .. 5999 ) ) {

        my $results = $check->check( { cache => $cache, now => $time - $minute } )->{react};
        next unless $results;

        push @results, @{ $results };

    }

    is( scalar @results,
        100,
        "Checking that 100 pulses were sent over 6000 seconds"
    );

}


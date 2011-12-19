#!/perl
use strict;

use Test::Exception;
use Test::More 'no_plan';

use App::Wubot::Logger;
use App::Wubot::Util::TimeLength;

ok( my $timelength = App::Wubot::Util::TimeLength->new(),
    "Creating a new App::Wubot::Util::TimeLength object"
);

# human readable string in most appropriate units
{
    is( $timelength->get_human_readable( 60 ),
        "1m",
        "Human-readable time for 1 minute"
    );

    is( $timelength->get_human_readable( 90 ),
        "1m30s",
        "Human-readable time for 1.5 minutes"
    );

    is( $timelength->get_human_readable( 60*60 ),
        "1h",
        "Human-readable time for 1 hour"
    );

    is( $timelength->get_human_readable( '1.5h' ),
        "1h30m",
        "Human-readable time for 1.5 hours"
    );

    is( $timelength->get_human_readable( 60*60*1.5 ),
        "1h30m",
        "Human-readable time for 1h 30m"
    );

    is( $timelength->get_human_readable( 60*60*24 ),
        "1d",
        "Human-readable time for 1 day"
    );

    is( $timelength->get_human_readable( 60*60*24*1.5 ),
        "1d12h",
        "Human-readable time for 1.5 days"
    );

    is( $timelength->get_human_readable( 0 ),
        "0s",
        "Human-readable time for 0s"
    );

    is( $timelength->get_human_readable( '0s' ),
        "0s",
        "Human-readable time for 0s"
    );

    is( $timelength->get_human_readable( 's' ),
        "0s",
        "Human-readable time for 0s"
    );

    is( $timelength->get_human_readable( -60 ),
        "-1m",
        "Human-readable time for -1m"
    );

    is( $timelength->get_human_readable( 60*60*24*8 ),
        "1w1d",
        "Human-readable time for 8 days"
    );

    is( $timelength->get_human_readable( 60*60*24*31 ),
        "1M1d",
        "Human-readable time for 1 month and 1 day"
    );

    is( $timelength->get_human_readable( 60*60*24*366 ),
        "1y1d",
        "Human-readable time for 366 days"
    );

    is( $timelength->get_human_readable( 60*60*24*365*20 + 60*60*24*7 ),
        "20y1w",
        "Human-readable time for 20 years and 1 week"
    );


}

# hours
{
    is( $timelength->get_hours( 60 ),
        "0",
        "hours: 1 minute"
    );

    is( $timelength->get_hours( 60*60 ),
        "1",
        "hours: 1 hour"
    );

    is( $timelength->get_hours( 60*60*1.5 ),
        "1.5",
        "hours: 1.5 hours"
    );

    is( $timelength->get_hours( 60*60*24 ),
        "24",
        "hours: 24 hours"
    );



}

# seconds
{
    is( $timelength->get_seconds( 60 ),
        60,
        "seconds: 60 seconds"
    );

    is( $timelength->get_seconds( '1m' ),
        60,
        "seconds: 1m"
    );

    is( $timelength->get_seconds( '+1m' ),
        60,
        "seconds: +1m"
    );

    is( $timelength->get_seconds( '1h' ),
        60*60,
        "seconds: 1h"
    );

    is( $timelength->get_seconds( '1h0m' ),
        60*60,
        "seconds: 1h0m"
    );

    is( $timelength->get_seconds( '1h00m' ),
        60*60,
        "seconds: 1h00m"
    );

    is( $timelength->get_seconds( '1d' ),
        60*60*24,
        "seconds: 1d"
    );

    is( $timelength->get_seconds( '1w' ),
        60*60*24*7,
        "seconds: 1w"
    );

    throws_ok( sub { $timelength->get_seconds( '1x' ) },
               qr/unable to parse time/,
               "Checking that 1x throws 'unable to parse time' exception"
           );

    is( $timelength->get_seconds( -60 ),
        -60,
        "seconds: -60 seconds"
    );

    is( $timelength->get_seconds( '-1m' ),
        -60,
        "seconds: -1m"
    );
}

# rounding
{
    is( $timelength->get_human_readable( 60*60*24*1.5+70 ),
        "1d12h",
        "Human-readable time for 1.5 days, 1 minute, and 10 seconds rounds to nearest hour"
    );

    is( $timelength->get_human_readable( 60*60*12+70 ),
        "12h1m",
        "Human-readable time for 12 hours 1 minute and 10 seconds rounds to nearest minute"
    );

    is( $timelength->get_human_readable( -60*60*24*1.5+70 ),
        "-1d12h",
        "Human-readable time for minus 1.5 days, 1 minute, and 10 seconds rounds to nearest hour"
    );

    is( $timelength->get_human_readable( -60*60*12+70 ),
        "-12h1m",
        "Human-readable time for minus 12 hours 1 minute and 10 seconds rounds to nearest minute"
    );
}


# space
{
    # without space
    {
        ok( my $timelength = App::Wubot::Util::TimeLength->new(),
            "Creating a new App::Wubot::Util::TimeLength object without spaces"
        );

        is( $timelength->get_human_readable( 60*60*12+70 ),
            "12h1m",
            "Human-readable time for 12h1m"
        );

        is( $timelength->get_seconds( "12h1m" ),
            60*60*12+60,
            "Seconds from 12h1m"
        );

        is( $timelength->get_seconds( "12h 1m" ),
            60*60*12+60,
            "Seconds from 12h 1m"
        );
    }

    # with space
    {
        ok( my $timelength = App::Wubot::Util::TimeLength->new( space => 1 ),
            "Creating a new App::Wubot::Util::TimeLength object with spaces"
        );

        is( $timelength->get_human_readable( 60*60*12+70 ),
            "12h 1m",
            "Human-readable time for 12h 1m"
        );

        is( $timelength->get_seconds( "12h1m" ),
            60*60*12+60,
            "Seconds from 12h1m"
        );

        is( $timelength->get_seconds( "12h 1m" ),
            60*60*12+60,
            "Seconds from 12h 1m"
        );
    }
}

{
    # map
    is( $timelength->_range_map( 10, 0, 100, 0, 1000 ),
        100,
        "calling map of 10 from 0..100 to 0..1000"
    );

    is( $timelength->_range_map( 10, 0, 100, 100, 200 ),
        110,
        "calling map of 10 from 0..100 to 100..200"
    );

    is( $timelength->_range_map( 10, 0, 100, 0, -100 ),
        -10,
        "calling map of 10 from 0..100 to 0..-100"
    );

    is( $timelength->_range_map( 10, 0, 100, 1000, 2000 ),
        1100,
        "calling map of 10 from 0..100 to 1000..2000"
    );

    is( $timelength->_range_map( 10, 0, 100, 10, 20 ),
        11,
        "calling map of 10 from 0..100 to 10..20"
    );

    is( $timelength->_range_map( 20, 10, 110, 40, 50 ),
        41,
        "calling map of 20 from 20..110 to 40..50"
    );

}

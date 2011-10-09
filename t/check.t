#!/perl
use strict;

use Test::More tests => 34;

use File::Temp qw/ tempdir /;
use Test::Differences;
use YAML::XS;

BEGIN {
    if ( $ENV{HARNESS_ACTIVE} ) {
        $ENV{WUBOT_SCHEMAS} = "config/schemas";
    }
}

use App::Wubot::Logger;
use App::Wubot::Check;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
my $cache_file = "$tempdir/storage.yaml";

{
    ok( my $check = App::Wubot::Check->new( { class      => 'App::Wubot::Plugin::TestCase',
                                              cache_file => $cache_file,
                                              key        => 'TestCase-testcase',
                                          } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { param1 => 'value1' } ),
        "Calling check() method and passing test config"
    );

    is( $results->{cache}->{param1},
        'value1',
        "Checking that check param set in cache data"
    );

    is( $results->{react}->[0]->{param1},
        'value1',
        "Checking that check param set in result data"
    );

    ok( my $cache = YAML::XS::LoadFile( $cache_file ),
        "Reading check cache file"
    );

    is( $cache->{param1},
        'value1',
        "Checking that check data was written to cache file"
    );
}

{
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    ok( my $check = App::Wubot::Check->new( { class             => 'App::Wubot::Plugin::TestCase',
                                              cache_file        => $cache_file,
                                              key               => 'TestCase-testcase',
                                              reactor_queue_dir => $tempdir,
                                          } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { param2 => 'value2', param3 => 'value3' } ),
        "Calling check() method and passing new config"
    );
    is( $results->{cache}->{param1},
        'value1',
        "Checking that param1 is still set in cache data"
    );
    is( $results->{cache}->{param2},
        'value2',
        "Checking that param2 set in cache data"
    );
    is( $results->{cache}->{param3},
        'value3',
        "Checking that param3 set in cache data"
    );
    is( $results->{react}->[0]->{param2},
        'value2',
        "Checking that param2 set in result hash"
    );
    is( $results->{react}->[0]->{param3},
        'value3',
        "Checking that param3 set in result hash"
    );

    ok( my $cache = YAML::XS::LoadFile( $cache_file ),
        "Reading check cache file"
    );
    is( $cache->{param1},
         'value1',
         'Checking that param1 still exists in cache file'
     );
    is( $cache->{param2},
         'value2',
         'Checking that param2 exists in cache file'
     );
    is( $cache->{param3},
         'value3',
         'Checking that param3 exists in cache file'
     );

    my $queue_contents = $check->reactor_queue->get( $tempdir );
    is( $queue_contents->{param2},
        "value2",
        "Checking that param1 set to value1 in queue"
    );
    is( $queue_contents->{param3},
        "value3",
        "Checking that param1 set to value1 in queue"
    );
    is( $queue_contents->{key},
        "TestCase-testcase",
        "Checking key from queue contents"
    );

    ok( exists $queue_contents->{checksum},
        "Checking that checksum found in message: $queue_contents->{checksum}"
    );

}



{
    my $react = [ { name => 'test reaction',
                    plugin => 'SetField',
                    config => {
                        field => 'abc',
                        value => 'xyz',
                    },
                },
              ];
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    ok( my $check = App::Wubot::Check->new( { class             => 'App::Wubot::Plugin::TestCase',
                                              cache_file        => $cache_file,
                                              key               => 'TestCase-testcase',
                                              reactor_queue_dir => $tempdir,
                                          } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { testparam => 'testvalue',
                                       react     => $react,
                                   },  ),
        "Calling check() method and passing new config"
    );
    is( $results->{cache}->{testparam},
        'testvalue',
        "Checking that param1 is still set in cache data"
    );
    is( $results->{react}->[0]->{testparam},
        'testvalue',
        "Checking that testparam set to testvalue"
    );
    is( $results->{react}->[0]->{abc},
        'xyz',
        "Checking that reactor config set 'abc' to 'xyz'"
    );

    my $queue_contents = $check->reactor_queue->get( $tempdir );
    is( $queue_contents->{testparam},
        "testvalue",
        "Checking that testparam message added to queue"
    );

}

{
    my $react = [ { name => 'last rule reaction',
                    last_rule => 1,
                },
              ];
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    ok( my $check = App::Wubot::Check->new( { class             => 'App::Wubot::Plugin::TestCase',
                                              cache_file        => $cache_file,
                                              key               => 'TestCase-testcase',
                                              reactor_queue_dir => $tempdir,
                                          } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { testparam => 'testvalue',
                                       react     => $react,
                                   },  ),
        "Calling check() method and passing new config"
    );

    ok( $results->{react}->[0]->{last_rule},
        "Checking that last_rule field in rule sets last_rule field in reaction"
    );
}

# status
{
    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    ok( my $check = App::Wubot::Check->new( { class             => 'App::Wubot::Plugin::TestCase',
                                              cache_file        => $cache_file,
                                              key               => 'TestCase-testcase',
                                              reactor_queue_dir => $tempdir,
                                          } ),
        "Creating a new check instance"
    );

    ok( my $results = $check->check( { die => 1 } ),
        "Calling check() method with 'die' param set"
    );

    is( $results->{react}->{status},
        'CRITICAL',
        "Checking that check status is CRITICAL when plugin calls 'die'"
    );

    is( $results->{react}->{subject},
        "CRITICAL: Testing Error",
        "Checking that subject contains error message"
    );

}

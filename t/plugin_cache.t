#!/perl
use strict;

use File::Temp qw/ tempdir /;
use LWP::Simple;
use Test::More 'no_plan';
use YAML::XS;

use App::Wubot::Logger;
use App::Wubot::Plugin::TestCase;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

my $class = "TestCase";

{
    my $key = "$class-one";
    my $cache_file = "$tempdir/$key.yaml";

    ok( my $test = App::Wubot::Plugin::TestCase->new( { key        => $key,
                                                        class      => $class,
                                                        cache_file => $cache_file,
                                                        reactor    => sub {},
                                                    } ),
        "Creating a new testcase object"
    );

    ok( $test->get_cache(),
        "Checking the get_cache() method with no previous cache data"
    );

    is_deeply( $test->get_cache(),
               {},
               "Checking that cache data is empty"
           );


}

{
    my $key = "$class-two";
    my $cache_file = "$tempdir/$key.yaml";
    my $fake_cache_data = { test => 1, abc => 'xyz' };

    YAML::XS::DumpFile( $cache_file, $fake_cache_data );

    ok( my $test = App::Wubot::Plugin::TestCase->new( { key        => $key,
                                                        class      => $class,
                                                        cache_file => $cache_file,
                                                        reactor    => sub {},
                                                    } ),
        "Creating a new testcase object"
    );

    ok( $test->get_cache(),
        "Checking the get_cache() method with previous cache data"
    );

    is_deeply( $test->get_cache(),
               $fake_cache_data,
               "Checking that cache data was read"
           );


}

{
    my $key = "$class-three";
    my $cache_file = "$tempdir/$key.yaml";

    open(my $fh, ">", $cache_file)
        or die "Couldn't open $cache_file for writing: $!\n";
    print $fh "---\na: b\n  c: d";
    close $fh or die "Error closing file: $!\n";

    ok( -r $cache_file,
        "Checking that fake corrupted cache file was written"
    );

    ok( my $test = App::Wubot::Plugin::TestCase->new( { key        => $key,
                                                        class      => $class,
                                                        cache_file => $cache_file,
                                                        reactor    => sub {},
                                                    } ),
        "Creating a new testcase object"
    );

    ok( $test->get_cache(),
        "Checking the get_cache() method with broken cache file"
    );

    is_deeply( $test->get_cache(),
               {},
               "Checking that empty cache data being used"
           );


}


# {
#     my $key = "$class-four";
#     my $cache_file = "$tempdir/$key.yaml";

#     ok( my $test = App::Wubot::Plugin::TestCase->new( { key        => $key,
#                                                    class      => $class,
#                                                    cache_file => $cache_file,
#                                                } ),
#         "Creating a new testcase object"
#     );

#     my $content = get( 'http://epguides.com/Futurama/' );

#     ok( $content,
#         "Checking that test content was retrieved"
#     );

#     my $cache_data = {};

#     for my $line ( split /\n/, $content ) {
#         next unless $line =~ m|^\d+\s+\d+\-\d+\s+\S+\s+\S+\s+(.*)|;

#         $test->cache_mark_seen( $cache_data, $1 );
#         print "Marking seen: $1\n";
#     }

#     ok( $test->write_cache( $cache_data ),
#         "Writing out cache data"
#     );

#     ok( $test->read_cache(),
#         "Checking the read_cache() method"
#     );

#     is_deeply( $test->read_cache(),
#                $cache_data,
#                "Checking read_cache returned our cache data"
#            );

#     system( "cat $cache_file" );


# }


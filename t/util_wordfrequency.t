#!/perl
use strict;
use warnings;

use Test::More;
use Test::Routine;
use Test::Routine::Util;

use File::Temp qw/ tempdir /;
use YAML;

BEGIN {
    if ( $ENV{HARNESS_ACTIVE} ) {
        $ENV{WUBOT_SCHEMAS} = "config/schemas";
    }
}

use App::Wubot::Logger;
use App::Wubot::Util::WordFrequency;

has util => (
    is   => 'ro',
    lazy => 1,
    clearer => 'reset_util',
    default => sub {
        my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
        App::Wubot::Util::WordFrequency->new( dbfile => "$tempdir/test.sql" );
    },
);

test "count_words" => sub {
    my ($self) = @_;

    is_deeply( $self->util->count_words( 'aaa aba aaa abb abc aaa' ),
               { aaa => 3,
                 aba => 1,
                 abb => 1,
                 abc => 1,
             },
               "Counting word frequency of a simple string"
           );

    is_deeply( $self->util->count_words( 'aaa ab1 aaa ab1' ),
               { aaa => 2,
                 ab1 => 2,
             },
               "Counting word frequency with some words containing numbers"
           );

    is_deeply( $self->util->count_words( 'Aaa aaa' ),
               { aaa => 2,
             },
               "Counting word frequency with some words in different cases"
           );

    is_deeply( $self->util->count_words( 'Aaa; aa-a a.a.a' ),
               { aaa => 3,
             },
               "Counting word frequency with some words containing special characters"
           );

    is_deeply( $self->util->count_words( 'aaa aaa', 'aaa' ),
               { aaa => 3,
             },
               "Counting word frequency for multiple strings"
           );

};

test "count_words with skip words" => sub {
    my ($self) = @_;

    is_deeply( $self->util->count_words( 'now is the time' ),
               { now  => 1,
                 time => 1,
             },
               "Counting word frequency skips words the 'the' and 'is'"
           );

    is_deeply( $self->util->count_words( 'now 1 12 123' ),
               { now  => 1,
                 123  => 1,
             },
               "Counting word frequency skips single and double-digit numbers"
           );
};

test 'store and fetch_word with a single document' => sub {
    my $self = shift;

    $self->reset_util;

    is( $self->util->store( 'test', { aaa => 1, bbb => 2 } ),
        2,
        "Storing 2 words for 'test' key"
    );

    is_deeply( $self->util->fetch_word( 'aaa' ),
               { test => 1 },
               "Checking that 'aaa' count was 1"
           );

    is_deeply( $self->util->fetch_word( 'bbb' ),
               { test => 2 },
               "Checking that 'bbb' count was 2"
           );

    is_deeply( $self->util->fetch_word( 'abc' ),
               undef,
               "Checking for word that did not exist in document"
           );

};

test 'store and fetch_word with multiple documents' => sub {
    my $self = shift;

    $self->reset_util;

    is( $self->util->store( 'test1', { aaa => 1, bbb => 2, ccc => 1 } ),
        3,
        "Storing 3 words for 'test1' key"
    );

    is( $self->util->store( 'test2', { aaa => 1, bbb => 2, ddd => 3 } ),
        3,
        "Storing 3 words for 'test2' key"
    );

    is_deeply( $self->util->fetch_word( 'aaa' ),
               { test1 => 1, test2 => 1 },
               "Checking that 'aaa' was found in both documents"
           );

    is_deeply( $self->util->fetch_word( 'bbb' ),
               { test1 => 2, test2 => 2 },
               "Checking that 'bbb' count found in both documents"
           );

    is_deeply( $self->util->fetch_word( 'ccc' ),
               { test1 => 1 },
               "Checking that 'ccc' count was 1, only in one document"
           );

    is_deeply( $self->util->fetch_word( 'ddd' ),
               { test2 => 3 },
               "Checking that 'ddd' count was 3, only in one document"
           );

};

test 'get similar documents' => sub {
    my $self = shift;

    $self->reset_util;

    is( $self->util->store( 'test1', { aaa => 1, bbb => 2, ccc => 1 } ),
        3,
        "Storing 3 words for 'test1' key"
    );

    is( $self->util->store( 'test2', { bbb => 1, ccc => 1, ddd => 1 } ),
        3,
        "Storing 3 words for 'test2' key"
    );

    is_deeply( $self->util->get_similar( { aaa => 1 } ),
               { test1 => 1 },
               'Checking document that contains a word only found in test1'
           );

    is_deeply( $self->util->get_similar( { ddd => 1 } ),
               { test2 => 1 },
               "Checking document that contains a word only found in test2"
           );

    is_deeply( $self->util->get_similar( { ccc => 1 } ),
               { test1 => 1, test2 => 1 },
               "Checking document that contains a word found in both documents"
           );

    is_deeply( $self->util->get_similar( { bbb => 2, ccc => 1 } ),
               { test1 => 2, test2 => 2 },
               "Checking document that contains multiple words found in both documents"
           );

    is_deeply( $self->util->get_similar( { bbb => 2, ccc => 1, ddd => 1 } ),
               { test1 => 2, test2 => 3 },
               "Checking document that contains 2 matches in test1 and 3 in test2"
           );

};

test 'fetch_words_from_key' => sub {
    my $self = shift;

    $self->reset_util;

    my $test1 = { aaa => 1, bbb => 2, ccc => 1 };

    is( $self->util->store( 'test1', $test1 ),
        3,
        "Storing 3 words for 'test1' key"
    );

    is_deeply( $self->util->fetch_words_from_key( 'test1' ),
               $test1,
               "Fetching test1 words"
           );

    my $test2 = { aaa => 1, bbb => 2, ddd => 3 };
    is( $self->util->store( 'test2', $test2 ),
        3,
        "Storing 3 words for 'test2' key"
    );

    is_deeply( $self->util->fetch_words_from_key( 'test1' ),
               $test1,
               "Fetching test1 words"
           );

    is_deeply( $self->util->fetch_words_from_key( 'test2' ),
               $test2,
               "Fetching test2 words"
           );

};

test 'store and fetch_word with a single document and one tag' => sub {
    my $self = shift;

    $self->reset_util;

    is( $self->util->store( 'test1', { aaa => 1, bbb => 2 }, 'foo' ),
        2,
        "Storing 2 words for 'test1' key"
    );

    is_deeply( $self->util->fetch_words_from_tag( 'foo' ),
               { aaa => 1, bbb => 2 },
               "Fetching words with tag 'foo'"
           );

};

test 'store and fetch_word with a multiple documents and one tag' => sub {
    my $self = shift;

    $self->reset_util;

    is( $self->util->store( 'test1', { aaa => 1, bbb => 2 }, 'foo' ),
        2,
        "Storing 2 words for 'test1' key"
    );

    is_deeply( $self->util->fetch_words_from_tag( 'foo' ),
               { aaa => 1, bbb => 2 },
               "Fetching words with tag 'foo'"
           );

    is( $self->util->store( 'test2', { aaa => 1, ccc => 1 }, 'foo' ),
        2,
        "Storing 2 words for 'test2' key"
    );

    is_deeply( $self->util->fetch_words_from_tag( 'foo' ),
               { aaa => 2, bbb => 2, ccc => 1 },
               "Fetching words with tag 'foo'"
           );

};

test 'store and fetch_word with a multiple documents and multiple tags' => sub {
    my $self = shift;

    $self->reset_util;

    is( $self->util->store( 'test1', { aaa => 1, bbb => 2 }, 'foo' ),
        2,
        "Storing 2 words for 'test1' key"
    );

    is( $self->util->store( 'test2', { aaa => 1, ccc => 1 }, 'foo' ),
        2,
        "Storing 2 words for 'test2' key"
    );

    is( $self->util->store( 'test3', { aaa => 1, ccc => 1 }, 'bar' ),
        2,
        "Storing 2 words for 'test3' key and 'bar' tag"
    );

    is_deeply( $self->util->fetch_words_from_tag( 'foo' ),
               { aaa => 2, bbb => 2, ccc => 1 },
               "Fetching words with tag 'foo' - no change in counts"
           );


};

test 'get list and counts of tags' => sub {
    my $self = shift;

    $self->reset_util;

    $self->util->store( 'test1', { aaa => 1, bbb => 1 }, 'foo' );

    is_deeply( [ $self->util->get_all_tags() ],
               [ 'foo' ],
               "Getting one tag with one doc"
           );

    is( $self->util->get_tagged_item_count( 'foo' ),
        1,
        "Checking that 1 item tagged 'foo'"
    );

    $self->util->store( 'test2', { aaa => 1, bbb => 1 }, 'foo' );

    is_deeply( [ $self->util->get_all_tags() ],
               [ 'foo' ],
               "Getting one tag with two doc"
           );

    is( $self->util->get_tagged_item_count( 'foo' ),
        2,
        "Checking that 2 items tagged 'foo'"
    );

    $self->util->store( 'test3', { aaa => 1, bbb => 1 }, 'bar' );

    is_deeply( [ $self->util->get_all_tags() ],
               [ 'bar', 'foo' ],
               "Getting two tags from three docs"
           );

    is( $self->util->get_tagged_item_count( 'foo' ),
        2,
        "Checking that 2 items tagged 'foo'"
    );

    is( $self->util->get_tagged_item_count( 'bar' ),
        1,
        "Checking that 1 item tagged 'bar'"
    );

    is( $self->util->get_tagged_item_count( 'baz' ),
        0,
        "Checking that 0 items tagged 'baz'"
    );

};

test 'get_num_words' => sub {
    my $self = shift;

    $self->reset_util;

    $self->util->store( 'test1', { aaa => 1, bbb => 1 }, 'foo' );

    is( $self->util->get_num_words(),
        2,
        "Checking that total number of words is 2"
    );
};


test 'multiple stores and fetch_word with a single document and one tag' => sub {
    my $self = shift;

    $self->reset_util;

    is( $self->util->store( 'test1', { aaa => 1, bbb => 2, ccc => 1 }, 'foo' ),
        3,
        "Storing 3 words for 'test1' key"
    );

    is( $self->util->store( 'test1', { ccc => 2, ddd => 1 }, 'foo' ),
        2,
        "Storing 2 words with changes for 'test1' key"
    );

    is_deeply( $self->util->fetch_words_from_tag( 'foo' ),
               { ccc => 2, ddd => 1 },
               "Fetching words with tag 'foo' gets most recently inserted test1"
           );

    is_deeply( $self->util->fetch_words_from_tag( '_TOTAL_' ),
               { ccc => 2, ddd => 1 },
               "Fetching words with tag '_TOTAL_' gets most recently inserted test1"
           );
};

# todo remove tags

test 'spam tag stats' => sub {
    my $self = shift;

    $self->reset_util;

    $self->util->store( 'test1', { offer => 1, is => 1, secret => 1 }, 'spam' );
    $self->util->store( 'test2', { click => 1, secret => 1, link => 1 }, 'spam' );
    $self->util->store( 'test3', { secret => 1, sports => 1, link => 1 }, 'spam' );

    $self->util->store( 'test4', { play => 1, sports => 1, today => 1 }, 'ham' );
    $self->util->store( 'test5', { went => 1, play => 1, sports => 1 }, 'ham' );
    $self->util->store( 'test6', { secret => 1, sports => 1, event => 1 }, 'ham' );
    $self->util->store( 'test7', { sports => 1, is => 1, today => 1 }, 'ham' );
    $self->util->store( 'test8', { sports => 1, costs => 1, money => 1 }, 'ham' );

    is_deeply( $self->util->get_tag_suggestions( { today => 1, is => 1, secret => 1 } ),
               { spam => .48576, ham => 0.51424 },
               "Getting tag suggestions"
           );
};


run_me;
done_testing;

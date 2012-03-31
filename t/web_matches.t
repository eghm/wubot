#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Test::MockObject;
use Test::More;
use Test::Routine;
use Test::Routine::Util;

use App::Wubot::Logger;
use App::Wubot::Plugin::WebMatches;;

my $mock_fetcher = Test::MockObject->new();
undef $/;
my $content = <DATA>;
$mock_fetcher->mock( 'fetch',
                     sub { return $content } );

has check => (
    is   => 'ro',
    lazy => 1,
    clearer => 'reset_check',
    default => sub {
        my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

        return App::Wubot::Plugin::WebMatches->new( { class      => 'App::Wubot::Plugin::WebMatches',
                                                      cache_file => "$tempdir/test.cache",
                                                      key        => 'WebMatches-testcase',
                                                      fetcher    => $mock_fetcher,
                                                      reactor    => sub {},
                                                  } );
    },
);


test "matches once times" => sub {
    my ($self) = @_;

    $self->reset_check; # this test requires a fresh one

    is_deeply( $self->check->check( { config => { url => undef, regexp => '(ghi)' } } )->{react},
               [ { link => undef, match => 'ghi' } ],
               "Running test with regexp that matches once"
           );
};

test "matches multiple times" => sub {
    my ($self) = @_;

    $self->reset_check; # this test requires a fresh one

    is_deeply( $self->check->check( { config => { url => undef, regexp => '(abc)' } } )->{react},
               [ { link => undef, match => 'abc' }, { link => undef, match => 'abc' } ],
               "Running test with regexp that matches twice"
           );
};

test "multiline regexp" => sub {
    my ($self) = @_;

    $self->reset_check; # this test requires a fresh one

    is_deeply( $self->check->check( { config => { url => undef, regexp => '^(abc)$' } } )->{react},
               [ { link => undef, match => 'abc' }, { link => undef, match => 'abc' } ],
               "Running test with regexp that uses default multi-line modifier"
           );

};

test "single line regexp modifier" => sub {
    my ($self) = @_;

    $self->reset_check; # this test requires a fresh one

    is_deeply( $self->check->check( { config => { url => undef, regexp => '^(abc)', modifier_s => 1 } } )->{react},
               [ { link => undef, match => 'abc' } ],
               "Running test with regexp that uses 's' modifier"
           );

};

run_me;
done_testing;

__DATA__
abc
def
ghi
abc
def

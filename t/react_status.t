#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More;
use Test::Routine;
use Test::Routine::Util;

use App::Wubot::Logger;
use App::Wubot::Reactor::Status;

has fixture => (
    is   => 'ro',
    lazy => 1,
    clearer => 'reset_fixture',
    default => sub {
        my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
        return App::Wubot::Reactor::Status->new( { dbfile => "$tempdir/status.sql" } );
    },
);

test "initial status" => sub {
    my ($self) = @_;

    $self->reset_fixture;

    my $now = time;

    is_deeply( $self->fixture->react( { key => 'abc', status => 'OK', lastupdate => $now },
                                      {}
                                  ),
               { key => 'abc', status => 'OK', lastupdate => $now, status_since => $now, status_count => 1 },
               "Running Status reactor on a message with initial status OK"
           );
};

test "default status is OK" => sub {
    my ($self) = @_;

    $self->reset_fixture;

    my $now = time;

    is_deeply( $self->fixture->react( { key => 'abc', lastupdate => $now },
                                      {}
                                  ),
               { key => 'abc', status => 'OK', lastupdate => $now, status_since => $now, status_count => 1 },
               "Running Status reactor on a message with no status defaults to OK"
           );
};

test "repeated status OK" => sub {
    my ($self) = @_;

    $self->reset_fixture;

    my $first = time;

    is_deeply( $self->fixture->react( { key => 'abc', status => 'OK', lastupdate => $first },
                                      {}
                                  ),
               { key => 'abc', status => 'OK', lastupdate => $first, status_since => $first, status_count => 1 },
               "Running Status reactor on a message with initial status OK"
           );

    sleep 1;

    my $second = time;

    is_deeply( $self->fixture->react( { key => 'abc', status => 'OK', lastupdate => $second },
                                      {}
                                  ),
               { key => 'abc', status => 'OK', lastupdate => $second, status_since => $first, status_count => 2 },
               "Running Status reactor on a message with initial status OK"
           );
};

test "initial warning status" => sub {
    my ($self) = @_;

    $self->reset_fixture;

    my $now = time;

    is_deeply( $self->fixture->react( { key => 'abc', status => 'WARNING', lastupdate => $now },
                                      {}
                                  ),
               { key          => 'abc',
                 status       => 'WARNING',
                 lastupdate   => $now,
                 status_since => $now,
                 status_count => 1,
                 color        => 'yellow',
             },
               "Running Status reactor on a message with initial status WARNING"
           );
};

test "initial critical status" => sub {
    my ($self) = @_;

    $self->reset_fixture;

    my $now = time;

    is_deeply( $self->fixture->react( { key => 'abc', status => 'CRITICAL', lastupdate => $now },
                                      {}
                                  ),
               { key          => 'abc',
                 status       => 'CRITICAL',
                 lastupdate   => $now,
                 status_since => $now,
                 status_count => 1,
                 color        => 'red',
             },
               "Running Status reactor on a message with initial status CRITICAL"
           );
};

test "status changes from OK to CRITICAL" => sub {
    my ($self) = @_;

    $self->reset_fixture;

    my $now = time;

    is_deeply( $self->fixture->react( { key => 'abc', status => 'OK', lastupdate => $now },
                                      {}
                                  ),
               { key => 'abc', status => 'OK', lastupdate => $now, status_since => $now, status_count => 1 },
               "Running Status reactor on a message with initial status OK"
           );

    is_deeply( $self->fixture->react( { key => 'abc', status => 'CRITICAL', lastupdate => $now },
                                      {}
                                  ),
               { key             => 'abc',
                 status          => 'CRITICAL',
                 lastupdate      => $now,
                 status_since    => $now,
                 status_count    => 1,
                 status_previous => 'OK',
                 color           => 'red',
             },
               "Running Status reactor when status changes to CRITICAL"
           );
};

test "repeated critical notification suppression" => sub {
    my ($self) = @_;

    $self->reset_fixture;

    my $now = time;

    is_deeply( $self->fixture->react( { key => 'abc', subject => 'foo', status => 'CRITICAL', lastupdate => $now },
                                      {}
                                  ),
               { key          => 'abc',
                 subject      => 'foo',
                 status       => 'CRITICAL',
                 lastupdate   => $now,
                 status_since => $now,
                 status_count => 1,
                 color        => 'red',
             },
               "Running Status reactor on a message with initial status CRITICAL"
           );

    sleep 1;
    my $second = time;

    is_deeply( $self->fixture->react( { key => 'abc', subject => 'foo', status => 'CRITICAL', lastupdate => $second },
                                      {}
                                  ),
               { key            => 'abc',
                 subject        => 'foo [2x CRITICAL]',
                 status         => 'CRITICAL',
                 lastupdate     => time,
                 status_since   => $now,
                 status_count   => 2,
                 color          => 'red',
             },
               "Running Status reactor on 2nd message with status CRITICAL"
           );

    is_deeply( $self->fixture->react( { key => 'abc', subject => 'foo', status => 'CRITICAL', lastupdate => $second },
                                      {}
                                  ),
               { key            => 'abc',
                 subject        => 'foo [3x CRITICAL]',
                 status         => 'CRITICAL',
                 lastupdate     => time,
                 status_since   => $now,
                 status_count   => 3,
                 color          => 'red',
             },
               "Running Status reactor on 3rd message with status CRITICAL"
           );

    is_deeply( $self->fixture->react( { key => 'abc', subject => 'foo', status => 'CRITICAL', lastupdate => $second },
                                      {}
                                  ),
               { key            => 'abc',
                 status_subject => 'foo',
                 status         => 'CRITICAL',
                 lastupdate     => time,
                 status_since   => $now,
                 status_count   => 4,
                 color          => 'red',
             },
               "Running Status reactor suppresses 4th warning, 4 is not a fibonacci number"
           );
};


test "_is_fibonacci" => sub {
    my ($self) = @_;

    $self->reset_fixture;

    for my $number ( 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144 ) {
        ok( $self->fixture->_is_fibonacci( $number ),
            "Checking that $number is a fibonacci number"
        );
    }

    for my $number ( 4, 6, 7, 9, 10, 11, 12, 14 ) {
        ok( ! $self->fixture->_is_fibonacci( $number ),
            "Checking that $number is not a fibonacci number"
        );
    }

};

run_me;
done_testing;



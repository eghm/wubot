#!/bin/perl
use strict;
use warnings;

package App::Wubot::Util::Test;
use Moose;

has 'dbfile' => ( is      => 'rw',
                  isa     => 'Str',
                  required => 1,
              );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

with 'App::Wubot::Util::Roles::Tables';

1;


package main;

use File::Temp qw/ tempdir /;
use Test::More;
use Test::Routine;
use Test::Routine::Util;

my $test_schema = { id     => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                    itemid => 'VARCHAR(16)',
                    data   => 'VARCHAR(16)',
                };

has test => (
    is   => 'ro',
    lazy => 1,
    clearer => 'reset_test',
    default => sub {

        my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

        return App::Wubot::Util::Test->new( dbfile => "$tempdir/tables.sql",
                                            schema => $test_schema,
                                            table  => 'test',
                                        );
    },
);

test "insert" => sub {
    my ($self) = @_;

    $self->reset_test;

    ok( my $item = $self->test->create( { itemid => 'myid', data => 'myvalue' } ),
        "Creating a new item"
    );

    is( $item->{id},
        1,
        "Checking that first item inserted got autoincrement id 1"
    );

    is( $item->{itemid},
        'myid',
        "Checking itemid"
    );
};

test "fetch" => sub {
    my ($self) = @_;

    $self->reset_test;

    $self->test->create( { itemid => 'myid', data => 'myvalue' } );

    ok( my $fetched = $self->test->fetch( 'myid' ),
        "Checking get_item for inserted id"
    );

    is( $fetched->{itemid},
        'myid',
        "Checking itemid on fetched item"
    );

    is( $fetched->{data},
        'myvalue',
        "Checking data field on fetched item"
    );

    is( $fetched->{id},
        "1",
        "Checking id field on fetched item"
    );
};

test "update" => sub {
    my ($self) = @_;

    $self->reset_test;

    $self->test->create( { itemid => 'myid', data => 'myvalue' } );

    $self->test->update( { itemid => 'myid', data => 'newvalue' } );

    ok( my $fetched = $self->test->fetch( 'myid' ),
        "Checking get_item for myid"
    );

    is( $fetched->{itemid},
        'myid',
        "Checking itemid on fetched item"
    );

    is( $fetched->{data},
        'newvalue',
        "Checking data field on fetched item"
    );
};



run_me;
done_testing;

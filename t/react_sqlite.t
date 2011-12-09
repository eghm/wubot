#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More;
use Test::Routine;
use Test::Routine::Util;
use YAML;

use App::Wubot::Logger;
use App::Wubot::Reactor::SQLite;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

has reactor => (
    is   => 'ro',
    lazy => 1,
    clearer => 'reset_reactor',
    default => sub {
        App::Wubot::Reactor::SQLite->new();
    },
);

test "test reactor" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    is_deeply( $self->reactor->react( {}, {} ),
               {},
               "Empty message results in no reaction field"
           );

};


test "simple insert" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $message = { subject => 'foo' };

    is_deeply( $self->reactor->react( $message,
                                      { file      => "$tempdir/test1.sql",
                                        tablename => 'test1',
                                        schema    => { subject => 'VARCHAR(32)' },
                                    } ),
               $message,
               "Empty message results in no reaction field"
           );
};

test "simple insert with id" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $message = 

    is_deeply( $self->reactor->react( { subject => 'bar' },
                                      { file      => "$tempdir/test1.sql",
                                        tablename => 'test2',
                                        schema    => { subject => 'VARCHAR(32)',
                                                       id      => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                                                   },
                                        id_field  => 'foo_id',
                                    } ),
               { subject => 'bar', foo_id => 1 },
               "Empty message results in no reaction field"
           );
};

run_me;
done_testing;

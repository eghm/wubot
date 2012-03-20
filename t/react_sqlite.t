#!/perl
use strict;
use warnings;

use Capture::Tiny;
use File::Temp qw/ tempdir /;
use Test::More;
use Test::Routine;
use Test::Routine::Util;
use YAML;

use App::Wubot::Logger;
use App::Wubot::Reactor::SQLite;

my $logger = Log::Log4perl::get_logger( __PACKAGE__ );

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

    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    is_deeply( $self->reactor->react( $message,
                                      { file      => "$tempdir/test1.sql",
                                        tablename => 'test1',
                                        schema    => { subject => 'VARCHAR(32)' },
                                    } ),
               $message,
               "Empty message results in no reaction field"
           );
};

test "no file or file_field" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $message = { subject => 'foo' };

    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );


    my $results;

    my $output = Capture::Tiny::capture_merged {
        $results = $self->reactor->react( $message,
                                          { tablename => 'test1',
                                            schema    => { subject => 'VARCHAR(32)' },
                                        } );
    };

    if ( $ENV{LOG_DEBUG} ) {
        like( $output,
              qr/sqlite reactor called with no 'file' or 'file_field' specified/,
              "react() with no file or file field set throws exception"
          );
    }

    is_deeply( $results,
               $message,
               "Checking that message returned unmodified"
           );

};

test "simple insert with id" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

    is_deeply( $self->reactor->react( { subject => 'bar' },
                                      { file      => "$tempdir/test1.sql",
                                        tablename => 'test2',
                                        schema    => { subject => 'VARCHAR(32)',
                                                       id      => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                                                   },
                                        id_field  => 'foo_id',
                                    } ),
               { subject => 'bar', foo_id => 1 },
               "checking that id_field from config was used for table id"
           );
};

test "use file_field to get file from field on message" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
    my $testfile = "$tempdir/asdf.sql";

    is_deeply( $self->reactor->react( { subject => 'asdf', my_file => $testfile },
                                      { file_field => 'my_file',
                                        tablename => 'test',
                                        schema    => { subject => 'VARCHAR(32)',
                                                       id      => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                                                   },
                                    } ),
               { subject => 'asdf', my_file => $testfile },
               "Setting path to sqlite file in my_file, where file_field is set to my_file"
           );

    ok( -r $testfile,
        "Checking that test sqlite file was created"
    );

    ok( $self->reactor->sqlite->{ $testfile },
        "Checking that reactor opened the test file"
    );

    is_deeply( [ $self->reactor->sqlite->{$testfile}->select( { tablename => 'test' } ) ],
               [ { id => 1, subject => 'asdf' } ],
               "Checking that row was inserted properly"
           );
};

run_me;
done_testing;

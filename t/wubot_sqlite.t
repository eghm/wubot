#!/perl
use strict;

use Test::More;
use Test::Routine;
use Test::Routine::Util;

use Capture::Tiny;
use File::Temp qw/ tempdir /;
use Test::Exception;
use YAML::XS;

BEGIN {
    if ( $ENV{HARNESS_ACTIVE} ) {
        $ENV{WUBOT_SCHEMAS} = "config/schemas";
    }
}

use App::Wubot::Logger;
use App::Wubot::SQLite;

has sqlite => (
    is      => 'rw',
    lazy    => 1,
    clearer => 'reset_sqlite',
    default => sub {
        my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
        my $sqldb   = "$tempdir/test.sql";
        my $sql     = App::Wubot::SQLite->new( { file => $sqldb } );
    },
);

test "using sqlite test" => sub {
    my ($self) = @_;

    $self->reset_sqlite; # this test requires a fresh one

    ok( $self->sqlite->dbh, "Checking that we have a db handle" );
};

# ok( -r $sqldb,
#     "Checking that sql db was created: $sqldb"
# );

test "create table, insert, query, and delete" => sub {
    my ($self) = @_;

    $self->reset_sqlite; # this test requires a fresh one

    my $table = "test_table_1";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
               };

    ok( $self->sqlite->create_table( $table, $schema ),
        "Creating a table $table"
    );

    is_deeply( [ $self->sqlite->get_tables() ],
               [ $table ],
               "Checking that table was created"
           );

    ok( $self->sqlite->insert( $table, { column1 => 123, column2 => "foo", column3 => "abc" }, $schema ),
        "Inserting hash into table"
    );

    is( ( $self->sqlite->query( "SELECT * FROM $table" ) )[0]->{column2},
        'foo',
        "Selecting row just inserted into table and checking column value"
    );

    is( ( $self->sqlite->query( "SELECT * FROM $table" ) )[0]->{column3},
        undef,
        "Checking that key not defined in schema was not inserted into table"
    );

    ok( $self->sqlite->delete( $table, { column1 => 123 } ),
        "Deleting entry just added"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [],
               "Checking that no rows left in the table"
           );

    $schema->{column3} = 'VARCHAR(32)';

    ok( $self->sqlite->insert( $table, { column1 => 234, column2 => "bar", column3 => "baz" }, $schema ),
        "Inserting hash with modified schema to include column3"
    );

    is( ( $self->sqlite->query( "SELECT * FROM $table" ) )[0]->{column3},
        'baz',
        "Selecting column3 just inserted into table and checking column value"
    );
};

test "table automatically created on 'insert'" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_2";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
               };

    ok( $self->sqlite->insert( $table, { column1 => 123, column2 => "foo" }, $schema ),
        "Inserting hash into non-existent table"
    );

    is( ( $self->sqlite->query( "SELECT * FROM $table" ) )[0]->{column2},
        'foo',
        "Checking that table was created and data was inserted and retrieved"
    );
};

test "auto-incrementing id" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_3";
    my $schema = { id      => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                   column1 => 'INT',
               };

    is( $self->sqlite->insert( $table, { column1 => 123 }, $schema ),
        1,
        "Inserting hash into table, checking returned id"
    );

    is( $self->sqlite->insert( $table, { column1 => 234 }, $schema ),
        2,
        "Inserting hash into table, checking returned id"
    );

    is( $self->sqlite->insert( $table, { column1 => 345 }, $schema ),
        3,
        "Inserting hash into table, checking returned id"
    );

    is( ( $self->sqlite->query( "SELECT * FROM $table" ) )[0]->{id},
        1,
        "Checking auto-incrementing id"
    );

    is( ( $self->sqlite->query( "SELECT * FROM $table" ) )[1]->{id},
        2,
        "Checking auto-incrementing id"
    );
};

test "testing 'id' field on message is not inserted over autoincrementing id" => sub {
    my ($self) = @_;

    $self->reset_sqlite;
    my $table = "test_table_13";
    my $schema = { id      => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                   column1 => 'INT',
                   column2 => 'INT',
               };

    ok( $self->sqlite->insert( $table, { id => 5, column1 => 0, column2 => 1 }, $schema ),
        "Inserting data hash into table with an 'id' that should be ignored"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ { id => 1, column1 => 0, column2 => 1 } ],
               "Checking inserted data got id that was autoincremented"
           );
};


test "inserting defined false value" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_4";
    my $schema = { column1 => 'INT' };

    ok( $self->sqlite->insert( $table, { column1 => 0 }, $schema ),
        "Inserting hash into table with data value 0"
    );

    is( ( $self->sqlite->query( "SELECT * FROM $table" ) )[0]->{column1},
        0,
        "Checking that 0 was returned on query"
    );
};

test "testing 'select' method" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_5";
    my $schema = { column1 => 'INT', column2 => 'TEXT', column3 => 'INT', column4 => 'INT', column5 => 'INT' };

    my $data1 = { column1 => 1, column2 => 'foo foo foo', column3 => 3, column4 => 1, column5 => 0 };
    ok( $self->sqlite->insert( $table, $data1, $schema ),
        "Inserting test data 1 into table"
    );

    my $data2 = { column1 => 2, column2 => 'bar bar', column3 => 2, column4 => 1, column5  => 1 };
    ok( $self->sqlite->insert( $table, $data2, $schema ),
        "Inserting test data 2 into table"
    );

    my $data3 = { column1 => 3, column2 => 'baz', column3 => 1, column4 => 0, column5 => 1 };
    ok( $self->sqlite->insert( $table, $data3, $schema ),
        "Inserting test data into table"
    );

    {
        my @rows;
        ok( $self->sqlite->select( { tablename  => $table,
                                     callback   => sub { push @rows, $_[0] },
                                 } ),
            "Selecting all rows in table"
        );
        is_deeply( \@rows,
                   [ $data1, $data2, $data3 ],
                   "Selecting all rows"
               );
    }
    {
        my @rows;
        ok( $self->sqlite->select( { tablename => $table,
                                     order     => 'column3',
                                     callback  => sub { push @rows, $_[0] },
                                 } ),
            "Selecting all rows in table ordered by column3"
        );
        is_deeply( \@rows,
                   [ $data3, $data2, $data1 ],
                   "Selecting all rows"
               );
    }
    {
        my @rows;
        ok( $self->sqlite->select( { tablename => $table,
                                     order     => 'column3',
                                     limit     => 1,
                                     callback  => sub { push @rows, $_[0] },
                                 } ),
            "Selecting all rows in table ordered by column3 with limit 1"
        );
        is_deeply( \@rows,
                   [ $data3 ],
                   "Selecting matching rows"
               );
    }
    {
        my @rows;
        ok( $self->sqlite->select( { tablename => $table,
                                     order     => 'column3',
                                     where     => { column4 => 1,
                                                    column5 => 1,
                                                },
                                     callback  => sub { push @rows, $_[0] },
                                 } ),
            "Selecting all rows in table with conditions column4 = 1 and column5 = 1"
        );
        is_deeply( \@rows,
                   [ $data2 ],
                   "Selecting matching rows"
               );
    }
};

test "testing 'update' method" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_6";
    my $schema = { column1 => 'INT', column2 => 'INT', column3 => 'INT' };

    my $data1 = { column1 => 0, column2 => 1, column3 => 2 };
    ok( $self->sqlite->insert( $table, $data1, $schema ),
        "Inserting data1 hash into table"
    );

    my $data2 = { column1 => 4, column2 => 5, column3 => 6 };
    ok( $self->sqlite->insert( $table, $data2, $schema ),
        "Inserting data2 hash into table"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data"
           );

    my $error;
    my ( $stdout, $stderr ) = Capture::Tiny::capture {
        eval {
            $self->sqlite->update( $table, { column1 => 7 }, { column1 => 0 } );
        };

        $error = $@;
    };

    like( $error,
          qr/no schema specified, and global schema not found for table: $table/,
          "Checking that exception thrown when running a sql update without providing schema",
      );

    like( $stderr,
          qr/no schema specified, and global schema not found for table: $table/,
          "Checking that exception thrown when running a sql update without providing schema",
      );

    ok( $self->sqlite->update( $table, { column1 => 7 }, { column1 => 0 }, $schema ),
        "Calling update() to set column1 to 7 where column1 was 0"
    );

    $data1->{column1} = 7;

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking row was updated"
           );
};

test "testing 'update' method with schema change" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_7";
    my $schema = { column1 => 'INT', column2 => 'INT', column3 => 'INT' };

    my $data1 = { column1 => 0, column2 => 1, column3 => 2 };
    ok( $self->sqlite->insert( $table, $data1, $schema ),
        "Inserting data1 hash into table"
    );

    my $data2 = { column1 => 4, column2 => 5, column3 => 6 };
    ok( $self->sqlite->insert( $table, $data2, $schema ),
        "Inserting data2 hash into table"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data before calling update()"
           );

    $schema->{column4} = 'INT';

    ok( $self->sqlite->update( $table, { column4 => 7 }, { column1 => 0 }, $schema ),
        "Calling update() with updated schema containing column4"
    );

    $data1->{column4} = 7;
    $data2->{column4} = undef;

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking row was updated with column4 data"
           );
};


test "testing 'insert_or_update' method" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_8";
    my $schema = { column1 => 'INT', column2 => 'INT', column3 => 'INT' };

    my $data1 = { column1 => 0, column2 => 1, column3 => 2 };

    ok( $self->sqlite->insert_or_update( $table, $data1, { column1 => 3 }, $schema ),
        "Inserting data2 hash into table with insert_or_update and no pre-existing row"
    );

    my $data2 = { column1 => 4, column2 => 5, column3 => 6 };
    ok( $self->sqlite->insert_or_update( $table, $data2, { column1 => 7 }, $schema ),
        "Inserting data2 hash into table with insert_or_update and no pre-existing row"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data before calling update()"
           );

    ok( $self->sqlite->insert_or_update( $table, { column1 => 7 }, { column1 => 0 }, $schema ),
        "Calling insert_or_update with row that already exists"
    );

    $data1->{column1} = 7;

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking existing row was updated with insert_or_update"
           );
};

test "testing 'update' that violates unique constraints" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_9";
    my $schema = { column1     => 'INT',
                   column2     => 'INT',
                   column3     => 'INT',
                   constraints => [ 'UNIQUE( column1, column2 )' ],
               };

    my $data1 = { column1 => 1, column2 => 2, column3 => 3 };
    ok( $self->sqlite->insert( $table, $data1, $schema ),
        "Inserting first new hash into table"
    );

    my $data2 = { column1 => 4, column2 => 5, column3 => 6 };
    ok( $self->sqlite->insert( $table, $data2, $schema ),
        "Inserting second new hash into table"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data"
           );

    {
        ok( ! $self->sqlite->insert( $table, $data1, $schema ),
            "Inserting duplicate data into column violates unique constraint"
        );
    }

    {
        my $data3 = { column1 => 1, column2 => 2, column3 => 7 };
        ok( ! $self->sqlite->insert( $table, $data3, $schema ),
            "Inserting data into column that violates unique constraint on column1 and column2"
        );
    }

    {
        ok( ! $self->sqlite->update( $table, $data2, $data1, $schema ),
            "Updating data2 to match data1 violates unique constraint on column1 and column2"
        );
    }

    {
        ok( ! $self->sqlite->insert_or_update( $table, $data2, $data1, $schema ),
            "insert_or_update data2 to match data1 violates unique constraint on column1 and column2"
        );
    }

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ $data1, $data2 ],
               "Checking inserted data"
           );

};

test "testing 'delete' method" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_10";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
               };

    $self->sqlite->create_table( $table, $schema );
    $self->sqlite->insert( $table, { column1 => 123, column2 => "foo1" }, $schema );
    $self->sqlite->insert( $table, { column1 => 234, column2 => "foo2" }, $schema );
    $self->sqlite->insert( $table, { column1 => 345, column2 => "foo3" }, $schema );

    ok( $self->sqlite->delete( $table, { column1 => { '>' => 123 } } ),
        "Deleting entries > 123"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ { column1 => 123, column2 => "foo1" } ],
               "Checking that only one row left in the table"
           );

};

test "testing 'insert' that violates unique constraint" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_11";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
                   constraints => [ 'UNIQUE( column1 )' ],
               };

    $self->sqlite->create_table( $table, $schema );

    ok( $self->sqlite->insert( $table, { column1 => 123, column2 => "foo1" }, $schema ),
        "Inserting first row into table"
    );

    ok( ! $self->sqlite->insert( $table, { column1 => 123, column2 => "foo2" }, $schema ),
        "failing to insert row that violates constraint"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ { column1 => 123, column2 => "foo1" } ],
               "Checking that only one row left in the table"
           );

};

test "testing 'on conflict replace' constraint" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    my $table = "test_table_12";
    my $schema = { column1 => 'INT',
                   column2 => 'VARCHAR(16)',
                   constraints => [ 'UNIQUE( column1 ) ON CONFLICT REPLACE' ],
               };

    ok( $self->sqlite->create_table( $table, $schema ),
        "Creating table with UNIQUE constraint and ON CONFLICT REPLACE"
    );

    ok( $self->sqlite->insert( $table, { column1 => 123, column2 => "foo1" }, $schema ),
        "Inserting first row into table"
    );

    ok( $self->sqlite->insert( $table, { column1 => 123, column2 => "foo2" }, $schema ),
        "inserting row that should replace first row due to constraint"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ { column1 => 123, column2 => "foo2" } ],
               "Checking that second row replaced first table due to ON CONFLICT REPLACE constraint"
           );
};

test "testing schema yaml files" => sub {
    my ($self) = @_;

    my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
    my $xyz_schema = { abc => 'INT',
                       def => 'TEXT',
                   };
    YAML::XS::DumpFile( "$tempdir/xyz.yaml", $xyz_schema );

    my $foo_schema = { bar => 'INT',
                       baz => 'TEXT',
                   };
    YAML::XS::DumpFile( "$tempdir/foo.yaml", $foo_schema );

    $self->reset_sqlite;

    # override schema_dir
    $self->sqlite->{schema_dir} = $tempdir;


    is_deeply( $self->sqlite->check_schema( 'xyz' ),
               $xyz_schema,
               "Checking xyz schema"
           );

    is_deeply( $self->sqlite->check_schema( 'foo' ),
               $foo_schema,
               "Checking foo schema"
           );

    my $table = "xyz";

    ok( $self->sqlite->create_table( $table ),
        "Creating table, using schema from schema file"
    );

    ok( $self->sqlite->insert( $table, { abc => 123, def => 456, ghi => 789 } ),
        "Inserting data, using schema in schema file"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ { abc => 123, def => 456 } ],
               "Checking that defined columns inserted into table"
           );

    # update schema
    $xyz_schema->{ghi} = 'TEXT';
    sleep 1; # ensure date stamp is at least one second later
    YAML::XS::DumpFile( "$tempdir/xyz.yaml", $xyz_schema );

    ok( $self->sqlite->insert( $table, { abc => 234, def => 567, ghi => 890 } ),
        "Inserting data, after adding column to schema file"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table ORDER BY abc" ) ],
               [ { abc => 123, def => 456, ghi => undef },
                 { abc => 234, def => 567, ghi => 890 }
             ],
               "Checking that defined columns inserted into table"
           );

};

test "testing schema config file with named schema" => sub {
    my ($self) = @_;

    my $tempdir2 = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
    my $table = "xyz";
    my $dir   = "foo";
    my $xyz_schema = { abc => 'INT',
                       def => 'TEXT',
                   };

    system( "mkdir", "$tempdir2/$dir" );
    YAML::XS::DumpFile( "$tempdir2/$dir/$table.yaml", $xyz_schema );

    $self->reset_sqlite;

    # override schema_dir
    $self->sqlite->{schema_dir} = $tempdir2;

    is_deeply( $self->sqlite->check_schema( $table, $dir ),
               $xyz_schema,
               "Checking $dir.$table schema"
           );

    ok( $self->sqlite->create_table( $table, $dir ),
        "Creating table, using schema from schema file"
    );

    ok( $self->sqlite->insert( $table, { abc => 123, def => 456, ghi => 789 }, $dir ),
        "Inserting data, using schema in schema file"
    );

    is_deeply( [ $self->sqlite->query( "SELECT * FROM $table" ) ],
               [ { abc => 123, def => 456 } ],
               "Checking that defined columns inserted into table"
           );
};

test "testing disconnect" => sub {
    my ($self) = @_;

    $self->reset_sqlite;

    ok( $self->sqlite->disconnect(),
        "Closing SQLite file"
    );

    throws_ok( sub { $self->sqlite->query( "SELECT * FROM test_table_2" ) },
               qr/prepare failed.*inactive database handle/,
               "Checking that exception thrown when running a sql query on dead sql handle",
           );
};



run_me;
done_testing;

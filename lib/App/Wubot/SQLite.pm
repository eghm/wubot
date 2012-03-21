package App::Wubot::SQLite;
use Moose;

# VERSION

use Capture::Tiny;
use DBI;
use DBD::SQLite;
use Devel::StackTrace;
use FindBin;
use SQL::Abstract;
use YAML::XS;

use App::Wubot::Logger;

=head1 NAME

App::Wubot::SQLite - the wubot library for working with SQLite


=head1 SYNOPSIS

    use App::Wubot::SQLite;

    my $sqlite = App::Wubot::SQLite->new( { file => '/path/to/db.sqlite' } );

    # insert data into 'mytable'.  table is automatically created if
    # it doesn't exist.
    $sqlite->insert( 'mytable', { abc => 'xyz' }, { abc => 'TEXT' } );

    # insert another row into 'mytable'.  'xyz' column is
    # automatically added.
    $sqlite->insert( 'mytable', { abc => 'def', xyz => 'abc' }, { abc => 'TEXT', xyz => 'TEXT" } );


=head1 DESCRIPTION

Wubot uses SQLite for a wide variety of uses, including:

  - asynchronous message queues
  - monitors
  - reactions
  - viewing data in the web interface

Most of the heavy lifting is accomplished by L<SQL::Abstract>.  See
the documentation there for more information.

App::Wubot::SQLite adds a number of features including:

  - allow schema to be define in external config files
  - add missing tables if schema is available
  - add missing columns that are defined in schema but missing from a table

=head1 SCHEMAS

Schema files are read from ~/wubot/schemas.  Each table's schema lives
in a file named {tablename}.yaml.  You can bypass the schema files by
specifying the complete schema as a hashref.  If you pass in a string
for the schema, then that string will be used as a subdirectory in
~/wubot/schemas.  This allows you to group similar schemas together
without having to use strange names for the tables.  Here are some
examples:

  # no schema specified, look for the schema file in
  # ~/wubot/schemas/mytable.yaml
  $sqlite->insert( 'mytable', { abc => 'xyz' } );

  # bypass schema files, specify schema in insert
  $sqlite->insert( 'mytable', { abc => 'xyz' }, { abc => 'TEXT' } );

  # schema directory specified, look for the schema file in
  # ~/wubot/schemas/foo/mytable.yaml
  $sqlite->insert( 'mytable', { abc => 'xyz' }, 'foo' );

A number of schemas are distributed in the wubot tarball in the
config/schemas subdirectory.  These schemas should be copied to
~/wubot/schemas before running wubot.

Each time a table schema is needed, the schema config file will be
checked to see if it has been updated; if so, the schema file will be
re-read.  This allows you to change the schema without re-starting the
process.  Note that while missing columns can be added, but columns
are not dynamically removed, and an existing column type is never
altered.


=cut

# only initialize one connection to each database handle
my %sql_handles;

has 'schemas'      => ( is       => 'ro',
                        isa      => 'HashRef',
                        lazy     => 1,
                        default  => sub { {} },
                    );

has 'file'         => ( is       => 'ro',
                        isa      => 'Str',
                        required => 1,
                    );

has 'dbh'          => ( is       => 'rw',
                        isa      => 'DBI::db',
                        lazy     => 1,
                        default  => sub {
                            my ( $self ) = @_;
                            return $self->connect();
                        },
                    );

has 'sql_abstract' => ( is       => 'ro',
                        isa      => "SQL::Abstract",
                        lazy     => 1,
                        default  => sub {
                            return SQL::Abstract->new;
                        },
                    );

has 'schema_dir'   => ( is       => 'ro',
                        isa      => 'Str',
                        lazy     => 1,
                        default  => sub {
                            my $self = shift;
                            my $schema_dir;
                            if ( $ENV{WUBOT_SCHEMAS} ) {
                                $schema_dir = $ENV{WUBOT_SCHEMAS};
                            }
                            else {
                                $schema_dir = join( "/", $ENV{HOME}, "wubot", "schemas" );
                            }
                            unless ( -d $schema_dir ) {
                                $self->logger->logdie( "schema directory does not exist: $schema_dir" );
                            }
                            $self->logger->debug( "schema directory: $schema_dir" );
                            return $schema_dir;
                        },
                    );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );



=head1 SUBROUTINES/METHODS

=over 8

=item create_table( $tablename, $schema )

Create a table using the specified schema.

If no schema is provided, the schema directory will be checked for a
schema file named '{tablename}.yaml'.

If no schema is found, a fatal error will be thrown.

=cut

sub create_table {
    my ( $self, $table, $schema ) = @_;

    unless ( $table ) {
        $self->logger->logcroak( "Error: table not specified" );
    }
    $schema = $self->check_schema( $table, $schema );

    my $command = "CREATE TABLE $table (\n";

    my @lines;
    for my $key ( keys %{ $schema } ) {
        next if $key eq "constraints";
        my $type = $schema->{$key};
        push @lines, "\t$key $type";
    }

    if ( $schema->{constraints} ) {
        for my $constraint ( @{ $schema->{constraints} } ) {
            push @lines, "\t$constraint";
        }
    }
    $command .= join ",\n", @lines;

    $command .= "\n);";

    $self->logger->trace( $command );

    $self->dbh->do( $command );
}

=item get_tables()

Get a list of all tables defined in the SQLite database.

If the database contains a table named 'sqlite_sequence', then that
table will be omitted from the returned list of tables.

=cut

sub get_tables {
    my ( $self, $table ) = @_;

    my $sth = $self->dbh->table_info(undef, undef, $table, 'TABLE' );

    my @tables;

    while ( my $entry = $sth->fetchrow_hashref ) {
        next if $entry->{TABLE_NAME} eq "sqlite_sequence";
        push @tables, $entry->{TABLE_NAME};
    }

    return @tables;
}

=item check_schema( $table, $schema, $failok )

Check the schema for a given tablename.  Returns the schema.

The schema is option.  If a schema is passed into the method, then
that schema will be used; otherwise the schema directory will be
checked for a file named {tablename}.yaml.  If the file has changed
since the last time the file was read, then the file will be re-read.

If no schema is found, a 'no schema specified or found for table'
exception will be thrown.

If the 'failok' flag is true, then failure to find a schema will not
throw an exception, but will simply write a log message at debug
level.

=cut

sub check_schema {
    my ( $self, $table, $schema, $failok ) = @_;

    unless ( $schema && ref $schema eq "HASH" ) {
        unless ( $schema = $self->get_schema( $table, $schema ) ) {
            if ( $failok ) {
                $self->logger->debug( "no schema specified, and global schema not found for table: $table" );
                return;
            }
            else {
                $self->logger->debug( Devel::StackTrace->new->as_string );
                $self->logger->logdie( "FATAL: no schema specified, and global schema not found for table: $table" );
            }
        }
    }

    unless ( $schema ) {
        $self->logger->logcroak( "Error: no schema specified or found for table: $table" );
    }

    unless ( ref $schema eq "HASH" ) {
        $self->logger->logcroak( "ERROR: schema for table $table is invalid: not a hash ref" );
    }

    return $schema;
}

=item insert( $table, $entry_h, $schema )

Insert a single row into the named table.

Only columns defined in the schema will be inserted.  Any keys in the
entry hash that are not found in the schema will be ignored.

If an 'id' field is defined in the entry, it will be ignored even if
the id is defined in the schema.  Wubot expects that an 'id' field is
always of the type 'INTEGER PRIMARY KEY AUTOINCREMENT'.

This method uses the 'insert' method on L<SQL::Abstract>.  See the
documentation there for more information.

The 'id' of the row that was inserted will be returned.

The get_prepared method is used to prepare the statement handle, so a
missing table or any missing columns will be added.  See the
get_prepared method documentation for more information.

=cut

sub insert {
    my ( $self, $table, $entry, $schema ) = @_;

    unless ( $entry && ref $entry eq "HASH" ) {
        $self->logger->logcroak( "ERROR: insert: entry undef or not a hashref" );
    }
    unless ( $table && $table =~ m|^\w+$| ) {
        $self->logger->logcroak( "ERROR: insert: table name does not look valid" );
    }
    $schema = $self->check_schema( $table, $schema );

    my $insert;
    for my $field ( keys %{ $schema } ) {
        next if $field eq "constraints";
        next if $field eq "id" && $schema->{id} && $schema->{id} =~ m|AUTOINCREMENT|;
        $insert->{ $field } = $entry->{ $field };
    }

    my( $command, @bind ) = $self->sql_abstract->insert( $table, $insert );

    my $sth1 = $self->get_prepared( $table, $schema, $command );

    eval {                          # try
        my ($stdout, $stderr) = Capture::Tiny::capture {
            $sth1->execute( @bind );
        };

        if ( $stdout ) { $self->logger->warn( $stdout ) }
        if ( $stderr ) { $self->logger->warn( $stderr ) }

        1;
    } or do {                       # catch
        return;
    };

    return $self->dbh->last_insert_id( "", "", $table, "");
}


=item update( $table, $entry_h, $where, $schema )

Update a row in the table described by the 'where' clause.

This method uses the 'update' method on L<SQL::Abstract>.  See the
documentation there for more information.

Only columns defined in the schema will be updated.  Any keys in the
entry hash that are not found in the schema will be ignored.

If an 'id' field is defined in the entry, it will be ignored even if
the id is defined in the schema.  Wubot expects that an 'id' field is
always of the type 'INTEGER PRIMARY KEY AUTOINCREMENT'.

The get_prepared method is used to prepare the statement handle, so a
missing table or any missing columns will be added.  See the
get_prepared method documentation for more information.

=cut

sub update {
    my ( $self, $table, $update, $where, $schema ) = @_;

    $schema = $self->check_schema( $table, $schema );

    my $insert;
    for my $field ( keys %{ $schema } ) {
        next if $field eq "constraints";
        next if $field eq "id" && $schema->{id} && $schema->{id} =~ m|AUTOINCREMENT|;
        next unless exists $update->{ $field };
        $insert->{ $field } = $update->{ $field };
    }

    my( $command, @bind ) = $self->sql_abstract->update( $table, $insert, $where );

    my $sth1 = $self->get_prepared( $table, $schema, $command );

    eval {                          # try
        my ($stdout, $stderr) = Capture::Tiny::capture {
            $sth1->execute( @bind );
        };

        if ( $stdout ) { $self->logger->warn( $stdout ) }
        if ( $stderr ) { $self->logger->warn( $stderr ) }

        1;
    } or do {                       # catch
        return;
    };

    return 1;
}

=item insert_or_update( $table, $entry_h, $where, $schema )

If a row exists in the table that matches the 'where' clause, then
calls the update() method on that row.  If not, then calls the
insert() method.  See the documentation on the 'update' and 'insert'
methods for more information.

=cut

sub insert_or_update {
    my ( $self, $table, $update, $where, $schema ) = @_;

    $schema = $self->check_schema( $table, $schema );

    my $count;
    # wrap select() in an eval, this could fail, e.g. if the table does not already exist
    eval {
        $self->select( { tablename => $table, where => $where, callback => sub { $count++ }, schema => $schema } );
    };

    if ( $count ) {
        $self->logger->debug( "updating $table" );
        return $self->update( $table, $update, $where, $schema );
    }

    $self->logger->debug( "inserting into $table" );
    return $self->insert( $table, $update, $schema );

    return 1;
}

=item select( $options_h )

This method takes the following options:

  - fields - a list of fields to return, defaults to *
  - where - SQL::Abstract 'where'
  - order - SQL::Abstract 'order'
  - limit - maximum number of rows to return
  - callback - method to be executed on all matching rows

This method uses the L<SQL::Abstract> 'select' method to return one or
more rows.  See the documentation there for more details.

If no callback() method is defined, then all matching rows will be
returned.  Using a callback() may be more efficient if a large dataset
is returned since it does not require all rows to be stored in memory.

The get_prepared method is used to prepare the statement handle, so a
missing table or any missing columns will be added.  See the
get_prepared method documentation for more information.

=cut

sub select {
    my ( $self, $options ) = @_;

    my $tablename = $options->{tablename};
    unless ( $tablename ) {
        $self->logger->logcroak( "ERROR: select called but no tablename provided" );
    }

    # if ( $self->logger->is_trace() ) {
    #     my $log_text = YAML::XS::Dump $options;
    #     $self->logger->trace( "SQL Select: $log_text" );
    # }

    my $fields    = $options->{fields}     || '*';
    my $where     = $options->{where};
    my $order     = $options->{order};
    my $limit     = $options->{limit};
    my $group     = $options->{group};

    my $callback  = $options->{callback};

    my( $statement, @bind ) = $self->sql_abstract->select( $tablename, $fields, $where, $order );

    if ( $group && $group =~ m|([\w\d]+)| ) {
        if ( $statement =~ m|ORDER| ) {
            $statement =~ s|ORDER|GROUP BY $group ORDER|;
        }
        else {
            $statement .= " GROUP BY $group";
        }
    }

    if ( $limit && $limit =~ m|(\d+)| ) {
        $statement .= " LIMIT $1";
    }

    #$self->logger->debug( "SQLITE: $statement", YAML::XS::Dump @bind );

    my $schema = $self->check_schema( $tablename, $options->{schema}, 1 );

    my $sth = $self->get_prepared( $tablename, $schema, $statement );

    my $rv;
    eval {
        $rv = $sth->execute(@bind);
        1;
    } or do {
        $self->logger->logcroak( "can't execute the query: $statement: $@ file=", $self->file );
    };

    my @entries;

    while ( my $entry = $sth->fetchrow_hashref ) {

        if ( $callback ) {
            $callback->( $entry );
        }
        else {
            push @entries, $entry;
        }
    }

    if ( $callback ) {
        return 1;
    }
    else {
        return @entries;
    }
}

=item query( $statement, $callback )

Execute the specified SQL statement.

If no callback() method is defined, then all matching rows will be
returned.  Using a callback() may be more efficient if a large dataset
is returned since it does not require all rows to be stored in memory.

Note that this method does not do any quoting of the statement, so if
it contains any data from external sources, it may be vulnerable to a
SQL injection attack!

=cut

sub query {
    my ( $self, $statement, $callback ) = @_;

    my ( $sth, $rv );
    my ($stdout, $stderr) = Capture::Tiny::capture {
        $sth = $self->dbh->prepare($statement) or $self->logger->logcroak( "Can't prepare $statement" );
        $rv  = $sth->execute or $self->logger->logcroak( "can't execute the query: $statement" );
    };

    if ( $stdout ) { $self->logger->warn( $stdout ) }
    if ( $stderr ) { $self->logger->warn( $stderr ) }

    my @return;

    while ( my $entry = $sth->fetchrow_hashref ) {
        if ( $callback ) {
            $callback->( $entry );
        }
        else {
            push @return, $entry;
        }
    }

    return @return;
}

=item delete( $table, $conditions )

Delete rows from a table that match the specified conditions.  See the
'delete' method on L<SQL::Abstract> for more details.

=cut

sub delete {
    my ( $self, $table, $conditions ) = @_;

    unless ( $table && $table =~ m|^\w+$| ) {
        $self->logger->logcroak( "ERROR: delete: invalid table name" );
    }
    unless ( $conditions && ref $conditions eq "HASH" ) {
        $self->logger->logcroak( "ERROR: delete: conditions is not a hash ref" );
    }

    my( $statement, @bind ) = $self->sql_abstract->delete( $table, $conditions );

    $self->logger->trace( join( ", ", $statement, @bind ) );

    my $sth = $self->dbh->prepare($statement) or confess "Can't prepare $statement\n";

    my $rv;
    eval {
        $sth->execute(@bind);
        1;
    } or do {
        $self->logger->logcroak( "can't execute the query: $statement: $@" );
    };

}

=item vacuum()

Run the 'vacuum' command.  Rebuilds the database to reclaim space from
deleted items.

=cut

sub vacuum {
    my ( $self ) = @_;

    eval {
        $self->logger->warn( "starting to vacuum database" );
        $self->dbh->do( 'vacuum' );
        $self->logger->warn( "done vacuuming database" );
        1;
    } or do {
        $self->logger->fatal( "can't vacuum database: $@" );
    };

}

=item get_prepared( $table, $schema, $command )

Given a SQL command, attempt to prepare the statement.

If the prepare() method throws a 'no such table' error, then the
table will be created using the specified schema.

If the prepare() method throws a 'no such column' error, then if the
column is defined in the schema, then the add_column method will be
called to add the missing column.

=cut

sub get_prepared {
    my ( $self, $table, $schema, $command ) = @_;

    $self->logger->trace( $command );

    my $sth1;

    # make sure dbh has been lazy loaded before we try to use it below
    # inside Capture::Tiny
    $self->dbh;

  RETRY:
    for my $retry ( 0 .. 10 ) {
        eval {                          # try

            my ($stdout, $stderr) = Capture::Tiny::capture {
                $sth1 = $self->dbh->prepare( $command );
            };

            if ( $stdout ) { $self->logger->warn( $stdout ) }
            if ( $stderr ) { $self->logger->warn( $stderr ) }

            1;
        } or do {                       # catch
            my $error = $@;

            # if the table doesn't already exist, create it
            if ( $error =~ m/no such table/ ) {
                $self->logger->warn( "Creating missing table: $table" );
                $self->create_table( $table, $schema );
                $self->{tables}->{$table} = 1;
                next RETRY;
            } elsif ( $error =~ m/(?:has no column named|no such column\:) (\S+)/ ) {
                my $column = $1;

                unless ( $column ) { $self->logger->logcroak( "ERROR: failed to capture a column name!"  ) }

                $self->logger->warn( "Adding missing column: $column" );

                if ( $schema->{$column} ) {
                    $self->add_column( $table, $column, $schema->{$column} );
                    next RETRY;
                } else {
                    $self->logger->logcroak( "Missing column $column not defined in schema for $table" );
                }
            } else {
                $self->logger->logcroak( "Unhandled error: $error" );
            }

        };

        return $sth1;
    };

    $self->logger->logcroak( "ERROR: unable to prepare statement, exceeded maximum retry limit" );
}

=item add_column( $table, $column, $type )

Add a column with the specified name and type to the schema by calling:

  ALTER TABLE $table ADD COLUMN $column $type

=cut

sub add_column {
    my ( $self, $table, $column, $type ) = @_;
    my $command = "ALTER TABLE $table ADD COLUMN $column $type";
    $self->dbh->do( $command );
}

=item connect()

Calls the DBI->connect method to open a handle to the SQLite database
file.

The open database handles are cached in a global variable, so multiple
attempts to call connect() on the same database file will return the
same database handle rather than creating multiple handles to the same
file.

=cut

sub connect {
    my ( $self ) = @_;

    my $datafile = $self->file;

    unless ( $datafile ) {
        $self->logger->logconfess( "SQLite connect method called but no datafile specified!" );
    }

    if ( $sql_handles{ $datafile } ) {
        return $sql_handles{ $datafile };
    }

    $self->logger->warn( "Opening sqlite file: $datafile" );

    my $dbh;
    eval {                          # try
        $dbh = DBI->connect( "dbi:SQLite:$datafile", "", "",
                             {
                                 AutoCommit => 1,
                                 RaiseError => 1,
                             }
                         );

        1;
    } or do {                       # catch
        my $error = $@;

        $self->logger->logcroak( "Unable to create database handle for $datafile: $error" );
    };

    $sql_handles{ $datafile } = $dbh;

    return $dbh;
}

=item disconnect()

Close the database handle for a database by calling the disconnect()
method on the database handle.

=cut

sub disconnect {
    my ( $self ) = @_;

    $self->dbh->disconnect;
}

=item get_schema( $table, $directory )

Given the name of a table, get the schema for that table.

The schema will be cached in memory, along with the timestamp on the
schema config file.  Any time this method is called, it will look at
the timestamp on the schema file to see if it has changed.  If so, the
schema file will be reloaded.  This allows you to dynamically change
the schema without having to restart the wubot processes.

=cut

sub get_schema {
    my ( $self, $table, $directory ) = @_;

    unless ( $table ) {
        $self->logger->logconfess( "ERROR: get_schema called but no table specified" );
    }

    if ( $directory && $directory =~ m|\.| ) {
        ( $directory, $table ) = split /\./, $directory;
    }

    my $schema_file;
    if ( $directory ) {
        $schema_file = join( "/", $self->schema_dir, $directory, "$table.yaml" );
    }
    else {
        $schema_file = join( "/", $self->schema_dir, "$table.yaml" );
    }
    $self->logger->debug( "looking for schema file: $schema_file" );

    unless ( -r $schema_file ) {
        $self->logger->debug( "schema file not found: $schema_file" );
        return;
    }

    my $mtime = ( stat $schema_file )[9];
    my $schema = {};

    if ( $self->schemas->{$table} ) {

        if ( $mtime > $self->schemas->{$table}->{mtime} ) {

            # file updated since last load
            $self->logger->warn( "Re-loading $table schema: $schema_file" );
            $schema = YAML::XS::LoadFile( $schema_file );
        }
        else {
            # no updates, return from memory
            return $self->schemas->{$table}->{table};
        }

    }
    else {

        # hasn't yet been loaded from memory
        $self->logger->info( "Loading $table schema: $schema_file" );
        $schema = YAML::XS::LoadFile( $schema_file );

    }

    $self->schemas->{$table}->{table} = $schema;
    $self->schemas->{$table}->{mtime} = $mtime;

    return $schema;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=back

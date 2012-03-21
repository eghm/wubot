package App::Wubot::Reactor::SQLite;
use Moose;

# VERSION

use App::Wubot::Logger;
use App::Wubot::SQLite;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'sqlite'  => ( is => 'ro',
                   isa => 'HashRef',
                   default => sub { {} },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    my $file;
    if ( $config->{file} ) {
        $file = $config->{file};
    }
    elsif ( $config->{file_field} ) {
        if ( $message->{ $config->{file_field} } ) {
            $file = $message->{ $config->{file_field} };
        }
        else {
            $self->logger->error( "WARNING: sqlite reactor: field $config->{file_field} not defined on message" );
            return $message;
        }
    }
    else {
        $self->logger->error( "WARNING: sqlite reactor called with no 'file' or 'file_field' specified" );
        return $message;
    }

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $file } ) {
        $self->sqlite->{ $file } = App::Wubot::SQLite->new( { file => $file } );
    }

    if ( $config->{update} ) {
        my $update_where;
        for my $field ( keys %{ $config->{update} } ) {
            $update_where->{ $field } = $message->{ $field };
        }
        $self->sqlite->{ $file }->insert_or_update( $config->{tablename}, $message, $update_where, $config->{schema} );
    }
    else {
        my $id = $self->sqlite->{ $file }->insert( $config->{tablename}, $message, $config->{schema} );

        if ( $config->{id_field} ) {
            $message->{ $config->{id_field} } = $id;
        }
    }

    return $message;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::Wubot::Reactor::SQLite - insert or update a message in a SQLite table row

=head1 SYNOPSIS

  - name: store message in SQLite database, schema in ~/wubot/schemas/mytable.yaml
    plugin: SQLite
    config:
      file: /path/to/myfile.sql
      tablename: mytable

  - name: store in SQLite with schema specified in config
    plugin: SQLite
    config:
      file: /path/to/somefile.sql
      tablename: tablex
      schema:
        id: INTEGER PRIMARY KEY AUTOINCREMENT
        subject: VARCHAR(256)
        somefield: INTEGER

  - name: update existing row in a table, see below
    plugin: SQLite
    config:
      update:
        foo: 1
        bar: 1
      file: /path/to/myfile.sql
      tablename: mytable
      schema:
        id: INTEGER PRIMARY KEY AUTOINCREMENT
        foo: INTEGER
        bar: INTEGER
        baz: INTEGER

=head1 DESCRIPTION

The message will be inserted into a row in a SQLite table.  The
'schema' is consulted to determine which fields to insert.  If you
don't specify the schema in the rule, it will search in
~/wubot/schemas for a named {tablename}.yaml.

=head1 UPDATE

If you set 'update' (see the third example in the SYNOPIS), then it
will use the columns you list under the 'update' section in building
the WHERE clause for the update.  In other words, if you defined a
field named 'foo' under update, it would attempt to update the row in
the database where the 'foo' column matches the 'foo' field on your
message.

If no row is found that matches the WHERE clause, then it will just do
an INSERT.

If a row exists that matches your WHERE clause, then the row will be
updated.  Only the columns specified in the 'schema' on the rule will
be updated.  If you do not specify the schema in the rule, then it
will fall back to the schema in ~/wubot/schemas/{tablename}.yaml.

A word of warning--if you use the schema file, then any field listed
in the schema that exist on the message will get updated in the
database.  If you have a table with many columns, and you are only
intending to update a few of them, it may be better to list the
'schema' directly on the rule to ensure only the columns you are
intending to modify will get updated.  Unfortunately this may lead to
duplicated schema definitions across your rules.  This is on my todo
list, but patches are welcome.  :)

Also note that if you have an 'ON CONFLICT' constraint on your table,
then this could lead to unexpected behavior when using 'update'.  For
example, if you specify 'update' with field 'x', and there is no row
in the table where column 'x' matches the value of 'x' on your
message, then this reactor will fall back to doing an INSERT.  If the
inserted message triggers your 'ON CONFLICT REPLACE' rule, then it may
remove the existing row and replace it with a new one created from
your new message--which may end up setting some fields in the row to
null (those that previously existed in the database before the
update and were not defined in the message being inserted).

=head1 WARNINGS


=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back

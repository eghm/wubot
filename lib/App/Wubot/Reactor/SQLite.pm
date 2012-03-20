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
        somefield: int


=head1 DESCRIPTION

more to come...

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back

package App::Wubot::Util::Roles::Tables;
use Moose::Role;

# VERSION

use App::Wubot::Logger;
use App::Wubot::SQLite;

=head1 NAME

App::Wubot::Util::Roles::Tables - under construction


=head1 SYNOPSIS

    with 'App::Wubot::Util::Roles::Tables';


=head1 DESCRIPTION

TODO: add documentation here!

=cut

requires 'dbfile';
requires 'logger';

has 'sql'    => ( is      => 'ro',
                  isa     => 'App::Wubot::SQLite',
                  lazy    => 1,
                  default => sub {
                      return App::Wubot::SQLite->new( { file => $_[0]->dbfile } );
                  },
              );

has 'table'  => ( is       => 'ro',
                  isa      => 'Str',
                  required => 1,
              );

has 'schema' => ( is       => 'ro',
              );

has 'idfield' => ( is      => 'ro',
                   isa     => 'Str',
                   default => 'itemid',
               );


=head1 SUBROUTINES/METHODS

=over 8

=item $obj->create( $item );

TODO: document this method!

=cut

sub create {
    my ( $self, $item_h ) = @_;

    unless ( $item_h->{lastupdate} ) {
        $item_h->{lastupdate} = time;
    }

    my ( $id ) = $self->sql->insert( $self->table,
                                     $item_h,
                                     $self->schema,
                                 );

    # set 'id' field to item we just inserted
    $item_h->{id} = $id;

    return $item_h;
}

=item $obj->fetch( $itemid );

TODO: document this method!

=cut

sub fetch {
    my ( $self, $itemid ) = @_;

    my $id_field = $self->idfield;

    unless ( $itemid ) {
        $self->logger->logdie( "ERROR: fetch called without $id_field" );
    }

    my ( $item_h ) = $self->sql->select( { tablename => $self->table,
                                           where     => { $id_field => $itemid },
                                           schema    => $self->schema,
                                       } );

    unless ( $item_h ) {
        $self->logger->logdie( "ERROR: item not found: $itemid" );
    }

    return $item_h;
}

=item $obj->update( $item );

TODO: document this method!

=cut

sub update {
    my ( $self, $item_h ) = @_;

    my $id_field = $self->idfield;

    unless ( $item_h->{ $id_field } ) {
        $self->logger->logdie( "ERROR: can't update without id field: $id_field" );
    }

    $self->sql->insert_or_update( $self->table, $item_h, { $id_field => $item_h->{ $id_field } }, $self->schema );

    return $item_h;
}


1;

__END__

=back

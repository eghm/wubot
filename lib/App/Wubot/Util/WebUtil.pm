package App::Wubot::Util::WebUtil;
use Moose;

# VERSION

#use Mojo::Base 'Mojolicious::Controller';

has 'type' => ( is => 'ro',
                isa => 'Str',
                required => 1,
            );

has 'idname' => ( is => 'ro',
                  isa => 'Str',
                  lazy => 1,
                  default => sub {
                      my $self = shift;
                      return join( "", $self->type, "id" );
                  },
              );

has 'fields' => ( is       => 'ro',
                  isa      => 'ArrayRef[Str]',
                  required => 1,
              );

has 'sql'    => ( is      => 'ro',
                  isa     => 'App::Wubot::SQLite',
                  lazy    => 1,
                  default => sub {
                      return App::Wubot::SQLite->new( { file => $_[0]->dbfile } );
                  },
              );

has 'dbfile' => ( is      => 'rw',
                  isa     => 'Str',
                  lazy    => 1,
                  default => sub {
                      my $self = shift;
                      my $type = $self->type;
                      return join( "/", $ENV{HOME}, "wubot", "sqlite", "$type.sql" );
                  },
              );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );


sub get_item {
    my ( $self, $id, $callback ) = @_;

    unless ( $id ) {
        $self->logger->logdie( "ERROR: get_task called but id not specified" );
    }

    my $type   = $self->type;
    my $idname = $self->idname;

    my ( $item_h ) = $self->sql->select( { tablename => $type,
                                           where     => { $idname => $id },
                                       } );

    unless ( $item_h ) {
        $self->logger->logdie( "ERROR: $type item not found: $id" );
    };

    $callback->( $item_h, $id );

    return $item_h;
}

sub create_item {

}

sub get_submit_item {
    my ( $self, $mojo, $postproc, $id ) = @_;

    my $idname = $self->idname;

    my $item;
    my $changed_flag;

  PARAM:
    for my $param ( @{ $self->fields } ) {

        my $value = $mojo->param( $param );
        next PARAM unless defined $value;

        $item->{ $param } = $value;
        $changed_flag = 1;
    }

    return unless $changed_flag;

    $item->{lastupdate} = time;

    if ( $id ) {
        $item->{$idname} = $id;
    }

    # class-specific formatting for submit item
    $postproc->( $item );

    return $item;
}

sub update_item {
    my ( $self, $item, $id, $preproc, $ref, $options ) = @_;

    my $type   = $self->type;
    my $idname = $self->idname;

    unless ( $item ) {
        die "ERROR: update_item called without item for type $type";
    }
    unless ( $id ) {
        die "ERROR: update_item called without id for type $type";
    }

    # ensure itemid is set in the item
    $item->{$idname} = $id;

    unless ( $options->{no_lastupdate} ) {
        $item->{lastupdate} = time;
    }

    $self->logger->info( "Updating $type item: $id" );

    $preproc->( $ref, $item );

    $self->sql->insert_or_update( $type, $item, { $idname => $id } );

    return 1;
}

sub check_session {
    my ( $self, $mojo, $variable ) = @_;

    my $val_param   = $mojo->param(   $variable );
    my $val_session = $mojo->session( $variable );

    # variable being set to a new value
    if ( $val_param ) {
        $self->logger->info( "Value set as param: $variable = $val_param" );
        $mojo->session( $variable => $val_param );
        $mojo->stash( $variable => $val_param );
        return $val_param
    }

    # variable being set to false
    if ( defined $val_param ) {
        $self->logger->info( "Value defined in session: $variable = $val_param" );
        $mojo->session( $variable => 0 );
        $mojo->stash( $variable => "" );
        $self->logger->debug( "Unset in session: $variable" );
        return;
    }

    # variable not changed, return from session
    $mojo->stash( $variable => $val_session );
    $mojo->stash( $variable => $val_session );
    return $val_session;
}

sub list {


}

sub get_item_post {


}

1;

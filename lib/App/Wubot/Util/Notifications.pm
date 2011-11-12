package App::Wubot::Util::Notifications;
use Moose;

# VERSION

use App::Wubot::Logger;
use App::Wubot::SQLite;

has 'sql'    => ( is      => 'ro',
                  isa     => 'App::Wubot::SQLite',
                  lazy    => 1,
                  default => sub {
                      App::Wubot::SQLite->new( { file => $_[0]->dbfile } );
                  },
              );

has 'dbfile' => ( is      => 'rw',
                  isa     => 'Str',
                  lazy    => 1,
                  default => sub {
                      return join( "/", $ENV{HOME}, "wubot", "sqlite", "notify.sql" );
                  },
              );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );



sub insert_tag {
    my ( $self, $id, $tag ) = @_;

    $self->sql->insert( 'tags',
                        { remoteid => $id, tag => $tag, tablename => 'notifications', lastupdate => time },
                    );

}

sub get_item_tags {
    my ( $self, $id ) = @_;

    my @tags;

    $self->sql->select( { tablename => 'tags',
                          fieldname => 'tag',
                          where     => { remoteid => $id },
                          order     => 'tag',
                          callback  => sub { my $entry = shift;
                                             push @tags, $entry->{tag};
                                         },
                      } );

    return @tags;
}

sub get_all_tags {
    my ( $self ) = @_;

    my $tags_h;

    $self->sql->select( { tablename => 'tags',
                          fieldname => 'tag',
                          callback  => sub { my $entry = shift;
                                             $tags_h->{ $entry->{tag} }++;
                                         },
                      } );

    return $tags_h;
}

sub mark_seen {
    my ( $self, $ids, $time ) = @_;

    unless ( $time ) { $time = time }

    my @seen;

    if ( ref $ids eq "ARRAY" ) {
        @seen = @{ $ids }
    }
    elsif ( $ids =~ m|,| ) {
        @seen = split /,/, $ids;
    }
    else {
        @seen = ( $ids );
    }

    $self->sql->update( 'notifications',
                        { seen => $time   },
                        { id   => \@seen },
                    );
}

sub get_tagged_ids {
    my ( $self, $tag ) = @_;

    my @ids;

    $self->sql->select( { tablename => 'tags',
                          fieldname => 'remoteid',
                          where     => { tag => $tag },
                          callback  => sub {
                              my $row = shift;
                              push @ids, $row->{remoteid};
                          },
                      } );

    return @ids;
}

sub get_item_by_id {
    my ( $self, $id ) = @_;

    my ( $item ) = $self->sql->select( { tablename => 'notifications',
                                         where     => { id => $id },
                                     } );

    return $item;
}


1;

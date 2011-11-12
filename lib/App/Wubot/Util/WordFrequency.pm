package App::Wubot::Util::WordFrequency;
use Moose;

# VERSION

use DB_File;
use Storable qw(freeze thaw);

use App::Wubot::Logger;
use App::Wubot::SQLite;

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
                      return join( "/", $ENV{HOME}, "wubot", "sqlite", "wordfreq.sql" );
                  },
              );

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'schemas'   => ( is => 'ro',
                     isa => 'HashRef',
                     default => sub {
                         return {
                             tags => {
                               id  => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                               tag => 'VARCHAR(32)',
                               key => 'VARCHAR(32)',
                               constraints => [ 'UNIQUE( tag, key )' ],
                           },
                             wordlist => {
                               id  => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                               key => 'VARCHAR(32)',
                               word => 'VARCHAR(64)',
                               constraints => [ 'UNIQUE( key, word ) ON CONFLICT REPLACE' ],
                             },
                             tag_words => {
                               id  => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                               tag => 'VARCHAR(32)',
                               word => 'VARCHAR(32)',
                               count => 'INTEGER',
                               constraints => [ 'UNIQUE( tag, word ) ON CONFLICT REPLACE' ],
                             },
                             key_wordlist => {
                               id  => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                               key => 'VARCHAR(32)',
                               wordlist => 'TEXT',
                               constraints => [ 'UNIQUE( key ) ON CONFLICT REPLACE' ],
                             },
                             word_keys   => {
                               id  => 'INTEGER PRIMARY KEY AUTOINCREMENT',
                               word => 'VARCHAR(32)',
                               keylist => 'TEXT',
                               constraints => [ 'UNIQUE( word ) ON CONFLICT REPLACE' ],
                           },
                         };
                     },
                 );

my %skip_words = (
    the => 1,
    a   => 1,
    an  => 1,
    is  => 1,
    be  => 1,
    was => 1,
    were => 1,
    with => 1,
    you => 1,
    your => 1,
    i => 1,
    in  => 1,
    on  => 1,
    of  => 1,
    it  => 1,
    if  => 1,
    by  => 1,
    on  => 1,
);

sub count_words {
    my ( $self, @content ) = @_;

    my %words;

    for my $content ( @content ) {
        next unless $content;

        chomp $content;

      WORD:
        for my $word ( split /[\s+\=]/, $content ) {

            $word = lc( $word );

            $word =~ tr/a-z0-9//cd;

            next unless $word;

            next WORD if $skip_words{ $word };

            next if $word =~ m|^\d\d?$|;

            $words{$word}++;

        }
    }

    return \%words;
}

sub store {
    my ( $self, $key, $words, @tags ) = @_;

    push @tags, '_TOTAL_';

    my $word_count = 0;

    # get original data from the deb
    my ( $item ) = $self->sql->select( { tablename => 'key_wordlist',
                                         where     => { key => $key },
                                         schema    => $self->schemas->{key_wordlist},
                                     } );
    my $orig_item = thaw( $item->{wordlist} );

    $self->sql->insert( 'key_wordlist',
                        {  key => $key, wordlist => freeze( $words ) },
                        $self->schemas->{key_wordlist}
                    );

    # add new data to the tables
    for my $word ( keys %{ $words } ) {
        my $orig_count = $orig_item->{ $word } || 0;

        {
            my ( $item ) = $self->sql->select( { tablename => 'word_keys',
                                                 where     => { word => $word },
                                                 schema    => $self->schemas->{word_keys},
                                                 } );

            my $keylist = thaw( $item->{keylist} );
            $keylist->{$key} += $words->{$word} - $orig_count;

            $self->sql->insert( 'word_keys',
                                { word => $word, keylist => freeze( $keylist ) },
                                $self->schemas->{word_keys}
                            );
        }

        $self->sql->insert( 'wordlist',
                            { key => $key, word => $word, count => $words->{$word} },
                            $self->schemas->{wordlist}
                        );

        for my $tag ( @tags ) {

            my $item_count = $item->{count} || 0;

            $item->{tag} = $tag;
            $item->{word} = $word;
            $item->{count} = $item_count + $words->{$word} - $orig_count;

            $self->sql->insert( 'tags', { tag => $tag, key => $key }, $self->schemas->{tags} );

            {
                my ( $item ) = $self->sql->select( { tablename => 'tag_words',
                                                     where     => { tag => $tag, word => $word },
                                                     schema    => $self->schemas->{tag_words},
                                                 } );

                $item->{count} +=  $words->{$word} - $orig_count;

                $self->sql->insert( 'tag_words',
                                    { tag => $tag, word => $word, count => $item->{count} },
                                    $self->schemas->{tag_words}
                                );
            }
        }

        $word_count++;
        delete $orig_item->{ $word };
    }

    # delete the words that no longer exist in the document
    for my $word ( keys %{ $orig_item } ) {
        my $orig_count = $orig_item->{ $word } || 0;

        $self->sql->delete( 'wordlist', { key => $key, word => $word } );

        for my $tag ( @tags ) {

            my ( $item ) = $self->sql->select( { tablename => 'tag_words',
                                                 where     => { tag => $tag, word => $word },
                                                 schema    => $self->schemas->{tag_words},
                                             } );

            $item->{count} -= $orig_count;;

            if ( $item->{count} ) {
                $self->sql->insert( 'tag_words',
                                    { tag => $tag, word => $word, count => $item->{count} },
                                    $self->schemas->{tag_words}
                                );
            }
            else {
                $self->sql->delete( 'tag_words', { tag => $tag, word => $word } );
            }
        }

    }

    # return number of words stored for $key
    return $word_count;
}

sub get_num_words {
    my ( $self ) = @_;

    my $count;

    $self->sql->select( { tablename => 'wordlist',
                          schema    => $self->schemas->{wordlist},
                          callback  => sub {
                              my $row = shift;
                              $count->{ $row->{word} }++;
                          },
                      } );

    return scalar keys %{ $count };
}

sub get_all_tags {
    my ( $self ) = @_;

    my @tags;

    $self->sql->select( { tablename => 'tags',
                          fieldname => 'tag',
                          order     => 'tag',
                          group     => 'tag',
                          schema    => $self->schemas->{tags},
                          callback  => sub {
                              my $row = shift;
                              return if $row->{tag} eq "_TOTAL_";
                              push @tags, $row->{tag};
                          },
                      } );

    return @tags;
}

sub get_tagged_item_count {
    my ( $self, $tag ) = @_;

    my $count = 0;

    $self->sql->select( { tablename => 'tags',
                          fieldname => 'tag',
                          where     => { tag => $tag },
                          schema    => $self->schemas->{tags},
                          callback  => sub {
                              my $row = shift;
                              $count++;
                          },
                      } );

    return $count;
}

sub fetch_word {
    my ( $self, $word ) = @_;

    my ( $item ) = $self->sql->select( { tablename => 'word_keys',
                                         where     => { word => $word }
                                     } );

    return thaw( $item->{keylist} );
}

sub fetch_words_from_key {
    my ( $self, $key ) = @_;

    # get original data from the deb
    my ( $item ) = $self->sql->select( { tablename => 'key_wordlist',
                                         where     => { key => $key },
                                         schema    => $self->schemas->{key_wordlist},
                                     } );

    return thaw( $item->{wordlist} );
}

sub fetch_words_from_tag {
    my ( $self, $tag ) = @_;

    my $words;

    $self->sql->select( { tablename => 'tag_words',
                          where     => { tag => $tag },
                          schema    => $self->schemas->{tag_words},
                          callback  => sub {
                              my $row = shift;
                              $words->{ $row->{word} } = $row->{count};
                          }
                      } );

    delete $words->{_TOTAL_};

    return $words;
}

sub get_similar {
    my ( $self, $words ) = @_;

    my $matches;

    for my $word ( keys %{ $words } ) {

        my $counts = $self->fetch_word( $word );
        next unless $counts;

        for my $key ( keys %{ $counts } ) {
            $matches->{ $key }++;
        }
    }

    return $matches;
}

sub get_tag_suggestions {
    my ( $self, $words ) = @_;

    my $num_words = $self->get_num_words();

    my $total_word_counts = $self->fetch_words_from_tag( '_TOTAL_' );

    my $grand_total_words = 0;
    for my $word ( keys %{ $total_word_counts } ) {
        $grand_total_words += $total_word_counts->{ $word };
    }

    my $total_count = $self->get_tagged_item_count( '_TOTAL_' );

    my $return;

    for my $tag ( $self->get_all_tags() ) {

        my $tag_word_counts = $self->fetch_words_from_tag( $tag );

        my $grand_tag_word_count;
        for my $word ( keys %{ $tag_word_counts } ) {
            $grand_tag_word_count += $tag_word_counts->{ $word };
        }

        my $p_tag_top = 1;
        my $p_tag_bot = 1;

        for my $word ( keys %{ $words } ) {

            my $tag_word_count = $tag_word_counts->{ $word }||0;

            my $notag_counts = $total_word_counts->{ $word } - $tag_word_count;

            # p( $word | tag )
            $p_tag_top *= ( $tag_word_count + 1 ) / ( $grand_tag_word_count + $num_words );

            my $grand_notag_word_count = $grand_total_words - $grand_tag_word_count;
            my $notag_count = $notag_counts||0;

            # p( $word | -tag )
            $p_tag_bot *= ( $notag_count + 1 ) / ( $grand_notag_word_count + $num_words );
        }

        my $tag_count = $self->get_tagged_item_count( $tag );
        my $notag_count = $total_count - $tag_count;

        # p(tag)
        $p_tag_top *= ( ( $tag_count + 1 ) / ( $total_count + 2 ) );

        # p(-tag)
        $p_tag_bot *= ( ( $notag_count + 1 ) / ( $total_count + 2 ) );

        # p( tag | item )
        next unless $p_tag_top;
        my $result = $p_tag_top / ( $p_tag_top + $p_tag_bot );

        $return->{ $tag } = sprintf( "%0.5f", $result );
    }

    return $return;
}


1;

package Wubot::Web::Rss;
use Mojo::Base 'Mojolicious::Controller';

use XML::Atom::SimpleFeed;
use XML::RSS;

use Wubot::SQLite;

my $rss_file       = join( "/", $ENV{HOME}, "wubot", "sqlite", "rss.sql" );
my $sqlite_rss     = Wubot::SQLite->new( { file => $rss_file } );

sub rss {
    my $self = shift;

    my $mailbox = $self->stash( 'mailbox' );

    my $start = time - 24*60*60;

    my $where = { mailbox    => $mailbox,
                  lastupdate => { '>', $start },
              };

    my $rss = new XML::RSS( version => '1.0' );
    $rss->channel(
        title => "$mailbox (wubot)",
        link  => "https://geektank.selfip.org/wubot",
        description => "rss feed generated by wubot",
    );

    $rss->image(
        title  => "$mailbox image",
        url    => "/images/rss/$mailbox.png",
    );

    $sqlite_rss->select( { tablename => 'feeds',
                           where     => $where,
                           order     => [ 'lastupdate' ],
                           limit     => $self->param('limit') || 100,
                           callback  => sub { my $entry = $_[0];

                                              my $site = $entry->{key};
                                              my $title = $entry->{title} || $entry->{subject} || "no title";

                                              my $article_title = "[$site] $title";
                                              utf8::decode( $article_title );

                                              my $link = $entry->{link} || "";

                                              my $body = $entry->{body};
                                              utf8::decode( $body );

                                              $rss->add_item(
                                                  title       => $article_title,
                                                  link        => $link,
                                                  description => $body,
                                                  dc => {
                                                      date => format_date_time( $entry->{lastupdate} )
                                                  }
                                              );
                                          },
                       } );

    my $text = $rss->as_string;

    # stash the feed content
    $self->stash( 'feed' => $text );

    $self->render( 'rss',
                   format => 'xml',
                   template => 'rss',
                   handler => 'epl',
               );


};

sub atom {
    my $self = shift;

    my $mailbox = $self->stash( 'mailbox' );

    my $start = time - 24*60*60;

    my $where = { mailbox    => $mailbox,
                  lastupdate => { '>', $start },
              };

    my $feed = XML::Atom::SimpleFeed->new(
        title   => "$mailbox (wubot)",
        link    => 'https://geektank.selfip.org/wubot',
        author  => 'Wu',
        icon    => "http://localhost:3000/images/rss/$mailbox.ico",
        logo    => "http://localhost:3000/images/rss/$mailbox.png",
    );

    $sqlite_rss->select( { tablename => 'feeds',
                           where     => $where,
                           order     => [ 'lastupdate' ],
                           limit     => $self->param('limit') || 100,
                           callback  => sub { my $entry = $_[0];

                                              my $site = $entry->{key};
                                              my $title = $entry->{title} || $entry->{subject} || "no title";

                                              my $article_title = "[$site] $title";
                                              utf8::decode( $article_title );

                                              my $link = $entry->{link} || "";

                                              my $body = $entry->{body};
                                              utf8::decode( $body );

                                              $feed->add_entry(
                                                  title     => $article_title,
                                                  link      => $link,
                                                  content   => $body,
                                              );

                                          },
                       } );

    my $text = $feed->as_string;

    # stash the feed content
    $self->stash( 'feed' => $text );

    $self->render( 'rss',
                   format => 'xml',
                   template => 'rss',
                   handler => 'epl',
               );


};

sub format_date_time {
    my ( $time ) = @_;

    unless ( $time ) { $time = time }

    my $dt_start = DateTime->from_epoch( epoch => $time        );
    my $start    = $dt_start->ymd('-') . 'T' . $dt_start->hms(':') . 'Z';

    return $start;
}

1;

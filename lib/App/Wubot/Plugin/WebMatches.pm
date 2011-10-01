package App::Wubot::Plugin::WebMatches;
use Moose;

# VERSION

use App::Wubot::Logger;
use App::Wubot::Util::WebFetcher;

with 'App::Wubot::Plugin::Roles::Cache';
with 'App::Wubot::Plugin::Roles::Plugin';


has 'fetcher' => ( is  => 'ro',
                   isa => 'App::Wubot::Util::WebFetcher',
                   lazy => 1,
                   default => sub {
                       return App::Wubot::Util::WebFetcher->new();
                   },
               );

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    my $content;
    eval {                          # try
        $content = $self->fetcher->fetch( $config->{url}, $config );
        1;
    } or do {                       # catch
        my $error = $@;
        my $subject = "Request failure: $error";
        $self->logger->error( $self->key . ": $subject" );
        return { cache => $cache, react => { subject => $subject } };
    };

    my @react;

    my $regexp = $config->{regexp};

    $self->logger->debug( "REGEXP: $regexp" );

    my $count;

  MATCH:
    while ( $content =~ m|$regexp|mg ) {

        $count++;

        my $match = $1;

        $self->logger->trace( "MATCH: $match" );

        if ( $self->cache_is_seen( $cache, $match ) ) {
            $self->logger->trace( "Already seen: ", $match );

            # touch cache time on this match
            $self->cache_mark_seen( $cache, $match );

            next MATCH;
        }

        $self->cache_mark_seen( $cache, $match );

        push @react, { match => $match, link => $config->{url} };

    }

    $self->cache_expire( $cache );

    unless ( $count ) {
        $self->logger->error( $self->key . ": no matches found" );
        return { cache => $cache, react => { subject => "no matches found" } };
    }

    return { react => \@react, cache => $cache };
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

App::Wubot::Plugin::WebMatches - monitor a web page for items matching a regexp


=head1 SYNOPSIS

  ~/wubot/config/plugins/WebMatches/openssl.yaml

  ---
  delay: 1d
  url: http://www.openssl.org/sourcex/
  regexp: '\"(openssl\-[\d\.]+[a-z]?\.tar\.gz)\"'


=head1 DESCRIPTION

This plugin allows you define a regexp will capture match one or more
items on a web page.  Each time a new item shows up on the page that
matches your regexp, a message will get sent with the matching item.

The message will contain a field called 'match' which will contain the
matched text, and 'link' which will point to the source URL.

In the event of a failure retrieving content from the specified URL, a
message will be sent containing a subject field such as:

  subject: Request failure: {$error}

=head1 HINTS

If you simply want to capture a single occurrence of a regexp from a
page at regular intervals, you may want to use the
L<App::Wubot::Plugin::WebFetch> plugin instead.  This plugin will cache
previously seen values and will only send a message when a new item
shows up in the list of matches.


=head1 EXAMPLE

I like to use this plugin to monitor for new releases of software when
there is no RSS feed or other mechanism to notify you of a new
release.  For example, here is the complete monitor config I use for
monitoring for new OpenSSL releases:

  ---
  delay: 1d
  url: http://www.openssl.org/sourcex/
  regexp: '\"(openssl\-[\d\.]+[a-z]?\.tar\.gz)\"'

  react:

    - name: matched
      condition: match is true
      rules:

        - name: field
          plugin: SetField
          config:
          field: sticky
          value: 1

        - name: subject
          plugin: Template
          config:
            template: 'New openssl release: {$match}'
            target_field: subject

=head1 CACHE

This monitor uses the global cache mechanism, so each time the check
runs, it will update a file such as:

  ~/wubot/cache/WebMatches-myfeed.yaml

The monitor caches all matches in the feed in this file.  When a new
(previously unseen) match shows up on the feed, the message will be
sent, and the cache will be updated.  Removing the cache file will
cause all matching items to be sent again.

=head1 SEE ALSO

This plugin uses L<App::Wubot::Util::WebFetcher>.


=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back

#!/perl
use strict;

use Test::More 'no_plan';
use YAML;

use Wubot::Util::WebFetcher;

ok( my $fetcher = Wubot::Util::WebFetcher->new(),
    "Creating a new fetcher"
);

ok( my $google_content = $fetcher->fetch( 'http://www.google.com/', {} ),
    "Fetching content from google with no config"
);

like( $google_content,
      qr/google/,
      "Checking google content"
  );

ok( my $futurama_episodes = $fetcher->fetch( 'http://epguides.com/Futurama/' ),
    "Getting futurama episodes web page"
);

$futurama_episodes =~ m/(M..bius Dick)/;

is( $1,
    'Möbius Dick',
    "Checking for utf8 character in futurama episode name"
);

{
    # my $content = $fetcher->fetch( 'http://feeds.feedburner.com/FreeBSD-TheUnknownGiant?format=xml' );
    # $content =~ m|(FreeNAS 8 .*? Audio)|;
    # print "GOT: $1\n";
    # print YAML::Dump { got => $1 };
}




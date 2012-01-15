#!/perl
use strict;

use Test::More 'no_plan';

use WubotX::Contacts::Item;

ok( my $item = WubotX::Contacts::Item->new(),
    "Creating a new 'contact' item"
);

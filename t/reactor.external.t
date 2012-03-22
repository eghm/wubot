#!/perl
use strict;

use File::Temp qw/ tempdir /;
use Sys::Hostname;
use Test::More;
use Test::Routine;
use Test::Routine::Util;
use YAML::XS;

use App::Wubot::Logger;
use App::Wubot::Reactor;

$| = 1;

my $hostname = hostname();
$hostname =~ s|\..*$||;

my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );

my $config_src = <<"EOF";
---
rules:

  - name: rule1
    condition: name matches TestCase1
    plugin: SetField
    config:
      field: foo
      value: 1

  - name: rule2
    condition: name matches TestCase2
    rulesfile: $tempdir/rules1.yaml

  - name: rule3
    condition: name matches TestCase3
    rulesfile_field: myrules

  - name: rule4
    condition: name matches TestCase4
    rulesfile: $tempdir/rules4.yaml

EOF

my $config = YAML::XS::Load( $config_src );

#############################################################################
# rules 1
open(my $fh1, ">", "$tempdir/rules1.yaml")
    or die "Couldn't open $tempdir/rules1.yaml for writing: $!\n";

my $rules1 = <<"END_RULES1";
---
rules:

  - name: rule4
    plugin: SetField
    config:
      field: bar
      value: 1

END_RULES1
print $fh1 $rules1;
close $fh1 or die "Error closing file: $!\n";

#############################################################################
# rules 2

open(my $fh2, ">", "$tempdir/rules2.yaml")
    or die "Couldn't open $tempdir/rules2.yaml for writing: $!\n";

my $rules2 = <<"END_RULES2";
---
rules:

  - name: rule5
    condition: x is true
    plugin: SetField
    config:
      field: baz
      value: 1

END_RULES2
print $fh2 $rules2;
close $fh2 or die "Error closing file: $!\n";

#############################################################################
# main

has reactor => (
    is   => 'ro',
    lazy => 1,
    clearer => 'reset_reactor',
    default => sub {
        my ( $self ) = @_;

        return App::Wubot::Reactor->new( config => $config );
    },
);

test "hello world" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( my $results = $self->reactor->react( { test => 'true' } ),
        "calling react() on message"
    );

    is_deeply( $results,
               { test => 'true' },
               "Calling react() with a minimal test message"
           );
};


test "running rule in main rules file" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( my $results = $self->reactor->react( { name => 'TestCase1' } ),
        "Calling react() on the message"
    );

    is_deeply( $results,
               { name => 'TestCase1',
                 foo  => 1,
                 wubot_rulelog => { $hostname => [ qw( rule1 ) ] },
             },
               "Calling react() for TestCase1"
           );
};

test "running rule in first external rules file" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( my $results = $self->reactor->react( { name => 'TestCase2' } ),
        "Calling react() on the message"
    );

    is_deeply( $results,
               { name => 'TestCase2',
                 bar  => 1,
                 wubot_rulelog => { $hostname => [ qw( rule2 rule4 ) ] },
             },
               "Calling react() for TestCase2"
           );
};

test "running rule in first external rules file, second run reads from cache" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( my $results = $self->reactor->react( { name => 'TestCase2' } ),
        "Calling react() on the message"
    );

    is_deeply( $results,
               { name => 'TestCase2',
                 bar  => 1,
                 wubot_rulelog => { $hostname => [ qw( rule2 rule4 ) ] },
             },
               "Calling react() for TestCase2"
           );
};

test "running rule in external file specified by rulesfile_field" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( my $results = $self->reactor->react( { name => 'TestCase3',
                                               myrules => "$tempdir/rules2.yaml",
                                               x => 1,
                                           } ),
        "Calling react() on the message"
    );

    is_deeply( $results,
               { name => 'TestCase3',
                 baz  => 1,
                 x    => 1,
                 myrules => "$tempdir/rules2.yaml",
                 wubot_rulelog => { $hostname => [ qw( rule3 rule5 ) ] },
             },
               "Calling react() for TestCase3"
           );
};

test "re-read external rules file on change" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    {
        open(my $fh4, ">", "$tempdir/rules4.yaml")
            or die "Couldn't open $tempdir/rules4.yaml for writing: $!\n";

        my $rules4 = <<"END_RULES4";
---
rules:

  - name: rule6
    condition: x is true
    plugin: SetField
    config:
      field: baz
      value: 1

END_RULES4

        print $fh4 $rules4;
        close $fh4 or die "Error closing file: $!\n";

        ok( my $results = $self->reactor->react( { name => 'TestCase4',
                                                   x => 1,
                                               } ),
            "Calling react() on the message"
        );

        is_deeply( $results,
                   { name => 'TestCase4',
                     baz  => 1,
                     x    => 1,
                     wubot_rulelog => { $hostname => [ qw( rule4 rule6 ) ] },
                 },
                   "Calling react() for TestCase4"
               );
    }

    sleep 1;

    {
        open(my $fh4, ">", "$tempdir/rules4.yaml")
            or die "Couldn't open $tempdir/rules4.yaml for writing: $!\n";

        my $rules4 = <<"END_RULES4";
---
rules:

  - name: rule6
    condition: x is true
    plugin: SetField
    config:
      field: baz
      value: 2

END_RULES4

        print $fh4 $rules4;
        close $fh4 or die "Error closing file: $!\n";


        ok( my $results = $self->reactor->react( { name => 'TestCase4',
                                                   x => 1,
                                               } ),
            "Calling react() on the message after changing the file"
        );

        is_deeply( $results,
                   { name => 'TestCase4',
                     baz  => 2,
                     x    => 1,
                     wubot_rulelog => { $hostname => [ qw( rule4 rule6 ) ] },
                 },
                   "Checking results for test case 4"
               );
    }
};

# test "rulesfile_field not found on message" => sub {
#     my ($self) = @_;

#     $self->reset_reactor;

#     ok( my $results = $self->reactor->react( { name => 'TestCase3' } ),
#         "Calling react() on the message"
#     );

#     is_deeply( $results,
#                { name => 'TestCase3',
#                  baz  => 1,
#                  wubot_rulelog => { $hostname => [ qw( rule3 rule5 ) ] },
#              },
#                "Calling react() for TestCase3"
#            );
# };



run_me;
done_testing;


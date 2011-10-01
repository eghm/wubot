#!/perl
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More;
use Test::Routine;
use Test::Routine::Util;
use YAML::XS;

use App::Wubot::Logger;
use App::Wubot::Reactor::User;

has reactor => (
    is   => 'ro',
    lazy => 1,
    clearer => 'reset_reactor',
    default => sub {
        my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
        App::Wubot::Reactor::User->new( { directory => $tempdir } );
    },
);

test "test reactor" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    ok( $self->reactor->react(),
        "Checking that test reactor is useable"
    );

    is_deeply( $self->reactor->react( {}, {} ),
               {},
               "Empty message results in no reaction field"
           );

};

test "parse username field" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $config = {};

    is_deeply( $self->reactor->react( { username => 'wu' }, $config ),
               { username      => 'wu',
                 username_orig => 'wu',
             },
               "Checking user reactor when only simple username is set"
           );

    is_deeply( $self->reactor->react( { username => 'dude@somehost.com' }, $config ),
               { username        => 'dude',
                 username_orig   => 'dude@somehost.com',
                 username_domain => 'somehost.com',
             },
               'Checking user reactor for email address dude@somehost.com'
           );

    is_deeply( $self->reactor->react( { username => 'El Duderino <dude@somehost.com>' }, $config ),
               { username        => 'dude',
                 username_orig   => 'El Duderino <dude@somehost.com>',
                 username_domain => 'somehost.com',
                 username_full   => 'El Duderino',
             },
               'Checking email style: El Duderino <dude@somehost.com>'
           );

    is_deeply( $self->reactor->react( { username => '"El Duderino" <dude@somehost.com>' }, $config ),
               { username        => 'dude',
                 username_orig   => '"El Duderino" <dude@somehost.com>',
                 username_domain => 'somehost.com',
                 username_full   => 'El Duderino',
             },
               'Checking email style: "El Duderino" <dude@somehost.com>'
           );

    is_deeply( $self->reactor->react( { username => '"El Duderino"<dude@somehost.com>' }, $config ),
               { username        => 'dude',
                 username_orig   => '"El Duderino"<dude@somehost.com>',
                 username_domain => 'somehost.com',
                 username_full   => 'El Duderino',
             },
               'Checking email style: "El Duderino"<dude@somehost.com>'
           );

    is_deeply( $self->reactor->react( { username => 'dude|idle' }, $config ),
               { username         => 'dude',
                 username_orig    => 'dude|idle',
                 username_comment => 'idle',
             },
               "Checking irc style: dude|idle"
           );
    is_deeply( $self->reactor->react( { username => 'dude{idle}' }, $config ),
               { username        => 'dude',
                 username_orig    => 'dude{idle}',
                 username_comment => 'idle',
             },
               "Checking irc style: dude{idle}"
           );
    is_deeply( $self->reactor->react( { username => 'dude{idle' }, $config ),
               { username        => 'dude',
                 username_orig    => 'dude{idle',
                 username_comment => 'idle',
             },
               "Checking irc style, missing close: dude{idle"
           );

    is_deeply( $self->reactor->react( { username => 'dude(http://www.dudism.com/)' }, $config ),
               { username         => 'dude',
                 username_orig    => 'dude(http://www.dudism.com/)',
                 username_comment => 'http://www.dudism.com/',
             },
               "Checking 'username(http://...)' style"
           );

    is_deeply( $self->reactor->react( { username => 'dude (http://www.dudism.com/)' }, $config ),
               { username         => 'dude',
                 username_orig    => 'dude (http://www.dudism.com/)',
                 username_comment => 'http://www.dudism.com/',
             },
               "Checking 'username (http://...)' style"
           );
};


test "read contact files" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $directory = $self->reactor->directory;

    my $dude = { aliases => [ 'lebowski' ], color => 'red' };
    YAML::XS::DumpFile( "$directory/dude.yaml",  $dude );

    my $walter = { abc => 'def' };
    YAML::XS::DumpFile( "$directory/walter.yaml", $walter );

    my $donny = { abc => 'xyz', def => 'pdq' };
    YAML::XS::DumpFile( "$directory/donny.yaml", $donny );

    $dude->{username} = 'dude';
    $walter->{username} = 'walter';
    $donny->{username} = 'donny';

    is_deeply( $self->reactor->get_user_info( 'dude' ),
               $dude,
               "checking user info for dude"
           );

    is_deeply( $self->reactor->get_user_info( 'walter' ),
               $walter,
               "checking user info for walter"
           );

    is_deeply( $self->reactor->get_user_info( 'donny' ),
               $donny,
               "checking user info for donny"
           );

    is_deeply( $self->reactor->get_user_info( 'lebowski' ),
               $dude,
               "checking user info for dude's alias 'lebowski'"
           );

    is_deeply( $self->reactor->react( { username => 'dude' }, {} ),
               { username       => 'dude',
                 username_orig  => 'dude',
                 color          => 'red',
             },
               "Checking user reactor gets color from user db"
           );

    is_deeply( $self->reactor->react( { username => 'lebowski' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
                 color          => 'red',
             },
               "Checking user reactor gets color and username from user db"
           );

    is_deeply( $self->reactor->react( { username => 'lebowski', color => 'blue' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
                 color          => 'red',
                 color_orig     => 'blue',
             },
               "Checking that username overridden param gets saved to param_orig"
           );

    is_deeply( $self->reactor->react( { username => 'lebowski', color => 'red' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
                 color          => 'red',
             },
               "Checking that username overridden param not saved to param_orig if value is unchanged"
           );

    is_deeply( $self->reactor->react( { username => 'lebowski', color => 'blue', color_orig => 'green' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
                 color          => 'red',
                 color_orig     => 'green',
             },
               "Checking that username overridden param does not overwrite existing param_orig"
           );


};

test "userdb info is not case sensitive" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $directory = $self->reactor->directory;

    my $dude = { aliases => [ 'Lebowski' ], color => 'red' };
    YAML::XS::DumpFile( "$directory/dude.yaml",  $dude );

    $dude->{username} = 'dude';
    $dude->{aliases}  = [ 'lebowski' ];

    is_deeply( $self->reactor->get_user_info( 'dude' ),
               $dude,
               "checking user info for dude"
           );

    is_deeply( $self->reactor->get_user_info( 'Dude' ),
               $dude,
               "checking user info for Dude"
           );

    is_deeply( $self->reactor->get_user_info( 'lebowski' ),
               $dude,
               "checking user info for lebowski"
           );

    is_deeply( $self->reactor->get_user_info( 'Lebowski' ),
               $dude,
               "checking user info for Lebowski"
           );
};

test "read changes to contact files" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $directory = $self->reactor->directory;

    my $dude = { aliases => [ 'lebowski' ] };
    YAML::XS::DumpFile( "$directory/dude.yaml",  $dude );

    is_deeply( $self->reactor->react( { username => 'dude' }, {} ),
               { username       => 'dude',
                 username_orig  => 'dude',
             },
               "Checking user reactor gets read user db file"
           );

    # ensure at least one second has passed so 'lastupdate' time will
    # be different
    sleep 1;

    $dude->{color} = 'red';
    YAML::XS::DumpFile( "$directory/dude.yaml",  $dude );

    is_deeply( $self->reactor->react( { username => 'dude' }, {} ),
               { username       => 'dude',
                 username_orig  => 'dude',
                 color          => 'red',
             },
               "Checking user reactor read in changes to user db file"
           );

    is_deeply( $self->reactor->react( { username => 'lebowski' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
                 color          => 'red',
             },
               "Checking user reactor applied updates to aliases"
           );


};

test "read newly added aliases" => sub {
    my ($self) = @_;

    local $TODO = "need to check all files for newly added aliases";

    $self->reset_reactor;

    my $directory = $self->reactor->directory;

    my $dude = { aliases => [ 'lebowski' ] };
    YAML::XS::DumpFile( "$directory/dude.yaml",  $dude );

    is_deeply( $self->reactor->react( { username => 'lebowski' }, {} ),
               { username       => 'dude',
                 username_orig  => 'lebowski',
             },
               "Checking user reactor gets read user db file"
           );

    # ensure at least one second has passed so 'lastupdate' time will
    # be different
    sleep 1;

    push @{ $dude->{aliases} }, 'el duderino';
    YAML::XS::DumpFile( "$directory/dude.yaml",  $dude );

    is_deeply( $self->reactor->react( { username => 'el duderino' }, {} ),
               { username       => 'dude',
                 username_orig  => 'el duderino',
             },
               "Checking user reactor read in newly added alias"
           );


};


test "broken yaml file" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $directory = $self->reactor->directory;

    my $path = "$directory/dude.yaml";

    open(my $fh, ">", $path )
        or die "Couldn't open $path for writing: $!\n";
    print $fh "---\nfoo: bar\nabc: def: ghi\n\n";
    close $fh or die "Error closing file: $!\n";

    is( $self->reactor->_read_userfile( 'dude' ),
        undef,
        "Checking that no data was returned, but call did not die"
    );

    is( $self->reactor->get_user_info( 'dude' ),
        undef,
        "Checking that no data was returned, but call did not die"
    );

};

test "run rules in contact file" => sub {
    my ($self) = @_;

    $self->reset_reactor;

    my $directory = $self->reactor->directory;

    my $dude = << '...';
---
aliases:
  - lebowski

rules:
  - name: set foo field on messages from the dude
    plugin: SetField
    config:
      field: foo
      value: bar

...

    my $path = "$directory/dude.yaml";
    open(my $fh, ">", $path)
        or die "Couldn't open $path for writing: $!\n";
    print $fh $dude;
    close $fh or die "Error closing file: $!\n";

    is_deeply( $self->reactor->react( { username => 'dude' }, {} )->{foo},
               'bar',
               "Checking that reactor rule ran and set 'foo' to 'bar'"
           );

    is_deeply( $self->reactor->react( { username => 'lebowski' }, {} )->{foo},
               'bar',
               "Checking that reactor rule ran for alias"
           );
};

run_me;
done_testing;

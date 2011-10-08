package App::Wubot::Reactor::User;
use Moose;

# VERSION

# todo
#  - App::Wubot::Util::User
#  - configure class for user in userdb config
#  - other classes could use other contact back-ends, e.g. emacs contacts
#  - role for interface, with method to check if file changed

use YAML::XS;

use App::Wubot::Logger;
use App::Wubot::Reactor;

has 'userdb'      => ( is => 'ro',
                       isa => 'HashRef',
                       lazy => 1,
                       default => sub { {} },
                   );

has 'directory'   => ( is => 'ro',
                       isa => 'Str',
                       lazy => 1,
                       default => sub {
                           return join( "/", $ENV{HOME}, "wubot", "userdb" );
                       },
                   );

has 'logger'      => ( is => 'ro',
                       isa => 'Log::Log4perl::Logger',
                       lazy => 1,
                       default => sub {
                           return Log::Log4perl::get_logger( __PACKAGE__ );
                       },
                   );

has 'lastupdates' => ( is => 'ro',
                        isa => 'HashRef',
                        lazy => 1,
                        default => sub { {} },
                    );

has 'aliases'     => ( is => 'ro',
                       isa => 'HashRef',
                       lazy => 1,
                       default => sub { {} },
                   );

has 'reactor'     => ( is => 'ro',
                       isa => 'App::Wubot::Reactor',
                       lazy => 1,
                       default => sub { return App::Wubot::Reactor->new() },
                   );

sub react {
    my ( $self, $message, $config ) = @_;

    return $message unless $message->{username};

    unless ( $message->{username_orig} ) {
        $message->{username_orig} = $message->{username};
    }

    if ( $message->{username} =~ m|\@| ) {
        $message->{username} =~ m|^(.*)\@(.*)|;

        $message->{username} = $1;

        $message->{username_domain} = $2;
        $message->{username_domain} =~ s|\>$||;

        if ( $message->{username} =~ m|^(.*)\s?\<(.*)$| ) {

            $message->{username_full} = $1;
            $message->{username} = $2;

            $message->{username_full} =~ s|^\s+||;
            $message->{username_full} =~ s|\s$||;

            $message->{username_full} =~ s|^\"||;
            $message->{username_full} =~ s|\"$||;
        }
    }

    if ( $message->{username} =~ m/\|/ ) {
        $message->{username} =~ m/^(.*)\|(.*)$/;
        $message->{username} = $1;
        $message->{username_comment} = $2;
    }

    if ( $message->{username} =~ m/\{.*/ ) {
        $message->{username} =~ m/^(.*)\{([^\}]+)/;
        $message->{username} = $1;
        $message->{username_comment} = $2;
    }

    if ( $message->{username} =~ m/\(http/ ) {
        $message->{username} =~ m/^(.*?)\s*\((http[^\)]+)/;
        $message->{username} = $1;
        $message->{username_comment} = $2;
    }

    if ( my $userdata = $self->get_user_info( $message->{username} ) ) {

        for my $param ( qw( username color image ) ) {

            if (      $userdata->{ $param }
                 &&    $message->{ $param }
                 && !  $message->{ "$param\_orig" }
                 && $message->{$param} ne $userdata->{ $param }
             ) {

                $message->{"$param\_orig"} = $message->{$param};
            }
            if ( $userdata->{ $param } ) {
                $self->logger->debug( "Setting $param for $message->{username}" );
                $message->{$param} = $userdata->{ $param };
            }
        }

        if ( $userdata->{rules} ) {
            $self->reactor->react( $message, $userdata->{rules} );
        }
    }

    return $message;
}

sub get_user_info {
    my ( $self, $username ) = @_;

    $username = lc( $username );

    unless ( keys %{ $self->userdb } ) {
        $self->_read_all_user_info();
    }

    # look up aliases
    if ( $self->aliases->{$username} ) {
        $username = $self->aliases->{$username};
    }

    return unless $self->userdb->{$username};

    # check for updates to user db
    $self->_read_userfile( $username );

    return $self->userdb->{$username};
}

sub _read_all_user_info {
    my ( $self ) = @_;

    my $config = {};

    my $directory = $self->directory;

    my $dir_h;
    opendir( $dir_h, $directory ) or die "Can't opendir $directory: $!";
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry;

        my $user = $entry;
        $user =~ s|.yaml$||g;

        $self->_read_userfile( $user );
    }
    closedir( $dir_h );

    return $config;
}

sub _read_userfile {
    my ( $self, $username ) = @_;

    my $path = join( "/", $self->directory, "$username.yaml" );
    return unless -f $path;

    my $mtime = ( stat $path )[9];

    if (    $self->lastupdates->{$username}
         && $self->lastupdates->{$username} == $mtime ) {

        $self->logger->trace( "User db cache is up to date" );
        return;
    }

    my $userdata;
    eval {                          # try
        $userdata = YAML::XS::LoadFile( $path );
        1;
    } or do {                       # catch
        $self->logger->error( "Unable to load yaml file: $path: $@" );
        return;
    };

    $userdata->{username}   = lc( $username );

    $self->lastupdates->{$username} = $mtime;

    $self->userdb->{$username} = $userdata;

    if ( $userdata->{aliases} ) {
        for my $alias ( @{ $userdata->{aliases} } ) {

            $alias = lc( $alias );
            $self->aliases->{$alias} = lc( $username );
        }
    }

}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::Wubot::Reactor::User - try to identify user from the 'username' field


=head1 SYNOPSIS

      - name: user
        plugin: User

=head1 DESCRIPTION

The user reactor will parse the username field.

The original user id will always be preserved in the username_orig
field.  If the username_orig field already exists, it will not be
overwritten.

If the username field contains an email address (e.g. the from on an
mbox monitor message), then the domain will be captured into the
username_domain field.  If the email contains a full name it will be
captured into username_full.  Any leading or trailing quotes or spaces
will be removed from the full username field.

Commonly usernames in IRC may contain some comment such as
username|idle or username{idle}.  Any such comments will be extracted
into the username_comment field.

Any remaining text will be left in the username field.

After this plugin has reacted on the message, you may want to send it
through the Icon reactor to determine if there is an appropriate icon
for the user in your images directory.  For more information, please
see the 'notifications' document.

=head1 USER DATABASE

The user database is still under construction.

You can define information about your contacts in:

  ~/wubot/userdb/{username}.yaml

Here is an example:

  ~/wubot/userdb/dude.yaml

  ---
  color: green
  aliases:
    - lebowski
    - El Duderino
  image: dude.png

If you define a 'color' or an 'image', then any messages that match
the username will have those values set in the message.  This will
override any pre-existing 'color' or 'image' fields.

You can define any aliases for your user in the 'aliases' section of
the config.  This allows you to recognize the same user in case they
have different usernames for email, twitter, etc.  The 'username'
field will be updated to use the username from the file name.  If the
username is modified, the original username will be stored in the
'username_orig' field.

Using the example above, if a message had the username set to
'lebowski', then the following fields would be set on the message:

  username: dude
  username_orig: lebowski
  color: green
  image: dude.png

Each time a message comes through that has a username for which some
user data is defined, the user's file will be scanned to see if it has
been updated.  If so, the userdb file will be re-read.

=head1 RULES

You can now include a custom set of rules to run any time a message is
received from a user by creating a rules tree in the user config file.

  aliases:
    - lebowski

  rules:

    - name: set foo field on messages from the dude
      plugin: SetField
      config:
        field: foo
        value: bar

The rules will run after an other userdb config has been processed.
This means that you could use it to things like set a custom color or
image based on other fields in the message.  For example, you might
set different colors for the user in different feeds, or based on the
user alias being used.

=head1 LIMITATIONS

The file name must be completely lower case, and all usernames and
aliases will automatically be converted to lower case.  This should be
fixed in the future.

Adding an alias to a contact will not yet be automatically re-read if
a message is received from that alias.  In that case it will be
necessary to restart the reactor to pick up the new alias.  This is
because it does not know which file to read when it receives a message
from the new alias.  In the future there should be some mechanism to
scan the directory occasionally to look for changed files that could
contain new aliases.


=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=item get_user_info( $username )

Given a username or alias, look up the information about the user in
the userdb.

=back

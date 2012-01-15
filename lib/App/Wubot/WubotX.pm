package App::Wubot::WubotX;
use Moose;

use YAML::XS;

has 'root' => ( is => 'ro',
                isa => 'Str',
                lazy => 1,
                default => sub {
                    return join( "/", $ENV{HOME}, "wubot", "WubotX" );
                },
            );

has 'plugins' => ( is => 'ro',
                   isa => 'ArrayRef[Str]',
                   lazy => 1,
                   default => sub {
                       return $_[0]->get_plugins();
                   },
               );

sub get_plugins {
    my ( $self ) = @_;

    my @plugins;

    my $directory = $self->root;

    my $dir_h;
    opendir( $dir_h, $directory ) or die "Can't opendir $directory: $!";
    while ( defined( my $entry = readdir( $dir_h ) ) ) {
        next unless $entry;
        next if $entry =~ m|^\.|;

        push @plugins, $entry;

        my $lib_path = join( "/", $directory, $entry, "lib" );
        if ( -d $lib_path ) {
            print "Adding WubotX lib path: $lib_path\n";
            push @INC, $lib_path;
        }
    }

    closedir( $dir_h );

    return \@plugins;
}

sub get_webui {
    my ( $self ) = @_;

    my $webui_config;

    for my $plugin ( @{ $self->plugins } ) {

        my $path = join( "/", $self->root, $plugin, "webui.yaml" );

        next unless -r $path;

        my $config = YAML::XS::LoadFile( $path );

        for my $key ( keys %{ $config } ) {
            $webui_config->{ $plugin }->{ $key } = $config->{ $key };
        }
    }

    print YAML::XS::Dump $webui_config;

    return $webui_config;

}

sub link_templates {
    my ( $self ) = @_;

  PLUGIN:
    for my $plugin ( @{ $self->plugins } ) {

        my @templates;

        my $directory = join( "/", $self->root, $plugin, "templates" );
        next PLUGIN unless -d $directory;

        my $dir_h;
        opendir( $dir_h, $directory ) or die "Can't opendir $directory: $!";
        while ( defined( my $entry = readdir( $dir_h ) ) ) {
            next unless $entry;
            next if $entry =~ m|^\.|;

            push @templates, $entry;
        }
        closedir( $dir_h );

        for my $template ( @templates ) {

            # skip template if it already exists in the global templates directory
            next if -r "templates/$template";

            # hard-link the template
            print "Linking template from plugin $plugin: $template\n";
            system( "ln", "$directory/$template", "templates/" );
        }

    }
}

1;

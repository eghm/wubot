package App::Wubot::Web;
use strict;
use warnings;

# VERSION

use Mojo::Base 'Mojolicious';

use YAML::XS;

use App::Wubot::Logger;
use App::Wubot::WubotX;

my $wubotx = App::Wubot::WubotX->new();

my $config_file = join( "/", $ENV{HOME}, "wubot", "config", "webui.yaml" );

my $config = YAML::XS::LoadFile( $config_file );

my $logger = Log::Log4perl::get_logger( __PACKAGE__ );

# This method will run once at server start
sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc" (this plugin requires Perl 5.10)
    #$self->plugin('PODRenderer');

    # Routes
    my $r = $self->routes;

    for my $plugin ( keys %{ $config->{plugins} } ) {

        my $plugin_name = join( "", ucfirst( $plugin ), "Web" );

        for my $route ( keys %{ $config->{plugins}->{$plugin} } ) {

            my $method = $config->{plugins}->{$plugin}->{$route};

            $logger->info( "ROUTE: $route => $plugin_name#$method" );
            $r->route( $route )->to( "$plugin_name#$method" );

        }
    }

    # WubotX extensions, eventually to replace the code above
    $wubotx->link_templates();
    my $extensions = $wubotx->get_webui();

    $logger->debug( YAML::XS::Dump { lib => \@INC } );

    for my $plugin ( keys %{ $extensions } ) {

        my $plugin_name = join( "", ucfirst( $plugin ), "Web" );

        $logger->warn( "PLUGIN: $plugin => $plugin_name" );

        for my $route ( keys %{ $extensions->{$plugin} } ) {

            my $method = $extensions->{$plugin}->{$route};

            $logger->info( "ROUTEX: $route => $plugin_name#$method" );
            $r->route( $route )->to( "$plugin_name#$method" );

        }
    }

}

1;

__END__

=head1 NAME

App::Wubot::Web - Mojolicious web interface for wubot

=head1 DESCRIPTION

For more information on the wubot web user interface, please see the
document L<App::Wubot::Guide::WebUI>.

The wubot web interface is still under construction.  There will be
more information here in the future.

TODO: finish docs

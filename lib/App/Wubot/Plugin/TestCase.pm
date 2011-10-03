package App::Wubot::Plugin::TestCase;
use Moose;

# VERSION

use App::Wubot::Logger;

with 'App::Wubot::Plugin::Roles::Cache';
with 'App::Wubot::Plugin::Roles::Plugin';

sub check {
    my ( $self, $inputs ) = @_;

    my $cache  = $inputs->{cache};
    my $config = $inputs->{config};

    if ( $config->{die} ) {
        die "Testing Error"
    }

    my $react;

    # just setting the cache params in the config
    for my $key ( keys %{ $config } ) {

        # don't handle the 'tags' config, that is done in the check() layer
        next if $key eq "tags";

        $cache->{$key}   = $config->{$key};
        $react->{ $key } = $config->{$key};
    }

    return { cache => $cache, react => [ $react ] };
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::Wubot::Plugin::TestCase - a plugin for testing purposes

=head1 DESCRIPTION

Not much to see here.  This plugin is only useful for testing.


=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back

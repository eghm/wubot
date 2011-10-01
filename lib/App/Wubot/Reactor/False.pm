package App::Wubot::Reactor::False;
use Moose;

# VERSION

use App::Wubot::Logger;

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

sub react {
    my ( $self, $message, $config ) = @_;

    unless ( $message->{ $config->{field} } ) {

        $self->logger->debug( "matched => $config->{field} is false" );

        for my $key ( keys %{ $config->{set} } ) {

            $self->logger->debug( "setting field $key to $config->{set}->{$key}" );
            $message->{ $key } = $config->{set}->{$key};

        }
    }

    return $message;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

App::Wubot::Reactor::False - set keys and values if a field is false


=head1 DESCRIPTION

This plugin is deprecated!

Please use the 'is false' condition in combination with the 'SetField'
reactor plugin:

  - name: 'test' field does not contain a value
    condition: test is false
    plugin: SetField
    config:
      set:
        key1: value1
        key2: value2

See the 'conditions' document for more information.

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back

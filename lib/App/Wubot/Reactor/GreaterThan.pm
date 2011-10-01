package App::Wubot::Reactor::GreaterThan;
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

    my $field_data = $message->{ $config->{field} };

    if ( $field_data >= $config->{minimum} ) {

        $self->logger->debug( "matched => $config->{field} data $field_data greater than $config->{minimum}" );

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

App::Wubot::Reactor::GreaterThan - set keys and values if the value of a field exceeds a value


=head1 DESCRIPTION

This plugin is deprecated!

Please use the '>' condition in combination with the 'SetField'
reactor plugin:

  - name: 'test' field is greater than 5
    condition: test > 5
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

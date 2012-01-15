package App::Wubot::Reactor::Dumper;
use Moose;

# VERSION

use YAML::XS;

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

    if ( $config->{field} ) {
        print YAML::XS::Dump $message->{ $config->{field} };
    }
    else {
        print YAML::XS::Dump $message;
    }

    return $message;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

App::Wubot::Reactor::Dumper - display the contents of a field or an entire message


=head1 SYNOPSIS

  - name: dump message contents to stdout
    plugin: Dumper

  - name: display contents of message field 'x'
    plugin: Dumper
    config:
      field: x


=head1 DESCRIPTION

Display the contents of a message field to stdout.  This is primary
intended as a debugging tool, e.g. to see how a message looks at some
point in the rule tree.

If no configuration is specified, then the entire message will be
displayed to stdout using YAML::XS::Dump.  If a field is specified in
the config, then the contents of that field will be dumped using
YAML::Dump.

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back

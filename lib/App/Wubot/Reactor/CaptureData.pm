package App::Wubot::Reactor::CaptureData;
use Moose;

# VERSION

# todo: enable using Regexp::Common regexps here

use App::Wubot::Logger;

sub react {
    my ( $self, $message, $config ) = @_;

    my $field_data = $message->{ $config->{source_field} || $config->{field} };

    return $message unless $field_data;

    my $regexp;
    if ( $config->{regexp_field} ) {
        $regexp = $message->{ $config->{regexp_field} };
    }
    elsif ( $config->{regexp} ) {
        $regexp = $config->{regexp};
    }

    my $target_field = $config->{target_field} || $config->{field} || $config->{source_field};

    if ( $field_data =~ m|$regexp|s ) {
        if ( $1 ) {
            $message->{ $target_field } = $1;
        }
    }

    return $message;
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

App::Wubot::Reactor::CaptureData - capture data from a field using a regexp


=head1 SYNOPSIS

  - name: capture data from 'title' field and store captured data in 'size' field
    plugin: CaptureData
    config:
      source_field: title
      regexp: '^M ([\d\.]+),'
      target_field: size

  - name: capture data from 'title' field, get there regexp from 'somefield', and store results in 'foo'
    plugin: CaptureData
    config:
      source_field: abc
      regexp_field: somefield
      target_field: foo

  - name: get first group of digits from field 'x' and replace contents of 'x' field with captured digits
    plugin: CaptureData
    config:
      field: x
      regexp: '([\d\.]+),'

=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back

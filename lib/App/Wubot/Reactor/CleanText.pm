package App::Wubot::Reactor::CleanText;
use Moose;

# VERSION

use App::Wubot::Logger;

sub react {
    my ( $self, $message, $config ) = @_;

    my $text = $message->{ $config->{source_field } };

    my $regexp_search = $config->{regexp_search};
    return $message unless $regexp_search;

    $text =~ s|$regexp_search||sg;

    $message->{ $config->{target_field}||$config->{source_field} } = $text;

    return $message;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::Wubot::Reactor::CleanText - clean a field using a regexp

=head1 SYNOPSIS

  - name: remove tables
    plugin: CleanText
    config:
      source_field: body
      regexp_search: '<table.*?</table>'


=head1 DESCRIPTION

TODO: More to come...


=head1 SUBROUTINES/METHODS

=over 8

=item react( $message, $config )

The standard reactor plugin react() method.

=back

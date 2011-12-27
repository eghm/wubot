package App::Wubot::Util::Colors;
use Moose;

# VERSION

# solarized color schema: http://ethanschoonover.com/solarized
my $pretty_colors = { pink      => '#660033',
                      yellow    => '#5a4400',
                      orange    => '#65250b',
                      red       => '#6e1917',
                      magenta   => '#3b003b',
                      brmagenta => '#691b41',
                      violet    => '#363862',
                      blue      => '#134569',
                      darkblue  => '#092234',
                      cyan      => '#15504c',
                      green     => '#424c00',
                      black     => '#191919',
                      brblack   => '#00151b',
                      brgreen   => '#2c373a',
                      bryellow  => '#323d41',
                      brblue    => '#414a4b',
                      brcyan    => '#495050',
                      white     => '#77746a',
                      brwhite   => '#7e7b71',
                      purple    => 'magenta',
                      dark      => 'black',
                      default   => 'black',
                  };

# color aliases
for my $color ( sort keys %{ $pretty_colors } ) {
    my $value = $pretty_colors->{$color};
    if ( $pretty_colors->{ $value } ) {
        $pretty_colors->{$color} = $pretty_colors->{ $value };
    }
}

sub get_color {
    my ( $self, $color ) = @_;

    return $pretty_colors->{default} unless $color;

    if ( $pretty_colors->{$color} ) {
        return $pretty_colors->{$color};
    }

    return $color;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

App::Wubot::Util::Colors - color themes for wubot

=head1 DESCRIPTION

This module defines color codes for named colors for the wubot web ui.

The web ui is still under development.  Current the colors are
hard-coded.  In the future these will be configurable.

The current colors are based on the solarized color schema.  For more info, see:

  http://ethanschoonover.com/solarized

Here is the current color names represent the following hex codes:

  black      #333333
  blue       #268bd2
  brblack    #002b36
  brblue     #839496
  brcyan     #93a1a1
  brgreen    #586e75
  brmagenta  #d33682
  brwhite    #fdf6e3
  bryellow   #657b83
  cyan       #2aa198
  dark       black
  green      #859900
  magenta    #770077
  orange     #cb4b16
  pink       #FF33FF
  purple     magenta
  red        #dc322f
  violet     #6c71c4
  white      #eee8d5
  yellow     #b58900


TODO: finish docs

=head1 SUBROUTINES/METHODS

=over 8

=item $obj->get_color( $color_name )

if there is a hex code defined in the theme for the specified color
name, return that hex code.

If called with a hex color or a color name that is not defined in the
theme, just returns the text that was passed in.

=back



package App::Wubot::Util::Colors;
use Moose;

# VERSION

# solarized color schema: http://ethanschoonover.com/solarized
my $pretty_colors = { pink                 => '#660033',
                      yellow               => '#5a4400',
                      orange               => '#65250b',
                      red                  => '#6e1917',
                      magenta              => '#3b003b',
                      brmagenta            => '#691b41',
                      violet               => '#363862',
                      blue                 => '#134569',
                      darkblue             => '#092234',
                      cyan                 => '#15504c',
                      green                => '#424c00',
                      black                => '#191919',
                      brblack              => '#00151b',
                      brgreen              => '#2c373a',
                      bryellow             => '#323d41',
                      brblue               => '#414a4b',
                      brcyan               => '#495050',
                      white                => '#77746a',
                      brwhite              => '#7e7b71',
                      purple               => 'magenta',
                      dark                 => 'black',
                      default              => 'black',

                      aliceblue            => '#F0F8FF',
                      antiquewhite         => '#FAEBD7',
                      aqua                 => '#00FFFF',
                      aquamarine           => '#7FFFD4',
                      azure                => '#F0FFFF',
                      beige                => '#F5F5DC',
                      bisque               => '#FFE4C4',
                      xblack               => '#000000',
                      blanchedalmond       => '#FFEBCD',
                      xblue                => '#0000FF',
                      blueviolet           => '#8A2BE2',
                      brown                => '#A52A2A',
                      burlywood            => '#DEB887',
                      cadetblue            => '#5F9EA0',
                      chartreuse           => '#7FFF00',
                      chocolate            => '#D2691E',
                      coral                => '#FF7F50',
                      cornflowerblue       => '#6495ED',
                      cornsilk             => '#FFF8DC',
                      crimson              => '#DC143C',
                      xcyan                => '#00FFFF',
                      xdarkblue            => '#00008B',
                      darkcyan             => '#008B8B',
                      darkgoldenrod        => '#B8860B',
                      darkgray             => '#A9A9A9',
                      darkgreen            => '#006400',
                      darkgrey             => '#A9A9A9',
                      darkkhaki            => '#BDB76B',
                      darkmagenta          => '#8B008B',
                      darkolivegreen       => '#556B2F',
                      darkorange           => '#FF8C00',
                      darkorchid           => '#9932CC',
                      darkred              => '#8B0000',
                      darksalmon           => '#E9967A',
                      darkseagreen         => '#8FBC8F',
                      darkslateblue        => '#483D8B',
                      darkslategray        => '#2F4F4F',
                      darkslategrey        => '#2F4F4F',
                      darkturquoise        => '#00CED1',
                      darkviolet           => '#9400D3',
                      deeppink             => '#FF1493',
                      deepskyblue          => '#00BFFF',
                      dimgray              => '#696969',
                      dimgrey              => '#696969',
                      dodgerblue           => '#1E90FF',
                      firebrick            => '#B22222',
                      floralwhite          => '#FFFAF0',
                      forestgreen          => '#228B22',
                      fuchsia              => '#FF00FF',
                      gainsboro            => '#DCDCDC',
                      ghostwhite           => '#F8F8FF',
                      gold                 => '#FFD700',
                      goldenrod            => '#DAA520',
                      gray                 => '#808080',
                      xgreen               => '#008000',
                      greenyellow          => '#ADFF2F',
                      grey                 => '#808080',
                      honeydew             => '#F0FFF0',
                      hotpink              => '#FF69B4',
                      indianred            => '#CD5C5C',
                      indigo               => '#4B0082',
                      ivory                => '#FFFFF0',
                      khaki                => '#F0E68C',
                      lavender             => '#E6E6FA',
                      lavenderblush        => '#FFF0F5',
                      lawngreen            => '#7CFC00',
                      lemonchiffon         => '#FFFACD',
                      lightblue            => '#ADD8E6',
                      lightcoral           => '#F08080',
                      lightcyan            => '#E0FFFF',
                      lightgoldenrodyellow => '#FAFAD2',
                      lightgray            => '#D3D3D3',
                      lightgreen           => '#90EE90',
                      lightgrey            => '#D3D3D3',
                      lightpink            => '#FFB6C1',
                      lightsalmon          => '#FFA07A',
                      lightseagreen        => '#20B2AA',
                      lightskyblue         => '#87CEFA',
                      lightslategray       => '#778899',
                      lightslategrey       => '#778899',
                      lightsteelblue       => '#B0C4DE',
                      lightyellow          => '#FFFFE0',
                      lime                 => '#00FF00',
                      limegreen            => '#32CD32',
                      linen                => '#FAF0E6',
                      xmagenta             => '#FF00FF',
                      maroon               => '#800000',
                      mediumaquamarine     => '#66CDAA',
                      mediumblue           => '#0000CD',
                      mediumorchid         => '#BA55D3',
                      mediumpurple         => '#9370DB',
                      mediumseagreen       => '#3CB371',
                      mediumslateblue      => '#7B68EE',
                      mediumspringgreen    => '#00FA9A',
                      mediumturquoise      => '#48D1CC',
                      mediumvioletred      => '#C71585',
                      midnightblue         => '#191970',
                      mintcream            => '#F5FFFA',
                      mistyrose            => '#FFE4E1',
                      moccasin             => '#FFE4B5',
                      navajowhite          => '#FFDEAD',
                      navy                 => '#000080',
                      oldlace              => '#FDF5E6',
                      olive                => '#808000',
                      olivedrab            => '#6B8E23',
                      xorange              => '#FFA500',
                      orangered            => '#FF4500',
                      orchid               => '#DA70D6',
                      palegoldenrod        => '#EEE8AA',
                      palegreen            => '#98FB98',
                      paleturquoise        => '#AFEEEE',
                      palevioletred        => '#DB7093',
                      papayawhip           => '#FFEFD5',
                      peachpuff            => '#FFDAB9',
                      peru                 => '#CD853F',
                      xpink                => '#FFC0CB',
                      plum                 => '#DDA0DD',
                      powderblue           => '#B0E0E6',
                      xpurple              => '#800080',
                      xred                 => '#FF0000',
                      rosybrown            => '#BC8F8F',
                      royalblue            => '#4169E1',
                      saddlebrown          => '#8B4513',
                      salmon               => '#FA8072',
                      sandybrown           => '#F4A460',
                      seagreen             => '#2E8B57',
                      seashell             => '#FFF5EE',
                      sienna               => '#A0522D',
                      silver               => '#C0C0C0',
                      skyblue              => '#87CEEB',
                      slateblue            => '#6A5ACD',
                      slategray            => '#708090',
                      slategrey            => '#708090',
                      snow                 => '#FFFAFA',
                      springgreen          => '#00FF7F',
                      steelblue            => '#4682B4',
                      tan                  => '#D2B48C',
                      teal                 => '#008080',
                      thistle              => '#D8BFD8',
                      tomato               => '#FF6347',
                      turquoise            => '#40E0D0',
                      xviolet              => '#EE82EE',
                      wheat                => '#F5DEB3',
                      xwhite               => '#FFFFFF',
                      whitesmoke           => '#F5F5F5',
                      x11yellow            => '#FFFF00',
                      yellowgreen          => '#9ACD32',
                  };

# read colors from external config file on startup
my $colorfile = join( "/", $ENV{HOME}, "wubot", "config", "colors.yaml" );
if ( -r $colorfile ) {
    my $custom_colors = YAML::XS::LoadFile( $colorfile );
    for my $color ( keys %{ $custom_colors } ) {
        print "COLOR: $color => $custom_colors->{$color}\n";
        $pretty_colors->{ $color } = '#' . $custom_colors->{ $color };
    }
}

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

    return $pretty_colors->{$color} if $pretty_colors->{$color};

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

This module handles translating color names to hex color codes.

You can define your own custom colors in ~/wubot/config/colors.yaml

  ---
  names:
    pink: 6c003f
    purple: 440066
    blue: 002b66
    green: 004a00
    yellow: 656500
    orange: 804c00
    red: 620000
    brblue: 004d66
    darkblue: 110066

The default colors are based on the solarized color schema.  For more info, see:

  http://ethanschoonover.com/solarized

For a complete list of colors, check out the source code.
=head1 SUBROUTINES/METHODS

=over 8

=item $obj->get_color( $color_name )

if there is a hex code defined in the theme for the specified color
name, return that hex code.

If called with a hex color or a color name that is not defined in the
theme, just returns the text that was passed in.

=back



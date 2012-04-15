package App::Wubot::Util::TimeLength;
use Moose;

# VERSION

use POSIX;
use YAML::XS;

use App::Wubot::Logger;

=head1 NAME

App::Wubot::Util::TimeLength - utilities for dealing with time durations


=head1 SYNOPSIS

    use App::Wubot::Util::TimeLength;

    my $timelength = App::Wubot::Util::TimeLength->new();

    # returns '1h1m'
    $timelength->get_human_readable( 3601 );

    # returns 1.5
    $timelength->get_hours( 60*60*1.5 );

    # returns 3601
    $timelength->get_seconds( '1h1s' );

    # rounds 1.5 days, 1 minute, and 10 seconds to nearest hour: 1d12h
    $timelength->get_human_readable( 60*60*24*1.5+70 )

    # use a space delimiter
    my $timelength = App::Wubot::Util::TimeLength->new( space => 1 ),

    # returns '1h 1s' with space delimiter
    $timelength->get_human_readable( 3601 );


=head1 DESCRIPTION

This class provides some utilities for dealing with time durations.
It supports the 'compact' form used by L<Convert::Age>, but with a few
variations.

For the sake of simplicity, one month is always treated as 30 days,
and one year is always represented as 365 days.

=cut

has 'space' => ( is => 'ro', isa => 'Bool', default => 0 );

my $constants = { s => 1,
                  m => 60,
                  h => 60*60,
                  d => 60*60*24,
                  w => 60*60*24*7,
                  M => 60*60*24*30,
                  y => 60*60*24*365,
              };

# my $colorfile = join( "/", $ENV{HOME}, "wubot", "config", "colors.yaml" );
# my $config = YAML::XS::LoadFile( $colorfile );
# my $colors;
# for my $key ( qw( s m h d w M y ) ) {
#     next unless $config->{$key\\\\};

#     my @rgb = map { hex($_) } unpack 'a2a2a2', $hex;


# }
# #    my $hex = 
# #    $colors->{$key} = [ split /,/, $config->{ages}->{$key} ];
# }

=head1 SUBROUTINES/METHODS

=over 8

=item $obj->get_seconds( $time );

When given a date in the 'compact' form (e.g. '1h1m' or '1h 1m'),
returns the number of seconds.

=cut

sub get_seconds {
    my ( $self, $time ) = @_;

    my $seconds = 0;

    return $seconds unless $time;

    $time =~ s|^\+||;

    # space-separate time fields for easier split
    $time =~ s|([a-z])|$1 |;

    for my $part ( split /\s+/, $time ) {

        if ( $part =~ m|^(\-?[\d\.]+)(\w)$| && $constants->{$2} ) {
            $seconds += $1 * $constants->{$2};
        }
        elsif ( $part =~ m|^(\-?\d+)$| ) {
            $seconds += $1;
        }
        elsif ( $part =~ m|^(\w)$| && $constants->{$1} ) {
            # empty = 0 more seconds
        }
        else {
            die "ERROR: unable to parse time: $part";
        }
    }

    return $seconds;

}

=item $obj->get_human_readable( $seconds );

Given a number of seconds, return the time in 'compact' form.  For
example, '3601' seconds returns '1h1s'.

Time lengths are rounded to the most significant two fields.  For
example, 1 day, 1 hour, 1 minute, and 1 second would be rounded to
1d1h.  Obviously this method is not intended for precise time
calculations, but rather for human-friendly ones.  Please don't try to
convert a number of seconds to the human-readable format, and then
convert that back to a number of seconds, as it will most likely be
different due to rounding!!! If you need a more precise calculation,
use L<Convert::Age>.

If the 'space' option was set at construction time, then a space
delimiter will be used in the resulting string, e.g. '1h 1m'.

=cut

sub get_human_readable {
    my ( $self, $time ) = @_;

    my $seconds = $self->get_seconds( $time );
    my $orig_seconds = $seconds;
    my $abs_seconds  = abs( $seconds );

    return '0s' unless $seconds;

    my $sign = "";
    if ( $seconds < 0 ) {
        $sign = "-";
        $seconds = -1 * $seconds;
    }

    my @string;

  TIME:
    for my $time ( qw( y M w d h m s ) ) {

        if ( $time eq "s" ) {
            next TIME if $abs_seconds > $constants->{h};
        }
        elsif ( $time eq "m" ) {
            next TIME if $abs_seconds > $constants->{d};
        }
        elsif ( $time eq "h" ) {
            next TIME if $abs_seconds > $constants->{w};
        }
        elsif ( $time eq "d" ) {
            next TIME if $abs_seconds > $constants->{M};
        }
        elsif ( $time eq "w" ) {
            next TIME if $abs_seconds > $constants->{y};
        }

        my $num_seconds = $constants->{ $time };

        if ( $seconds >= $num_seconds ) {

            my $rounded = int( $seconds / $num_seconds );

            push @string, "$rounded$time";

            $seconds -= int( $num_seconds * $rounded );
        }

        last TIME unless $seconds;
    }

    my $join = "";
    if ( $self->space ) {
        $join = " ";
    }

    return $sign . join( $join, @string );
}

=item $obj->get_hours( $seconds )

Given a number of seconds, return the number of hours rounded to a
single digit.

=cut

sub get_hours {
    my ( $self, $seconds ) = @_;

    my $num_seconds = $constants->{h};

    return int( $seconds / $num_seconds * 10 ) / 10;

}

=item $obj->get_age_color( $seconds )

Given a number of seconds, return a color representing the age.  This
helps to very quickly assess the age of an item by looking at the
color.  A steady stream of items with evenly spaced ages will create a
smooth gradient of color.  Different colors are used to represent the
age in minutes, hours, days, or months.

The colors will be moved off to a config file in the future.

=cut

sub get_age_color {
    my ( $self, $seconds ) = @_;

    # solarized
    # my $colors = { 'h' => [ 211,  54, 130,  108, 113, 196    ],
    #                'd' => [ 108, 113, 196,   38, 139, 210   ],
    #                'w' => [  38, 139, 210,  133, 153,   0    ],
    #                'M' => [ 133, 153,   0,  181, 137,   0    ],
    #                'y' => [ 181, 137,   0,  220,  50,  47, 2 ],
    #            };

    # spectrum
    # my $colors = { 'h' => [ 255,   0, 255,    0,   0, 255    ],
    #                'd' => [   0,   0, 255,    0, 200,   0    ],
    #                'w' => [   0, 200,   0,  200, 200,   0    ],
    #                'M' => [ 200, 200,   0,  200,   0,   0    ],
    #                'y' => [ 200,   0,   0,    0,   0,   0, 2 ],
    #            };

    # my $colors = { 'h' => [ 102,   0,  77,   54,  56,  98    ],
    #                'd' => [  54,  56,  98,   19,  69, 105    ],
    #                'w' => [  19,  69, 105,   66,  77,   0    ],
    #                'M' => [  66,  76,   0,  110,  25,  23    ],
    #                'y' => [  50,  50,  50,    0,   0,   0, 2 ],

    my $colors = { 'h' => [ 114,0,122, 40,0,122 ],
                   'd' => [ 0,27,122,  0, 102, 102 ],
                   'w' => [ 0, 102, 102,  66, 133, 0 ],
                   'M' => [ 66,133,0, 153,102,0 ],
                   'y' => [ 153,102,0, 0,0,0, 2 ],
               };

    my $previous = 0;

    for my $age ( qw( h d w M y ) ) {

        next unless $colors->{$age};

        my $color_a = $colors->{ $age };
        my $multiplier = $color_a->[6] || 1;

        my $max = $constants->{ $age } * $multiplier;

        if ( $seconds < $max ) {


            my $r = $self->_range_map( $seconds, $previous, $max, $color_a->[0], $color_a->[3] );
            my $g = $self->_range_map( $seconds, $previous, $max, $color_a->[1], $color_a->[4] );
            my $b = $self->_range_map( $seconds, $previous, $max, $color_a->[2], $color_a->[5] );

            return $self->_get_hex_color( $r, $g, $b );
        }

        $previous = $constants->{$age};
    }

}

sub _get_hex_color {
    my ( $self, $r, $g, $b ) = @_;

    my $color = "#";

    for my $col ( $r, $g, $b ) {
        $color .= sprintf( "%02x", $col );
    }

    return $color;
}

sub _range_map {
    my ( $self, $value, $low1, $high1, $low2, $high2 ) = @_;

    my $orig_value = $value;

    # ensure value is within low1 and high1
    if    ( $value < $low1  ) { $value = $low1  }
    elsif ( $value > $high1 ) { $value = $high1 }

    my $ratio = ( $high2 - $low2 ) / ( $high1 - $low1 );

    $value -= $low1;

    $value *= $ratio;

    $value += $low2;

    #print "MAP: $orig_value => $value [ $low1 .. $high1 ] [ $low2 .. $high2 ]\n";

    return $value;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=back

=head1 SEE ALSO

L<Convert::Age>



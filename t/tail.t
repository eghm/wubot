#!/perl
use strict;

use Capture::Tiny qw/capture/;
use File::Temp qw/ tempdir /;
use Test::Exception;
use Test::More;
use Test::Routine;
use Test::Routine::Util;

use App::Wubot::Logger;
use App::Wubot::Util::Tail;

$| = 1;

has tail => (
    is   => 'ro',
    lazy => 1,
    clearer => 'reset_tail',
    default => sub {
        my $self = shift;

        delete $self->{lines};
        delete $self->{warn};

        my $tempdir = tempdir( "/tmp/tmpdir-XXXXXXXXXX", CLEANUP => 1 );
        my $path = "$tempdir/file1.log";

        return App::Wubot::Util::Tail->new( {
            path           => $path,
            callback       => sub { push @{ $self->{lines} }, @_ },
            reset_callback => sub { push @{ $self->{warn}  }, @_ },
        } ),
    },
);





test "reads no new lines on non-existent file" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    is( $self->tail->get_lines(),
        undef,
        "Checking that undef lines read on non-existent file"
    );
};

test "reads no new lines on empty file" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "touch $path" );

    is( $self->tail->get_lines(),
        0,
        "Checking that 0 lines read on empty file"
    );
};

test "seeks to end of file on open" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "echo line0 >> $path" );
    system( "echo line0 >> $path" );

    is( $self->tail->get_lines(),
        0,
        "Calling get_lines() on file that exists but has had no writes since open"
    );
};

test "reads new lines from file after open" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "echo line0 >> $path" );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new lines in file"
    );

    is_deeply( $self->{lines},
               [ 'line1', 'line2' ],
               "Checking lines read from file"
           );
};


test "reads no new lines immediately after reading all new lines" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "echo line0 >> $path" );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    $self->tail->get_lines();

    is( $self->tail->get_lines(),
        0,
        "Got 0 new lines after getting lines once"
    );
};

test "reads new lines and then read some more new lines" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "echo line0 >> $path" );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new lines in file"
    );

    is_deeply( $self->{lines},
               [ 'line1', 'line2' ],
               "Checking lines read from file"
           );

    delete $self->{lines};

    system( "echo line3 >> $path" );
    system( "echo line4 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new more lines in file"
    );

    is_deeply( $self->{lines},
               [ 'line3', 'line4' ],
               "Checking more lines read from file"
           );
};

test "truncate file handle" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "echo line0 >> $path" );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new lines in file"
    );

    is_deeply( $self->{lines},
               [ 'line1', 'line2' ],
               "Checking lines read from file"
           );

    delete $self->{lines};

    system( "echo line3 > $path" );
    system( "echo line4 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new more lines in file"
    );

    is_deeply( $self->{lines},
               [ 'line3', 'line4' ],
               "Checking more lines read from file"
           );

    like( $self->{warn}->[0],
          qr/file was truncated: $path/,
          "Checking for 'file was truncated' warning"
      );

};


test "truncate file handle with rename detection disabled" => sub {
    my ($self) = @_;

    $self->reset_tail;

    ok( ! $self->tail->detect_rename( 0 ),
        "Turning detect_rename off"
    );

    my $path = $self->tail->path;

    system( "echo line0 >> $path" );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new lines in file"
    );

    is_deeply( $self->{lines},
               [ 'line1', 'line2' ],
               "Checking lines read from file"
           );

    delete $self->{lines};

    system( "echo line3 > $path" );
    system( "echo line4 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new more lines in file"
    );

    is_deeply( $self->{lines},
               [ 'line3', 'line4' ],
               "Checking more lines read from file"
           );

    like( $self->{warn}->[0],
          qr/file was truncated: $path/,
          "Checking for 'file was truncated' warning"
      );

};


test "rename file" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "touch", $path );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    $self->tail->get_lines();
    delete $self->{lines};

    unlink( $path );
    sleep 1;
    system( "echo line3 >> $path" );
    system( "echo line4 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new more lines in file after rename"
    );

    is_deeply( $self->{lines},
               [ 'line3', 'line4' ],
               "Checking lines read from file after rename"
           );

    like( $self->{warn}->[0],
          qr/file was renamed: $path/,
          "Checking for 'file was renamed' warning"
      );

};

test "rename file with detect_rename disabled" => sub {
    my ($self) = @_;

    $self->reset_tail;

    ok( ! $self->tail->detect_rename( 0 ),
        "Turning detect_rename off"
    );

    my $path = $self->tail->path;

    system( "touch", $path );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    $self->tail->get_lines();
    delete $self->{lines};

    unlink( $path );
    sleep 1;
    system( "echo line3 >> $path" );
    system( "echo line4 >> $path" );

    is( $self->tail->get_lines(),
        0,
        "Got 0 new more lines in file after rename"
    );
};

test "move and recreate" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "echo line0 >> $path" );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new lines in file"
    );

    is_deeply( $self->{lines},
               [ 'line1', 'line2' ],
               "Checking lines read from file"
           );

    delete $self->{lines};

    system( "mv $path $path.old" );
    sleep 1;
    system( "echo line8 >> $path" );
    system( "echo line9 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new more lines in file after rename"
    );

    is_deeply( $self->{lines},
               [ 'line8', 'line9' ],
               "Checking lines read from file after rename"
           );

    like( $self->{warn}->[0],
          qr/file was renamed: $path/,
          "Checking for 'file was renamed' warning"
      );

};

test "truncate file to same length" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "echo line0 >> $path" );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Got 2 new lines in file"
    );

    is_deeply( $self->{lines},
               [ 'line1', 'line2' ],
               "Checking lines read from file"
           );

    delete $self->{lines};

    sleep 1;
    system( "echo line3 > $path" );
    system( "echo line4 >> $path" );
    system( "echo line5 >> $path" );

    is( $self->tail->get_lines(),
        3,
        "Got 2 new more lines in file after truncating and rebuilding to same length"
    );

    is_deeply( $self->{lines},
               [ 'line3', 'line4', 'line5' ],
               "Checking lines read from file after rename"
           );

    like( $self->{warn}->[0],
          qr/file was renamed: $path/,
          "Checking for 'file was renamed' warning"
      );

};

#
# the conditions for this bug:
#   - get_lines is called
#   - file was truncated
#   - file was appended to, and grew beyond the size it was at the last read
#   - get_lines called again--this is where the bug happens
#
# the specifics of the bug:
#   reading from the filehandle will not return any lines before the current
#   location in the file, prior to truncation
#
test "fixme: file truncated, then more lines written than existed at last read" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;

    system( "echo line0 >> $path" );

    $self->tail->get_lines();

    system( "echo line1 >> $path" );
    $self->tail->get_lines();
    delete $self->{lines};

    sleep 1;
    system( "echo line2 > $path" );
    system( "echo line3 >> $path" );
    system( "echo line4 >> $path" );

    is( $self->tail->get_lines(),
        1,
        "fixme: only got one more line from file"
    );

    is_deeply( $self->{lines},
               [ 'line4' ],
               "fixme: Checking lines read from file after rename"
           );

    ok( ! $self->{warn},
        "fixme: no warning generated"
    );

};



test "using 'position'" => sub {
    my ($self) = @_;

    $self->reset_tail;

    my $path = $self->tail->path;
    system( "touch $path" );

    {

        my $position;

        {
            my @lines;

            ok( my $tail = App::Wubot::Util::Tail->new( { path           => $path,
                                                          callback       => sub { push @lines, @_ },
                                                          reset_callback => sub { return },
                                                      } ),
                "Creating new file tail object"
            );

            is( $tail->get_lines(),
                0,
                "Calling get_lines() on file that exists but has had no writes since open"
            );

            system( "echo line1 >> $path" );
            system( "echo line2 >> $path" );

            is( $tail->get_lines(),
                2,
                "Got 2 new lines from file"
            );
            is_deeply( \@lines,
                       [ 'line1', 'line2' ],
                       "Checking lines read from file"
                   );

            $position = $tail->position;

            undef $tail;
        }

        system( "echo line3 >> $path" );
        system( "echo line4 >> $path" );

        {
            my @lines;

            ok( my $tail = App::Wubot::Util::Tail->new( { path           => $path,
                                                          callback       => sub { push @lines, @_ },
                                                          reset_callback => sub { return },
                                                          position       => $position,
                                                      } ),
                "Creating new file tail object"
            );

            is( $tail->get_lines(),
                2,
                "Calling get_lines() on file that was updated before second App::Wubot::Util::Tail object was created"
            );

            is_deeply( \@lines,
                       [ 'line3', 'line4' ],
                       "Checking lines read from file"
                   );
        }

    }
};

test "seek position beyond end of file" => sub {
    my ($self) = @_;

    $self->reset_tail;

    ok( $self->tail->position( 1024 ),
        "Setting position beyond end of file"
    );

    my $path = $self->tail->path;

    system( "echo line1 >> $path" );
    system( "echo line2 >> $path" );

    is( $self->tail->get_lines(),
        2,
        "Read all new lines in file"
    );

    like( $self->{warn}->[0],
          qr/file was truncated: $path/,
          "Checking for 'file was truncated' warning"
      );

};


run_me;
done_testing;






#         # refresh interval
#         sleep 1;
#         system( "echo line15 > $path" );

#         {
#             # setting count back to 0
#             $self->tail->count(   0 );
#             $self->tail->refresh( 2 );

#             is( $self->tail->get_lines(),
#                 0,
#                 "Got 0 new lines"
#             );

#             is( $self->tail->get_lines(),
#                 1,
#                 "Got 1 new lines from file"
#             );

#             like( $warn[0],
#                   qr/file was truncated: $path/,
#                   "Checking for 'file was truncated' warning"
#               );
#             undef @warn;

#             is_deeply( \@lines,
#                        [ 'line15' ],
#                        "Getting 2 more lines after refresh"
#                    );
#             undef @lines;

#             is( $self->tail->get_lines(),
#                 0,
#                 "Got 0 new lines"
#             );

#         }
#     }


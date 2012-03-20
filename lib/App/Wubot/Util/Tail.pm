package App::Wubot::Util::Tail;
use Moose;

# VERSION

use Fcntl qw( SEEK_END SEEK_CUR SEEK_SET O_NONBLOCK O_RDONLY );

use App::Wubot::Logger;

=head1 NAME

App::Wubot::Util::Tail - follow the tail of a growing file


=head1 SYNOPSIS

    use App::Wubot::Util::Tail;

    # for a complete example, see App::Wubot::Plugin::FileTail


=head1 DESCRIPTION

This class helps build plugins that need to monitor a log file that is
being continuously updated, and execute a bit of code for each new
line.

Once initialized, it holds the filehandle open while wubot is running.
The position in the file can be cached using the standard wubot
caching mechanism.

Plugins that use this library can call get_lines() in the check()
method to process all lines that showed up in the file since the last
time check() was called.  This will execute a callback for each new
line.  In addition, a callback can be defined to run if the filehandle
was reset (i.e. the filehandle was reopened or the file was
truncated).

=cut

has 'path'      => ( is       => 'rw',
                     isa      => 'Str',
                     required => 1,
                 );

has 'callback'  => ( is       => 'rw',
                     isa      => 'CodeRef',
                 );

has 'reset_callback' => ( is => 'rw',
                          isa => 'CodeRef',
                      );

has 'tail_fh'   => ( is      => 'rw',
                     lazy    => 1,
                     default => sub {
                         return $_[0]->get_fh();
                     },
                 );

has 'lastread'  => ( is      => 'rw',
                     isa     => 'Num',
                 );

has 'refresh'   => ( is      => 'rw',
                     isa     => 'Num',
                     default => sub {
                         # default behavior is to recheck if file was
                         # renamed or truncated every time we go to
                         # check and don't find any new lines.
                         return 1;
                     }
                 );

has 'count'     => ( is      => 'rw',
                     isa     => 'Num',
                     default => 0,
                 );

has 'leftover'  => ( is      => 'rw',
                     isa     => 'Str',
                     default => '',
                 );

has 'position'  => ( is      => 'rw',
                     default => undef,
                 );

has 'detect_rename' => ( is      => 'rw',
                         isa     => 'Bool',
                         default => 1,
                     );


=head1 SUBROUTINES/METHODS

=over 8

=item $obj->get_lines();

Look for new lines in the file, and run the callback on each.

If no new lines are found in the file, then the filehandle is checked
to see if the file was truncated or the filehandle was closed and then
a new one was re-opened.  In either case, the reset_callback is
executed and is passed the appropriate text:

  filehandle was truncated: {$path}

If the 'detect_rename' attribute is true (the default), then the
filehandle will also be checked to see if it was renamed.  This will
detect if the date on the file has increased even though the
filehandle has nothing available to read.  In the event of a rename,
the reset_callback will be executed.

  file was renamed: {$path}

=cut

sub get_lines {
    my ( $self ) = @_;

    $self->count( $self->count + 1 );

    my $path = $self->path;

    unless ( $path ) {
        $self->logger->logconfess( "FATAL: FileTail: no path set" );
    }

    unless ( -r $path ) {
        $self->reset_callback->( "path not readable: $path" );
        return;
    }

    my $fh = $self->tail_fh;

    my $mtime = ( stat $path )[9];

    if ( my $lines = $self->_get_lines_nonblock( $fh ) ) {
        return $lines;
    }

    return 0 unless $self->count % $self->refresh == 0;

    my $end_pos = sysseek( $fh, 0, SEEK_END);

    my $was_truncated = $end_pos < $self->position ? 1 : 0;
    my $was_renamed   = $self->lastread && $mtime > $self->lastread ? 1 : 0;

    if ( $was_truncated || ( $was_renamed && $self->detect_rename ) ) {

        if ( $was_truncated ) {
            $self->reset_callback->( "file was truncated: $path" );
        }
        else {
            $self->reset_callback->( "file was renamed: $path" );
        }

        $self->position( 0 );
        $self->tail_fh( $self->get_fh() );
        $fh = $self->tail_fh;

        return $self->_get_lines_nonblock( $fh );
    }

    # file was not truncated, seek back to same spot
    sysseek( $fh, 0, $self->position);

    return 0;
}

=item $obj->get_fh()

Use sysopen to open the filehandle in non-blocking read-only mode.  If
a position was defined on the object, seeks to that position.

=cut

sub get_fh {
    my ( $self ) = @_;

    my $path = $self->path;

    sysopen( my $fh, $path, O_NONBLOCK|O_RDONLY )
        or die "can't open $path: $!";

    my $position = $self->position;

    if ( defined $position ) {
        sysseek( $fh, $position, SEEK_SET );
    }
    else {
        sysseek( $fh, 0, SEEK_END );
    }

    return $fh;
}

=item $obj->_get_lines_nonblock( $fh )

Private method, code adapted from:

  http://www.perlmonks.org/?node_id=55241

=cut

sub _get_lines_nonblock {
  my ( $self, $fh ) = @_;

  my $timeout = 0;
  my $rfd = '';

  vec($rfd,fileno($fh),1) = 1;
  return unless select($rfd, undef, undef, $timeout)>=0;

  # I'm not sure the following is necessary?
  return unless vec($rfd,fileno($fh),1);

  my $buf = '';
  my $n = sysread($fh,$buf,1024*1024);

  # no lines read, check if file was truncated/renamed
  $self->position( sysseek( $fh, 0, SEEK_CUR) );

  # No new lines found
  return unless $n;

  $self->lastread( time );

  # Prepend the last unfinished line
  $buf = $self->leftover . $buf;

  # And save any newly unfinished lines
  $self->leftover( (substr($buf,-1) !~ /[\r\n]/ && $buf =~ s/([^\r\n]*)$//) ? $1 : '' );

  return unless $buf;

  my $count = 0;

  for my $line ( split( /\n/, $buf ) ) {
      chomp $line;
      next unless $line;

      $self->callback->( $line );
      $count++;
  }

  return $count;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=back

=head1 SIMILAR MODULES

I looked at a lot of other similar modules, but ended up having to
roll my own due some some specific requirements of wubot.

L<File::Tail> - I was unable to tweak the frequency at which this
module checks for updates or filehandle resets to work the way I
wanted.  I wanted to do this reliably every time the check() method
was executed.

L<POE::Wheel::FollowTail> - I have used this module in the past and
love it.  While old versions of wubot were based on POE, the current
version of wubot uses AnyEvent.

L<File::Tail> - this module has great mechanisms for detecting if the
file was replaced or the file was truncated, but unfortunately it does
pass that information on to programs that use the module.

=begin Pod::Coverage

  SEEK_END
  SEEK_CUR
  SEEK_SET
  O_NONBLOCK
  O_RDONLY

=end Pod::Coverage

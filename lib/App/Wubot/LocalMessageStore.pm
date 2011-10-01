package App::Wubot::LocalMessageStore;
use Moose;

# VERSION

use Digest::MD5 qw( md5_hex );
use File::Path;
use POSIX qw(strftime);
use Sys::Hostname qw();
use YAML::XS;

use App::Wubot::Logger;
use App::Wubot::Reactor;
use App::Wubot::SQLite;

=head1 NAME

App::Wubot::LocalMessageStore - add or remove messages from a local wubot SQLite message queue

=head1 SYNOPSIS

    use App::Wubot::LocalMessageStore;

    my $messenger = App::Wubot::LocalMessageStore->new();
    my $directory = "/path/to/queue/directory";

    $messenger->store( { %{ $message } }, $directory );

    # scalar context, get the message, immediately deleting it from
    # the queue
    my $got_message = $messenger->get( $directory );

    # array context, get the message and return a callback that can be
    # called to delete the message after it has been successfully
    # processed.
    my ( $got_message, $callback ) = $messenger->get( $directory );
    # do something here to process the message
    # delete the message after processing
    $callback->();


=head1 DESCRIPTION

Wubot uses LocalMessageStore to add messages to a FIFO queue
implemented in SQLite for asynchronous processing.

Common uses of LocalMessageStore include the queue where wubot-monitor
stores messages for reactions by wubot-reactor.

When a message in the queue has been processed, it will not be
immediately removed from the queue.  Instead, the 'seen' flag will be
set to the timestamp when the message was marked as processed.

=head1 GUARANTEED MESSAGE PROCESSING

The callback mechanism (see the example above) is used to ensure that
the message has been successfully processed before it is deleted.  If
the wubot process gets shut down in the middle of processing a
message, the message will not be removed from the queue.  This could
sometimes lead to reacting to a message more than once, but ensures
that the reaction will always occur.


=cut

has 'logger'  => ( is => 'ro',
                   isa => 'Log::Log4perl::Logger',
                   lazy => 1,
                   default => sub {
                       return Log::Log4perl::get_logger( __PACKAGE__ );
                   },
               );

has 'hostname' => ( is => 'ro',
                    isa => 'Str',
                    lazy => 1,
                    default => sub {
                        my $hostname = Sys::Hostname::hostname();
                        $hostname =~ s|\..*$||;
                        return $hostname;
                    },
                );

has 'sqlite'  => ( is => 'ro',
                   isa => 'HashRef',
                   default => sub { {} },
               );

has 'reactor' => ( is => 'ro',
                   default => undef,
               );

has 'novacuum' => ( is => 'ro',
                    default => undef,
                );


=head1 SUBROUTINES/METHODS

=over 8

=item initialize_db( $directory )

This will get called the first time a queue is accessed in a running
process.  A App::Wubot::SQLite object will be created for the queue.

When initializing the database connection, all items that were marked
'seen' more than 24 hours ago will be deleted from the queue, and the
current number of messages remaining in the queue in the 'seen' and
'unseen' state will be logged.  Since the wubot processes are
automatically restarted every night just after midnight, this ensures
that the queue will not get too long, since long queues can
significantly degrade performance.

=cut

sub initialize_db {
    my ( $self, $directory ) = @_;

    unless ( $directory ) {
        $self->logger->logconfess( "ERROR: initialize_directory called without directory" );
    }

    unless ( -d $directory ) {
        mkpath( $directory );
    }

    my $dbfile = "$directory/queue.sqlite";

    $self->sqlite->{ $dbfile } = App::Wubot::SQLite->new( { file => $dbfile } );

    $self->delete_seen( $directory, 24*60*60 );

    my ( $seen, $unseen, $total ) = $self->get_counts( $directory );

    if ( $total ) {

        if ( $total > 100000 ) {
            $self->logger->error( "queue length: $total ($seen/$unseen): $dbfile" );
        }
        elsif ( $total > 30000 ) {
            $self->logger->warn( "queue length: $total ($seen/$unseen): $dbfile" );
        }
        else {
            $self->logger->info( "queue length: $total ($seen/$unseen): $dbfile" );
        }

        # if ( $self->reactor ) {
        #     $self->reactor->react( { subject => "seen queue length: $length",
        #                              file    => $dbfile,
        #                              length  => $length,
        #                          } );
        # }
    }

}

=item store( $message, $directory )

Given a message (a simple or multi-level hash), store it in the queue
in the specified directory.

If the message does not already have a checksum, lastupdate, or
hostname, then those fields will be determined.

The message will be serialized using YAML::XS, and the result will be
stored in the 'data' column.

=cut

sub store {
    my ( $self, $message, $directory ) = @_;

    unless ( -d $directory ) {
        mkpath( $directory );
    }

    my $dbfile = "$directory/queue.sqlite";

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $dbfile } ) {
        $self->initialize_db( $directory );
    }

    unless ( $message->{checksum} ) {
        $message->{checksum}   = $self->checksum( $message );
    }

    unless ( $message->{lastupdate} ) {
        $message->{lastupdate} = time;
    }

    unless ( $message->{hostname} ) {
        $message->{hostname}  = $self->hostname;
    }

    my $message_text = Dump $message;

    my $time = $message->{lastupdate};
    my $date = strftime( "%a, %d %b %Y %H:%M:%S %z", localtime( $time ) );

    my $subject;
    if ( $message->{key} ) {
        $subject = join( ": ", $message->{key}, $message->{subject} || $date );
    }
    else {
        $subject = $message->{subject} || $date;
    }

    $self->sqlite->{ $dbfile }->insert( 'message_queue',
                                        { date       => $date,
                                          subject    => $subject,
                                          data       => $message_text,
                                          hostname   => $message->{hostname},
                                          seen       => undef,
                                          lastupdate => $time,
                                          key        => $message->{key} || "",
                                      },
                                    );

    return 1;
}

=item delete_seen( $directory, $age )

Delete all queue items where the 'seen' time is older than the
specified 'age' in seconds.

Also calls the 'vacuum' command on the database to reclaim any unused
space and improve performance.

=cut

sub delete_seen {
   my ( $self, $directory, $age ) = @_;

   my $dbfile = "$directory/queue.sqlite";

   unless ( -r $dbfile ) {
       $self->logger->debug( "ERROR: dbfile not found: $dbfile" );
       return;
   }

   unless ( $self->sqlite->{ $dbfile } ) {
       $self->initialize_db( $directory );
   }

   my $time = time;
   if ( $age ) { $time -= $age }
   $self->logger->info( "Deleting items from message queue that are older than: ", scalar localtime $time );

   my $conditions = { seen => { '<' => $time } };
   $self->sqlite->{ $dbfile }->delete( 'message_queue', $conditions );

   unless ( $self->novacuum ) {
       $self->sqlite->{ $dbfile }->vacuum();
   }

   return 1;
}

=item get( $directory )

Get the oldest unseen item in the queue, deserialize the message, and
return the message data structure.

If called in array context, will also return a callback which can be
used to delete the message (i.e. mark it 'seen') after it has been
processed.

=cut

sub get {
    my ( $self, $directory ) = @_;

    my $dbfile = "$directory/queue.sqlite";

    unless ( -r $dbfile ) {
        $self->logger->debug( "ERROR: dbfile not found: $dbfile" );
        return;
    }

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $dbfile } ) {
        $self->initialize_db( $directory );
    }

    my ( $entry ) = $self->sqlite->{ $dbfile }->query( "SELECT * FROM message_queue WHERE seen IS NULL ORDER BY id LIMIT 1" );

    return unless $entry;

    my $message;
    eval {                          # try
        $message = Load $entry->{data};
        1;
    } or do {                       # catch
        # error
        my $error = $@;
        $self->logger->error( "ERROR LOADING MESSAGE: $entry->{id} => $entry->{subject}: $error" );

        $self->sqlite->{ $dbfile }->insert( 'message_queue_rejected',
                                            $entry,
                                        );

        $self->sqlite->{ $dbfile }->delete( 'message_queue', { id => $entry->{id} } );

        $message = { subject => "LocalMessageStore: rejected $entry->{id}: $entry->{subject}",
                     errmsg  => $error,
                 };

    };


    # if called in array context, return the message and a callback
    # method to delete the item from the queue AFTER it has been
    # processed.
    if ( wantarray ) {
        my $callback = sub { $self->sqlite->{ $dbfile }->update( 'message_queue', { seen => time }, { id => $entry->{id} } ) };
        $self->logger->trace( "Marking message_queue id seen: $entry->{id}: ", time );
        return ( $message, $callback );
    }

    $self->sqlite->{ $dbfile }->delete( 'message_queue', { id => $entry->{id} } );
    return $message;
}

=item get_counts( $directory )

Given the directory of a queue, return three statistics:

  - number of messages in the queue marked 'seen'
  - number of messsages in the queue left to be processed
  - total number of messages in the queue

=cut

sub get_counts {
    my ( $self, $directory ) = @_;

    my $dbfile = "$directory/queue.sqlite";

    unless ( -r $dbfile ) {
        $self->logger->debug( "ERROR: dbfile not found: $dbfile" );
        return;
    }

    # if we don't have a sqlite object for this file, create one now
    unless ( $self->sqlite->{ $dbfile } ) {
        $self->initialize_db( $directory );
    }

    my ( $seen   ) = $self->sqlite->{ $dbfile }->query( "SELECT count(*) FROM message_queue WHERE seen IS NOT NULL" );
    my ( $unseen ) = $self->sqlite->{ $dbfile }->query( "SELECT count(*) FROM message_queue WHERE seen IS NULL" );

    my $seen_count   = $seen->{'count(*)'}   || 0;
    my $unseen_count = $unseen->{'count(*)'} || 0;

    return ( $seen_count, $unseen_count, $seen_count + $unseen_count );
}

=item checksum( $message )

Given a message, calculate the md5sum of the message.  This involves
serializing the message with YAML::XS and then calculating the md5_hex
of the serialized message.  The generated 'checksum' field can be
useful to detect duplicate messages.

=cut


sub checksum {
    my ( $self, $message ) = @_;

    return unless $message;

    my $text = YAML::XS::Dump $message;

    utf8::encode( $text );

    return md5_hex( $text );
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=back

=head1 YAML::XS

This library requires YAML::XS, as I have experienced issues
serializing and/or deserializing messages with every other perl YAML
library I have tried.  YAML::XS has been extremely reliable; I have
yet to encounter a message that it can not handle.

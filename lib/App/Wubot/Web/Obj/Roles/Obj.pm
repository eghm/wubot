package App::Wubot::Web::Obj::Roles::Obj;
use Moose::Role;

# VERSION

use Date::Manip;
use HTML::Strip;
use POSIX qw(strftime);
use Text::Wrap;
use URI::Find;

use App::Wubot::Logger;
use App::Wubot::SQLite;
use App::Wubot::Util::Colors;
use App::Wubot::Util::TimeLength;

has 'id'               => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return $self->db_hash->{id};
                            }
                        );

has 'checksum'         => ( is => 'ro',
                            isa => 'Maybe[Str]',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return $self->db_hash->{checksum};
                            }
                        );

has 'sql'              => ( is      => 'ro',
                            isa     => 'App::Wubot::SQLite',
                            required => 1,
                        );

has 'logger'           => ( is => 'ro',
                            isa => 'Log::Log4perl::Logger',
                            lazy => 1,
                            default => sub {
                                return Log::Log4perl::get_logger( __PACKAGE__ );
                            },
                        );

has 'timelength'       => ( is => 'ro',
                            isa => 'App::Wubot::Util::TimeLength',
                            lazy => 1,
                            default => sub {
                                return App::Wubot::Util::TimeLength->new( { space => 1 } );
                            },
                        );

has 'colors'           => ( is => 'ro',
                            isa => 'App::Wubot::Util::Colors',
                            lazy => 1,
                            default => sub {
                                return App::Wubot::Util::Colors->new();
                            },
                        );

has 'color'            => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;

                                if ( $self->db_hash->{color} ) {
                                    return $self->db_hash->{color};
                                }

                                return 'black';
                            }
                        );

has 'display_color'    => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return $self->colors->get_color( $self->color );
                            }
                        );

has 'link'             => ( is => 'ro',
                            isa => 'Maybe[Str]',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return $self->db_hash->{link};
                            }
                        );

has 'lastupdate'       => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return $self->db_hash->{lastupdate};
                            }
                        );

has 'body'             => ( is => 'ro',
                            isa => 'Maybe[Str]',
                            lazy => 1,
                            default => sub {
                                my $self = shift;

                                my $body = $self->db_hash->{body};
                                utf8::decode( $body );

                                $body =~ s|\<br\>|\n\n|g;
                                $Text::Wrap::columns = 80;
                                my $hs = HTML::Strip->new();
                                $body = $hs->parse( $body );
                                $body =~ s|\xA0| |g;
                                $body = fill( "", "", $body);
                            }
                        );

has 'has_body'         => ( is => 'ro',
                            isa => 'Bool',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return $self->db_hash->{body} ? 1 : 0;
                            },
                        );

has 'lastupdate_color' => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return $self->color unless $self->age;
                                return $self->timelength->get_age_color( abs( $self->lastupdate - time ) );
                            }
                        );

has 'age'              => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return unless $self->lastupdate;
                                return $self->timelength->get_human_readable( time - $self->lastupdate );
                            }
                        );

has 'username'         => ( is => 'ro',
                            isa => 'Maybe[Str]',
                            lazy => 1,
                            default => sub {
                                my $self = shift;

                                my $username = $self->db_hash->{username};
                                utf8::decode( $username );
                                return $username;
                            }
                        );

has 'seen'             => ( is => 'ro',
                            isa => 'Maybe[Num]',
                            lazy => 1,
                            default => sub {
                                my $self = shift;
                                return $self->db_hash->{seen};
                            }
                        );

has 'text'             => ( is => 'ro',
                            isa => 'Str',
                            lazy => 1,
                            default => sub {
                                my $self = shift;

                                my @return;

                                for my $field ( qw( subject subject_text ) ) {
                                    next unless $self->db_hash->{ $field };
                                    push @return, $self->db_hash->{ $field };
                                }

                                my $body = $self->body;
                                if ( $body ) {
                                    push @return, $body;
                                }

                                return join( "\n", @return );
                            },
                        );

has 'urls'             => ( is => 'ro',
                            isa => 'ArrayRef[Str]',
                            lazy => 1,
                            default => sub {
                                my $self = shift;

                                my %urls;

                                URI::Find->new( sub {
                                                    my ( $url ) = @_;
                                                    $url =~ s|\]\[.*$||;
                                                    $urls{$url}++;
                                                }
                                            )->find(\$self->text);

                                for my $url ( keys %urls ) {
                                    if ( $url =~ m|doubleclick| ) {
                                        delete $urls{$url};
                                    }
                                }

                                if ( $self->link ) {
                                    delete $urls{ $self->link };
                                }

                                return [ sort keys %urls ];
                            }
                        );

has 'image'            => ( is => 'rw',
                            isa => 'Maybe[Str]',
                            lazy => 1,
                            default => sub {
                                my $self = shift;

                                my $image;

                                URI::Find->new( sub {
                                                    my ( $url ) = @_;
                                                    return if $image;
                                                    return unless $url =~ m/\.(?:png|gif|jpg)$/i;
                                                    $image = "$url";
                                                    print "IMAGE: $image\n";
                                                }
                                            )->find(\$self->text);

                                return $image;
                            }
                        );

1;

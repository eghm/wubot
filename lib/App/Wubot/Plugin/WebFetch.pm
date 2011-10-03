package App::Wubot::Plugin::WebFetch;
use Moose;

# VERSION

# todo: select with xpath in addition to regexp

use App::Wubot::Logger;
use App::Wubot::Util::WebFetcher;

with 'App::Wubot::Plugin::Roles::Cache';
with 'App::Wubot::Plugin::Roles::Plugin';

has 'fetcher' => ( is  => 'ro',
                   isa => 'App::Wubot::Util::WebFetcher',
                   lazy => 1,
                   default => sub {
                       return App::Wubot::Util::WebFetcher->new();
                   },
               );

sub check {
    my ( $self, $inputs ) = @_;

    my $config = $inputs->{config};
    my $cache  = $inputs->{cache};

    $self->logger->debug( "Fetching content from: $config->{url}" );

    my $content = $self->fetcher->fetch( $config->{url}, $config );

    my $field = $config->{field} || 'content';

    return { react => { $field => $content }, cache => $cache };
}

__PACKAGE__->meta->make_immutable;

1;

__END__


=head1 NAME

App::Wubot::Plugin::WebFetch - fetch content from a URL


=head1 SYNOPSIS

  ~/wubot/config/plugins/WebFetch/mypage.yaml

  ---
  delay: 24h
  url: http://myweb.com/somepage.html
  field: content

=head1 DESCRIPTION

Fetch content from a web page at regular intervals.

The retrieved content will be stored in the 'field' specified in the
config.  If no field is specified, the default target field will be
'content'.

=head1 GITHUB TRAFFIC

I like to keep track of how many hits some of my projects have
received on github.  I haven't found any sort of a feed that will
provide that data.  The only place I have seen that is on the
'traffic' graph page.  So I use the following config to pull that page
once per day, grab the number of hits and send me a notification.

  ---
  delay: 24h
  url: https://github.com/wu/wubot/graphs/traffic

  react:

    - name: content
      condition: contains content
      rules:

        - name: get page views
          plugin: CaptureData
          config:
            source_field: content
            regexp: '^.*?Page Views \((\d+) over last 90 days\)'
            target_field: hits

        - name: build subject
          plugin: Template
          config:
            template: wubot: hits last 90 days: {$hits}
            target_field: subject

        - name: color
          plugin: SetField
          config:
            set:
              color: purple
              sticky: 1

=head1 GRAPHING ROUTER TRAFFIC

My DSL router does not provide any mechanism to graph the traffic sent
or received.  However it does provide a web page where it lists the
the total number of packets sent and received.  So I use the following
config which captures the sent and received packets every 5 minutes.


  ---
  delay: 5m
  url: http://192.168.1.98/cgi-bin/webcm?getpage=../html/lan_status.html

  react:

    - name: content
      condition: contains content
      rules:

        - name: get packets sent
          plugin: CaptureData
          config:
            source_field: content
            regexp: '^.*?Packets Sent:</td>.*?<td\>(\d+)'
            target_field: sent

        - name: get packets received
          plugin: CaptureData
          config:
            source_field: content
            regexp: '^.*?Packets Received:</td>.*?<td>(\d+)'
            target_field: recv


Then I use the following rule in the reactor to graph the data using
RRD:

  - name: WebFetch RRD
    condition: key matches ^WebFetch-router
    plugin: RRD
    config:
      base_dir: /usr/home/wu/wubot/rrd
      fields:
        sent: COUNTER
        recv: COUNTER
      period:
        - day
        - week
        - month
      graph_options:
        lower_limit: 0
        right-axis: 1:0
        width: 375

=head1 SEE ALSO

This plugin uses L<App::Wubot::Util::WebFetcher>.


=head1 SUBROUTINES/METHODS

=over 8

=item check( $inputs )

The standard monitor check() method.

=back

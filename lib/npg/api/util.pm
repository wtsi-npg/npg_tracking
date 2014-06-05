#########
# Author:        rmp
# Created:       2007-03-28
#
#
# This module is now DEPRACATED. Do not use. Use npg::api::request directly instead.
# js10 5th June 2014
#
package npg::api::util;

use strict;
use warnings;
use base qw(Class::Accessor);
use Carp;
use XML::LibXML;
use Readonly;

use npg::api::request;

our $VERSION = '0';

Readonly::Scalar our $LIVE_BASE_URI => 'http://sfweb.internal.sanger.ac.uk:9000/perl/npg';
Readonly::Scalar our $DEV_BASE_URI  => 'http://npg.dev.sanger.ac.uk/perl/npg';

Readonly::Scalar our $MAX_RETRIES      => 3;
Readonly::Scalar our $RETRY_DELAY      => 5;

sub new {
  my ($class, $ref) = @_;
  $ref ||= {};
  bless $ref, $class;
  return $ref;
}

sub parser {
  my $self = shift;
  $self->{'parser'} ||= XML::LibXML->new();
  return $self->{'parser'};
}

sub max_retries {
  my ($self, $v) = @_;
  if(defined $v) {
    $self->{max_retries} = $v;
  }
  return $self->{max_retries} || $MAX_RETRIES;
}

sub retry_delay {
  my ($self, $v) = @_;
  if(defined $v) {
    $self->{retry_delay} = $v;
  }
  return $self->{retry_delay} || $RETRY_DELAY;
}

sub useragent {
  my $self = shift;

  if(!$self->{'useragent'}) {
    my $ua = LWP::UserAgent->new();
    $ua->agent("npg::api::util/$VERSION ");
    $ua->env_proxy();
    $self->{'useragent'} = $ua;
  }
  return $self->{'useragent'};
}

sub request {
  my ($self, $content_type) = @_;
  my $h = {};
  $h->{max_retries} = $self->max_retries;
  $h->{retry_delay} = $self->retry_delay;
  if ($content_type) {
    $h->{content_type} = $content_type;
  }
  if ($self->{useragent}) {
    $h->{useragent} = $self->{useragent};
  }
  return  npg::api::request->new($h);
}

sub base_uri {
  my $self = shift;
  if ($self->{base_uri}) {
    return $self->{base_uri};
  }
  my $dev = $ENV{dev} || q{live};

  $self->{base_uri} = $dev eq q{dev} ? $DEV_BASE_URI : $LIVE_BASE_URI;
  return $self->{base_uri};
}

sub get {
  my ($self, $uri, $args) = @_;
  return  $self->request('text/xml')->make($uri, q[GET], $args);
}

sub post {
  my ($self, $uri, $args) = @_;
  return  $self->request('text/xml')->make($uri, q[POST], $args);
}

sub post_non_xml {
  my ($self, $uri, $args) = @_;
  return  $self->request()->make($uri, q[POST], $args);
}

1;
__END__

=head1 NAME

npg::api::util

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - Constructor

May take optional base_uri, useragent and parser attributes, see respective methods below.

  my $oUtil = npg::api::util->new();
  my $oUtil = npg::api::util->new({
    'base_uri'  => 'http://npg.sanger.ac.uk/perl/npg',
    'useragent' => LWP::UserAgent->new(),
    'parser'    => XML::LibXML->new();
  });

=head2 parser - an instance of XML parser

=head2 useragent

=head2 max_retries

=head2 retry_delay

=head2 request - an instance of npg::api::request object

=head2 base_uri - base URI for this resource set

  my $sURI = $oDerivedObject->base_uri();

=head2 get - HTTP GET with additional Accept: text/XML header

=head2 post - HTTP POST with additional Accept: text/XML header

=head2 post_non_xml - HTTP POST without Accept:text/XML header

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item strict

=item warnings

=item Readonly

=item Class::Accessor

=item Carp

=item XML::LibXML

=item npg::api::request

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Roger Pettett

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

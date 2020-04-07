package npg_tracking::heron::upload::metadata_client;

use strict;
use warnings;

use Data::Dump qw(pp);
use JSON;
use LWP::UserAgent;
use Moose;
use MooseX::StrictConstructor;
use URI;

with qw[
    WTSI::DNAP::Utilities::Loggable
    WTSI::DNAP::Utilities::JSONCodec
];

our $VERSION = '0';

our $JSON_CONTENT_TYPE = 'application/json';

has 'username' =>
    (isa           => 'Str',
     is            => 'ro',
     required      => 1,
     documentation => 'The registered user name for the COG-Uk API account',);

has 'token' =>
    (isa           => 'Str',
     is            => 'ro',
     required      => 1,
     documentation => 'The registered access token for the COG-UK API account',);

has 'api_uri' =>
  (isa           => 'URI',
   is            => 'ro',
   required      => 1,
   default       => sub { return URI->new('https://localhost') },
   documentation => 'COG-UK API endpoint URI to receive sequencing metadata',);

=head2 send_metadata

  Arg[1]     : Library name, Str.
  Arg[n]     : Runs, npg_tracking::heron::upload::run.

  Example    : my $response_content = $client->send_metadata($library_name, @runs)
  Description: Return the (decoded) response data on successful upload of metadata
               to the COG-UK API endpoint, or raise an error if some or all of the
               metadata were rejected.
  Returntype : HashRef.

=cut

sub send_metadata {
  my ($self, $library_name, @runs) = @_;

  my $document = $self->_make_library_metadata($library_name);
  foreach my $run (@runs) {
    push @{$document->{runs}}, $self->_make_run_metadata($run);
  }

  # Add credentials
  $document->{username} = $self->username;
  $document->{token}    = $self->token;

  my $req_content = $self->encode($document);

  my $ua = LWP::UserAgent->new;
  $ua->default_header('Content-Type' => $JSON_CONTENT_TYPE);

  my $uri = $self->_seq_add_uri;
  $self->debug(sprintf q(POST to '%s', content %s ),
                       $uri, $req_content);

  my $response = $ua->post($uri, Content => $req_content);
  $self->debug(sprintf q(POST returned code %d, %s),
                       $response->code, $response->message);

  my $res_content;
  if ($response->is_success) {
    my $res_json = $response->content;
    $self->debug('Response JSON ', $res_json);
    $res_content = $self->decode($res_json);
  }
  else {
    $self->logcroak(sprintf q(Failed to get results from URI '%s': %s),
                            $uri, $response->message);
  }

  foreach my $add (@{$res_content->{new}}) {
    $self->info('Added ', pp($add));
  }
  foreach my $update (@{$res_content->{updated}}) {
    $self->info('Updated ', pp($update));
  }
  foreach my $ignore (@{$res_content->{ignored}}) {
    $self->info('Ignored ', $ignore);
  }

  my $summary = sprintf q(POST to %s failed; %d errors, %d warnings, ) .
                        q(%d updated, %d ignored),
                        $uri, $res_content->{errors}, $res_content->{warnings},
                        scalar @{$res_content->{updated}},
                        scalar @{$res_content->{ignored}};

  if ($res_content->{success}) {
    foreach my $message (@{$res_content->{messages}}) {
      $self->info('Endpoint message: ', pp($message));
    }
    $self->info($summary);
  }
  else {
    foreach my $message (@{$res_content->{messages}}) {
      $self->error('Endpoint message: ', pp($message));
    }
    $self->logcroak($summary);
  }

  return $res_content;
}

sub _seq_add_uri {
  my ($self) = @_;

  my $uri = $self->api_uri->clone;
  $uri->path('api/v2/process/sequencing/add/');

  return $uri;
}

sub _make_library_metadata {
  my ($self, $library_name) = @_;

  $library_name or $self->logconfess('An empty library_name was supplied');

  return {library_name => $library_name,
          runs         => []};
}

sub _make_run_metadata {
  my ($self, $run) = @_;

  return {run_name         => $run->name,
          instrument_make  => $run->instrument_make,
          instrument_model => $run->instrument_model};
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;

__END__

=head1 NAME

npg_tracking::heron::upload::metadata_client

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Client capable of uploading sequencing run metadata to the COG-UK API
endpoint described at https://docs.covid19.climb.ac.uk/metadata.

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Keith James <kdj@sanger.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020, Genome Research Limited. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the Perl Artistic License or the GNU General
Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut

#############
# $Id: sensors.pm 15402 2012-03-29 16:11:11Z mg8 $
# Created By: Jennifer Liddle (js10@sanger.ac.uk)
# Last Maintained By: $Author: mg8 $
# Created On: 2012-03-13
# Last Changed On: $Date: 2012-03-29 17:11:11 +0100 (Thu, 29 Mar 2012) $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/sensors.pm $

package npg::sensors;
use strict;
use warnings;
use Moose;
use Carp;
use English qw{-no_match_vars};
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 15402 $ =~ /(\d+)/mxs; $r; };

use npg_tracking::Schema;
use npg::util::mailer;
use XML::Simple;
use Data::Dumper;
use LWP::UserAgent;

with 'MooseX::Getopt';

Readonly::Scalar our $DEFAULT_URL => 'http://netbotz-h237.internal.sanger.ac.uk/xmlQuery/sensors/';
Readonly::Scalar our $DEFAULT_USERNAME => 'lims';
Readonly::Scalar our $DEFAULT_PASSWORD => 'lims';
Readonly::Scalar our $MAX_TEMPERATURE => 29;
Readonly::Scalar our $MIN_TEMPERATURE => 15;

my $data;

has url => (
  is         => 'ro',
  isa        => 'Str',
  default    => $DEFAULT_URL,
);

has username => (
  is         => 'ro',
  isa        => 'Str',
  default    => $DEFAULT_USERNAME,
);

has password => (
  is         => 'ro',
  isa        => 'Str',
  default    => $DEFAULT_PASSWORD,
);

has schema => (
  is         => 'ro',
  isa        => 'npg_tracking::Schema',
  lazy_build => 1,
);

sub _build_schema {
  return npg_tracking::Schema->connect();
}

=head1 NAME

npg::sensors

=head1 VERSION

$LastChangedRevision: 15402 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 main

=cut

sub main {
  my $self = shift;
  $self->load_data();
  $self->post_data();
  return 0;
}

=head2 load_data

=cut
sub load_data {
  my ($self, $arg_refs) = @_;

  # create a user agent object
  my $ua = LWP::UserAgent->new();

  # Create a request
  my $req = HTTP::Request->new(POST => $self->url);
  $req->authorization_basic($self->username, $self->password);

  # Pass request to the user agent and get a response back
  my $res = $ua->request($req);

  # Check the outcome of the response
  if (!$res->is_success) {
    die $res->status_line, "\n";
  }

  $data = $res->content;
  return $data;
}

=head2 post_data

=cut
sub post_data {
  my $self = shift;
  my $xml = XML::Simple->new();
  my $schema = $self->schema;

  my $ref = XMLin($data);
  my $sensors = $ref->{variable};
  foreach my $s (@{$sensors}) {
    if (exists $s->{guid} && exists $s->{'double-val'}) {
      my $guid = $s->{guid};
      my $temperature = $s->{'double-val'};
      my $dbic_sensor = $schema->resultset('Sensor')->find({guid => $guid});
                        if (!$dbic_sensor) {
                            carp "Sensor with guid $guid not found in the sensor table";
          next;
      }
      $schema->resultset('SensorData')->create({
        id_sensor => $dbic_sensor->id_sensor,
        date => $ref->{time},
        value => $temperature});
      if (($temperature > $MAX_TEMPERATURE) || ($temperature < $MIN_TEMPERATURE)) {
        npg::util::mailer->new({
          to => 'js10@sanger.ac.uk',
          from => 'npg@sanger.ac.uk',
          subject => 'Temperature warning',
          body => "The temperature of sensor $guid is now $temperature.",
        })->mail();
      }
    }
  }
  return 0;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English -no_match_vars

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: mg8 $

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012 GRL, by Jennifer Liddle (js10@sanger.ac.uk)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

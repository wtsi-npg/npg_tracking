#############
# Created By: ajb
# Created On: 2010-02-10

package npg::email::run;
use strict;
use warnings;
use Moose;
use Carp;
use English qw{-no_match_vars};
use Readonly;

our $VERSION = '0';

use st::api::lims;
extends qw{npg::email};

=head1 NAME

npg::email::run

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 get_run

Returns a run resultset object based on the id_run provided

=cut

sub get_run {
  my ($self, $id_run) = @_;
  return $self->schema_connection()->resultset(q{Run})->find($id_run);
}

=head2 get_lims

Returns a run-level st::api::lims object

=cut

sub get_lims {
  my ($self, $id_run) = @_;
  my $batch_id = $self->get_run($id_run)->batch_id();
  return st::api::lims->new(batch_id => $batch_id, id_run => $id_run);
}

=head2 study_lane_followers

Provides a hashref of studys from given batch, with lanes that are in the study, and the followers who would be emailed

  my $hProjectLaneFollowers = $oClass->study_lane_followers();
  
  {
    <study_name> => {
      followers => [],
      lanes => [{
        position => x,
        library => y,
      },],
    },
  }

=cut

sub study_lane_followers {
  my ($self, $id_run) = @_;

  my $return_hash = {};
  eval {
    my $lims = $self->get_lims($id_run);
    my $with_spiked_control = 0;
    foreach my $child_lims ($lims->associated_child_lims) {
      my $position = $child_lims->position;
      foreach my $study_name ($child_lims->study_names($with_spiked_control)) {
        if ( !exists $return_hash->{ $study_name } ) {
          $return_hash->{$study_name}->{followers} = undef;
          $return_hash->{$study_name}->{lanes} = [];
        }
        push @{ $return_hash->{$study_name}->{lanes} }, {position => $position,library => $child_lims->library_name,};
      }
    }

    foreach my $dlims ($lims->associated_lims) {
      my $study_name = $dlims->study_name;
      if ( $study_name && exists $return_hash->{$study_name} && !$return_hash->{$study_name}->{followers} ) {
        my @addresses = $dlims->email_addresses;
        $return_hash->{$study_name}->{followers} = $dlims->email_addresses;
      }
    }
    1;
  } or do {
    carp qq{Unable to obtain lims data for run $id_run: } . $EVAL_ERROR;
  };

  return $return_hash;
}


=head2 id_run

returns the run id from the entity, or stores it on construction

=cut

has id_run => (
  is         => 'ro',
  isa        => 'Int',
  lazy_build => 1,
);

sub _build_id_run {
  my ($self) = @_;

  my $id_run;
  eval {
    $id_run = $self->entity->id_run();
  } or do {
    $id_run = $self->entity->run_lane->id_run();
  };

  return $id_run;
}


=head2 batch details

returns a hashref of details about the batch this run was performed on

=cut

has batch_details => (
  is         => 'ro',
  isa        => 'HashRef',
  lazy_build => 1,
);

sub _build_batch_details {
  my ($self) = @_;

  my $details = {error => q{}, lanes => [], batch_id => undef,};
  eval {
    my $lims = $self->get_lims($self->id_run);
    $details->{batch_id} = $lims->batch_id;

    foreach my $child_lims ($lims->associated_child_lims) {
      push @{ $details->{lanes} }, {
        position     => $child_lims->position,
        library      => $child_lims->library_name,
        control      => $child_lims->is_control,
        request_id   => $child_lims->request_id,
        req_ent_name => 'request',
      };
    }
    1;
  } or do {
     $details->{error} = $EVAL_ERROR;
  };

  return $details;
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

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Andy Brown (ajb@sanger.ac.uk)

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

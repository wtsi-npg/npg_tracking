package npg::email::run;

use Moose;
use Carp;
use Try::Tiny;
use st::api::lims;

extends qw{npg::email};

our $VERSION = '0';

=head1 NAME

npg::email::run

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
  try {
    my $lims = $self->get_lims($id_run);
    my $with_spiked_control = 0;
    foreach my $child_lims ($lims->associated_child_lims) {
      my $position = $child_lims->position;
      foreach my $study_name ($child_lims->study_names($with_spiked_control)) {
        if ( !exists $return_hash->{ $study_name } ) {
          $return_hash->{$study_name}->{'followers'} = undef;
          $return_hash->{$study_name}->{'lanes'} = [];
        }
        push @{ $return_hash->{$study_name}->{'lanes'} },
          {'position' => $position,'library' => $child_lims->library_name || q[],};
      }
    }

    foreach my $dlims ($lims->associated_lims) {
      my $study_name = $dlims->study_name;
      if ( $study_name && exists $return_hash->{$study_name} && !$return_hash->{$study_name}->{'followers'} ) {
        $return_hash->{$study_name}->{'followers'} = $dlims->email_addresses;
      }
    }
  } catch {
    carp qq{Unable to obtain lims data for run $id_run: $_};
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
  try {
    $id_run = $self->entity->id_run();
  } catch {
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

  my $details = {'error' => q{}, 'lanes' => [], 'batch_id' => 0,};
  try {
    my $lims = $self->get_lims($self->id_run);
    $details->{'batch_id'} = $lims->batch_id;

    foreach my $child_lims ($lims->associated_child_lims) {
      push @{ $details->{'lanes'} }, {
        position     => $child_lims->position,
        library      => $child_lims->library_name || q[],
        control      => $child_lims->is_control   ?  1 : 0,
        request_id   => $child_lims->request_id   || q[],
        req_ent_name => 'request',
      };
    }
  } catch {
     $details->{'error'} = $_;
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

=item Try::Tiny

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown ajb@sanger.ac.uk

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 GRL

This program is part of NPG software suit.

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

=cut

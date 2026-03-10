package npg_tracking::report::event2followers;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use List::MoreUtils qw/uniq/;
use Readonly;
use Try::Tiny;

use st::api::lims;
use npg::util::mailer;

extends 'npg_tracking::report::event2subscribers';

Readonly::Scalar my $MLWH_DRIVER_TYPE => q[ml_warehouse_fc_cache];

our $VERSION = '0';

has 'schema_mlwh' => (
  isa        => 'WTSI::DNAP::Warehouse::Schema',
  is         => 'ro',
  required   => 0,
  predicate  => '_has_schema_mlwh',
);

has 'lims' => (
  is         => 'ro',
  required   => 0,
  isa        => 'ArrayRef[st::api::lims]',
  lazy_build => 1,
);
sub _build_lims {
  my $self = shift;

  my @lims_list = ();
    my $id_run = $self->event_entity->id_run();
    try {
      my $schema = $self->event_entity->result_source()->schema();
      my $run_row = $schema->resultset('Run')->find($id_run);
      my $ref = { id_run => $id_run };
      if ($self->event_entity->can('position')) {
        $ref->{'position'} = $self->event_entity->position();
      }
      if ($self->_has_schema_mlwh()) {
        $ref->{'id_flowcell_lims'} = $run_row->batch_id();
        $ref->{'flowcell_barcode'} = $run_row->flowcell_id();
        $ref->{'driver_type'}      = $MLWH_DRIVER_TYPE;
        $ref->{'mlwh_schema'}      = $self->schema_mlwh();
      }
      # Fall back on some other driver type, for example,
      # samplesheet. This will allow to easily test this utility.
      my $lims = st::api::lims->new($ref);
      @lims_list =  $ref->{'position'} ? ($lims) : $lims->children();
    } catch {
      $self->logcroak(qq[Failed to get LIMs data for run ${id_run}: $_]);
    };

  return \@lims_list;
}

sub template_name {
  return 'run_status2followers';
}

has '_study_info' => (
  is         => 'ro',
  required   => 0,
  isa        => 'HashRef',
  lazy_build => 1,
);
sub _build__study_info {
  my $self = shift;

  my $h = {};

  foreach my $lane ( grep {!$_->is_control()} @{$self->lims()} ) {
    my @l = $lane->is_pool() ? (grep {!$_->is_control()} $lane->children()) : ($lane);
    foreach my $cl (@l) {
      my $study_id = $cl->study_id();
      if ($study_id) {
        if (!$h->{$study_id}->{'people'}) {
          $h->{$study_id}->{'people'} = $cl->email_addresses();
        }
        # Template Toolkit uses the same syntax for accessing methods of a
        # class and keys in a hash. We are going to exploit this feature.
        # For each position we create a hash which has the same keys as
        # the names of the methods of the st::api::lims object the template
        # will invoke.
        push @{$h->{$study_id}->{'lanes'}->{$cl->position()}->{'sample_names'}},
          $cl->sample_name() || q[unknown];
        $h->{$study_id}->{'lanes'}->{$cl->position()}->{'study_name'} =
          $cl->study_name() || q[unknown];
        $h->{$study_id}->{'lanes'}->{$cl->position()}->{'position'} = $cl->position();
      }
    }
  }

  return $h;
}

sub _build_reports {
  my $self = shift;

  my $study_info = $self->_study_info();
  my @reports = ();

  # These reports are grouped by study. If all samples in a run belong to one
  # study, one report is created.
  foreach my $study_id (sort {$a <=> $b} keys %{$study_info}) {
    my @people = @{$study_info->{$study_id}->{'people'}};
    my @lims_list = ();
    # Create a sorted by position list of hashes that mimic st::api::lims objects.
    foreach my $position ( sort {$a <=> $b} keys %{$study_info->{$study_id}->{'lanes'}} ) {
      my $lims_mimic = $study_info->{$study_id}->{'lanes'}->{$position};
      $lims_mimic->{'sample_names'} = [uniq sort @{$lims_mimic->{'sample_names'}}];
      push @lims_list, $lims_mimic;
    }

    if (@people && @lims_list) {
      my $subject = join q[: ], "Study $study_id", $self->report_short();
      push @reports, npg::util::mailer->new({
        from    => $self->report_author(),
        subject => $subject,
        body    => $self->report_full(\@lims_list),
        to      => [$self->username2email_address(@people)]
      });
    }
  }

  return \@reports;
}

1;

__END__

=head1 NAME

npg_tracking::report::event2followers

=head1 SYNOPSIS

 npg_tracking::report::event2followers->new(event_entity => $some_row)->emit();
 
=head1 DESCRIPTION

 Reports new run statuses by email to NPG followers, the end-users who are either
 study owners or managers or followers. The reports are generated for each study that
 had samples on a run that changes status.

 This class inherits from npg_tracking::report::event2subscribers and retains all
 attributes and methods of the parent.

=head1 SUBROUTINES/METHODS

=head2 dry_run

=head2 event_entity

=head2 schema_mlwh

 DBIx handle for a warehouse containing LIMs data, see WTSI::DNAP::Warehouse::Schema.
 This attribute is not lazy.

=head2 lims

 An array of lane-level st::api::lims type objects. An optional attribute, will be built
 if not set. To avoid circular dependencies between different NPG packages, if the
 schema_mlwh attribute is not set, the driver type will not be specified when building
 this attribute. The st::api::lims object should then figure out itself what driver to use.

=head2 reports

=head2 emit

=head2 template_name

=head2 template_dir_path

 Required attribute.

=head2 report_short

=head2 report_full

=head2 report_author

=head2 usernames2email_address
 
=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item List::MoreUtils

=item Try::Tiny

=item Readonly

=item st::api::lims

=item npg::util::mailer

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017,2021,2026 Genome Research Ltd.

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

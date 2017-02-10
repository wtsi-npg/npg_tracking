package npg_tracking::report::event2followers;

use Moose;
use npg::util::mailer;

extends 'npg_tracking::report::event2subscribers';

our $VERSION = '0';

sub _build_template_name {
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

  foreach my $lane ( map { !$_->is_control() } @{$self->lims()}) {
    my @l = $lane->is_pool() ? (map {!$_->is_control()} $lane->children()) : ($lane);
    foreach my $cl (@l) {
      my $study_id = $cl->study_id();
      if ($study_id) {
        if (!$h->{$study_id}->{'study_name'}) {
          $h->{$study_id}->{'study_name'} = $cl->study_name();
        }
        if (!$h->{$study_id}->{'people'}) {
          $h->{$study_id}->{'people'} = $cl->email_addresses();
        }
        push @{$h->{$study_id}->{$cl->position()}->{'sample_names'}},
          $cl->sample_name() || q[unknown];
      }
    }
  }

  foreach my $study_id (keys %{$h}) {
    foreach my $position (keys %{$h->{$study_id}}) {
      $h->{$study_id}->{$position}->{'position'}   = $position;
      $h->{$study_id}->{$position}->{'study_name'} = $h->{$study_id}->{'study_name'};
    }
    delete $h->{$study_id}->{'study_name'};
  }

  return $h;
}

sub _build_reports {
  my $self = shift;

  my @reports = ();

  foreach my $study_id (keys %{$self->_study_info()}) {

    my @people = @{$self->_study_info()->{$study_id}->{'people'}};
    my @lims_list = ();
    foreach my $position (sort {$a == $b} keys %{$self->_study_info()->{$study_id}}) {
      push @lims_list, $self->_study_info()->{$study_id}->{$position};
    }

    if (@people && @lims_list) {
      my $subject = join q[: ], "Study $study_id", $self->report_short();
      push @reports, npg::util::mailer->new(
        from    => $self->report_author(),
        subject => $subject,
        body    => $self->report_full(\@lims_list),
        to      => $self->usernames2email_address(@people),
      );
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

=head2 lims

=head2 reports

=head2 emit

=head2 template_name

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

=item Readonly

=item Carp

=item npg::util::mailer

=item st::api::lims

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 GRL

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

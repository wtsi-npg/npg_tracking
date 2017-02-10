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

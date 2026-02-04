package npg_tracking::report::event2subscribers;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use List::MoreUtils qw/uniq/;
use Template;
use Readonly;
use Carp;

use npg_tracking::util::types;
use npg::util::mailer;

with 'WTSI::DNAP::Utilities::Loggable';

our $VERSION = '0';

Readonly::Scalar my $TEMPLATE_EXT           => q[.tt2];
## no critic (ValuesAndExpressions::RequireInterpolationOfMetachars)
Readonly::Scalar my $DEFAULT_RECIPIENT_HOST => q[@sanger.ac.uk];
## use critic
Readonly::Scalar my $DEFAULT_AUTHOR         => q[srpipe];

has 'dry_run' => (
  isa       => 'Bool',
  is        => 'ro',
);

has 'event_entity' => (
  is       => 'ro',
  required => 1,
  isa      => 'DBIx::Class::Row',
);

has 'template_dir_path' => (
  isa        => 'NpgTrackingDirectory',
  is         => 'ro',
  required   => 1,
);

sub template_name {
  return 'instrument';
}

sub report_full {
  my ($self, $lims) = @_;

  my $text;
  my $t = Template->new(
    INCLUDE_PATH => [ $self->template_dir_path ],
    INTERPOLATE  => 1,
    OUTPUT       => \$text,
  )  || $self->logcroak($Template::ERROR);

  my $vars = {
    event_entity => $self->event_entity(),
  };
  if ($lims) {
    $vars->{lanes} = $lims;
  }

  $t->process($self->template_name() . $TEMPLATE_EXT, $vars )
    || $self->logcroak($t->error());

  return $text;
}

sub report_short {
  my $self = shift;
  return $self->event_entity->summary();
}

sub report_author {
  my $self = shift;
  return ($self->username2email_address($ENV{'USER'} || $DEFAULT_AUTHOR))[0];
}

sub username2email_address {
  my ($self, @users) = @_;
  my @emails = uniq
               map  { $_ =~ /@/xms ? $_ : $_ . $DEFAULT_RECIPIENT_HOST}
               grep { $_ }
               @users;
  @emails = sort @emails;
  return @emails;
}

sub _subscribers {
  my $self = shift;
  my $group = q[engineers];
  my @subscribers = ();
  my $schema = $self->event_entity->result_source->schema;
  my $group_row = $schema->resultset('Usergroup')->search(
                  {groupname => $group, iscurrent => 1})->next();
  if (!$group_row) {
    croak "Group $group is not available in the db";
  }
  push @subscribers, map  { $_->username() }
                     grep { $_->iscurrent() }
                     map  { $_->user() }
    $group_row->user2usergroups()->all();
  return [ $self->username2email_address(@subscribers) ];
}

has 'reports' => (
  is         => 'ro',
  required   => 0,
  isa        => 'ArrayRef',
  init_arg   => undef,
  lazy_build => 1,
);
sub _build_reports {
  my $self = shift;

  my @reports = ();
  my $subscribers = $self->_subscribers();
  if ( @{$subscribers} ) {
    push @reports, npg::util::mailer->new({
      from    => $self->report_author(),
      subject => $self->report_short(),
      body    => $self->report_full(),
      to      => $subscribers,
    });
  }
  return \@reports;
}

sub emit {
  my $self = shift;

  if (scalar @{$self->reports} == 0) {
    $self->info('No reports generated');
  }

  foreach my $report (@{$self->reports}) {
    if ($self->dry_run) {
      $self->info('DRY RUN ' . $report->get_subject());
    } else {
      $report->mail();
    }
  }
  return;
}

1;

__END__

=head1 NAME

npg_tracking::report::event2subscribers

=head1 SYNOPSIS

 npg_tracking::report::event2subscribers->new(event_entity => $some_row)->emit();
 
=head1 DESCRIPTION

 Reports new statuses or annotations by email to NPG subscribers. Instrument related events
 are reported to NPG users who are members of the group 'engineers'. Run and lane related
 events are reported to NPG users who are members of the group 'events'.

=head1 SUBROUTINES/METHODS

=head2 dry_run

 An optional boolean flag. Set it to avoid sending out reports.

=head2 event_entity

 A DBIx row object for one of the tables of the tracking database.
 A required attribute.

=head2 schema_mlwh

 DBIx handle for a warehouse containing LIMs data, see WTSI::DNAP::Warehouse::Schema.
 This attribute is not lazy.

=head2 lims

 An array of lane-level st::api::lims type objects. An optional attribute, will be built
 if not set. To avoid circular dependencies between different NPG packages, if the
 schema_mlwh attribute is not set, the driver type will not be specified when building
 this attribute. The st::api::lims object shoudl then figure out itself what driver to use.
 Objects generated using an xml driver are not accepted, resulting in an error.

=head2 reports

 An array of generated reports. This attribute cannot be set via a constructor.

=head2 emit

 Builds reports and either sends them or, if dry_run is true, prints short report
 content.

=head2 template_name

 Template name that should be used to generate a report.

=head2 template_dir_path

 Required attribute.

=head2 report_short

 Short report, used when dry_run oprion is enabled.

=head2 report_full

 A full test of the report that will be sent to the user.

=head2 report_author

 The e-mail address of the user from whom whose account the e-mail will be sent.

=head2 username2email_address

 Maps a list of username to email addresses.
 
=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item namespace::autoclean

=item List::MoreUtils

=item Template

=item Readonly

=item Carp

=item npg_tracking::util::types

=item npg::util::mailer

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017,2021,2023,2026 Genome Research Ltd.

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

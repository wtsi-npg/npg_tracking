#############
# Created By: ajb
# Created On: 2010-02-10

package npg::email::run::complete_archived;
use strict;
use warnings;
use Moose;
use Carp;
use English qw{-no_match_vars};
use POSIX qw(strftime);
our $VERSION = '0';

extends qw{npg::email::run};

=head1 NAME

npg::email::run::complete_archived

=head1 VERSION


=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 run

This method runs the relevant processing to send out emails, and record the successful sending, when a run reaches
'run complete' and 'run archived' to requested parties (Project related people from Sequencescape)

=cut

sub run {
  my ($self) = @_;
  $self->_mail_run_complete();
  $self->_mail_run_archived();
  return 1;
}

# private methods

has q{_no_run_complete_sent} => (isa => q{ArrayRef[Int]}, is => q{ro}, lazy_build => 1, writer => q{_set_complete});
has q{_no_run_archived_sent} => (isa => q{ArrayRef[Int]}, is => q{ro}, lazy_build => 1, writer => q{_set_archived});

sub _build__no_run_complete_sent {
  my ($self) = @_;
  return $self->_populate_sent_arrays(q{complete});
}

sub _build__no_run_archived_sent {
  my ($self) = @_;
  return $self->_populate_sent_arrays(q{archived});
}

sub _populate_sent_arrays {
  my ($self, $type) = @_;

  my $schema = $self->schema_connection();

  # get list of runs already with sent emails for run complete and run archived
  my $mailed = $schema->resultset(q{MailRunProjectFollower});
  my $mail_complete = {};
  my $mail_archived = {};
  while (my $mail = $mailed->next()) {
    if ($mail->run_complete_sent()) {
      $mail_complete->{$mail->id_run()}++;
    }
    if ($mail->run_archived_sent()) {
      $mail_archived->{$mail->id_run()}++;
    }
  }

  # get all runs which have a status of run complete, but have not yet had an email sent out
  my $no_run_complete_sent = $self->_runs_which_have_not_had_email_for_status(q{run complete}, $mail_complete);

  # get all runs which have a status of run archived, but have not yet had an email sent out
  my $no_run_archived_sent = $self->_runs_which_have_not_had_email_for_status(q{run archived}, $mail_archived);

  $self->_set_complete($no_run_complete_sent);
  $self->_set_archived($no_run_archived_sent);

  # currently only performing on two statuses, so return whichever one the initial request was for
  if ($type eq q{complete}) {
    return $no_run_complete_sent;
  }

  return $no_run_archived_sent;
}

# refactoring common code for determining non-sent status emails for run
sub _runs_which_have_not_had_email_for_status {
  my ($self, $status, $mailed) = @_;

  my $schema = $self->schema_connection();

  # get all run statuses with matching description, and process them against the hash keys in the mailed list
  my $rss = $schema->resultset(q(RunStatusDict))->find( {description => $status} )->run_statuses();
  my $not_sent = [];
  while (my $rs = $rss->next()) {
    my $id_run = $rs->id_run();
    if (!$mailed->{$id_run}) {
      push @{$not_sent}, $rs->id_run();
    }
  }
  return $not_sent;
}

# mail project owners for run complete, and update the database table with the datetime the email was sent
sub _mail_run_complete {
  my ($self) = @_;

  if (scalar @{$self->_no_run_complete_sent()}) {
    $self->_mail_group($self->_no_run_complete_sent(), q{run_complete});
  }

  return 1;
}

# mail project owners for run archived, and update the database table with the datetime the email was sent
sub _mail_run_archived {
  my ($self) = @_;

  if (scalar @{$self->_no_run_archived_sent()}) {
    $self->_mail_group($self->_no_run_archived_sent(), q{run_archived});
  }

  return 1;
}

# mail the group, and save out the timestamp that the mails where sent
sub _mail_group {
  my ($self, $runs_to_mail, $status) = @_;

  my $template = $status . q{.tt2};

  my $subject_suitable_status = $status;
  $subject_suitable_status =~ s/_/ /gxms;

  my $schema = $self->schema_connection();

  foreach my $id_run (@{$runs_to_mail}) {

    my $info;
    my $skip;
    # unfortunately, the dependency on Sequencescape can cause problems if there is just a problem with 1 batch
    # we will skip to the next run if this is the case
    eval {
      $info = $self->study_lane_followers($id_run);
    } or do {
      $skip++;
      carp qq{$EVAL_ERROR - this is not fatal, moving to next run};
    };

    next if $skip;

    eval {
      my $template_obj = $self->email_templates_object();

      foreach my $project (sort keys %{$info}) {

        $template_obj->process($template, {
            project => $project,
            run => $id_run,
            lanes => $info->{$project}->{lanes},
          });

        my $tos = $info->{$project}->{followers};

        foreach my $to (@{$tos}) {
          if ($to !~ /@/xms) {
            $to .= $self->default_recipient_host();
          }
        }

        $self->send_email({
            body => $self->next_email(),
            to => $tos,
            subject => q{Run } . $id_run . q{ - } . $subject_suitable_status . q{ - } . $project,
          });
      }

      # now record that emails for this lane at this status was sent was sent
      my $ts = strftime '%Y-%m-%d %H:%M:%S', localtime time;

      my $column = $status . q{_sent};
      $schema->resultset(q{MailRunProjectFollower})->update_or_create({id_run => $id_run, $column => $ts});
      1;
    }
    or do {
      croak qq{Failed to send emails/update sent for run $id_run - $EVAL_ERROR};
    };

  }
  return;
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

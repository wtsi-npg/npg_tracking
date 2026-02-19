package npg::model::run_status;

use strict;
use warnings;
use English qw(-no_match_vars);
use Carp;

use npg::model::run_status_dict;

use base qw(npg::model);

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a([qw(run user run_status_dict)]);

sub fields {
  return qw(id_run_status
            id_run
            date
            id_run_status_dict
            id_user
            iscurrent);
}

sub create {
  my $self     = shift;
  my $util     = $self->util();
  my $dbh      = $util->dbh();
  my $tr_state = $util->transactions();

  eval {
    my $rows = $dbh->do(q(UPDATE run_status
                          SET    iscurrent = 0
                          WHERE  id_run    = ?), {},
               $self->id_run());

    my $query = q(INSERT INTO run_status (id_run,date,id_run_status_dict,id_user,iscurrent)
                  VALUES (?,now(),?,?,1));

    $dbh->do($query, {},
            $self->id_run(),
            $self->id_run_status_dict(),
            $self->id_user());

    my $idref = $dbh->selectall_arrayref('SELECT LAST_INSERT_ID()');
    $self->id_run_status($idref->[0]->[0]);

    $util->transactions(0);

    $self->run()->instrument()->autochange_status_if_needed(
      $self->run_status_dict->description());

    1;

  } or do {
    $util->transactions($tr_state);
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR;
  };

  $util->transactions($tr_state);

  eval {
    $tr_state and $dbh->commit();
    1;

  } or do {
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR;
  };

  return 1;
}

1;
__END__

=head1 NAME

npg::model::run_status

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 user - npg::model::user who actioned this status

  my $oOperatingUser = $oRunStatus->user();

=head2 run - npg::model::run to which this run_status belongs

  my $oRun = $oRunStatus->run();

=head2 run_status_dict - npg::model::run_status_dict for this status's id_run_status_dict

  my $oRunStatusDict = $oRunStatus->run_status_dict();

=head2 create - special handling for dates & iscurrent

  $oRunStatus->create();

  Sets date using database's now() function
  Sets all other run_status for this id_run to iscurrent=0
  Sets this iscurrent=1 (whatever was set/unset in the object);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::model

=item English

=item Carp

=item npg::model::run_status_dict

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Roger Pettett

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007-2012, 2013,2014,2018,2025,2026  Genome Research Ltd.

This file is part of NPG.

NPG is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .

=cut

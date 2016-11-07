#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::instrument;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::user;
use npg::model::run;
use npg::model::instrument_format;
use npg::model::instrument_status;
use npg::model::instrument_status_dict;
use npg::model::instrument_mod;
use npg::model::instrument_annotation;
use npg::model::annotation;
use npg::model::instrument_designation;
use npg::model::designation;
use DateTime;
use List::MoreUtils qw/any/;

our $VERSION = '0';

use Readonly;
Readonly::Scalar our $HISEQ_INSTR_MODEL => 'HiSeq';
Readonly::Scalar our $MISEQ_INSTR_MODEL => 'MiSeq';
Readonly::Scalar our $CBOT_INSTR_MODEL  => 'cBot';
Readonly::Array  our @FC_SLOT_TAGS    => qw/fc_slotA fc_slotB/;

Readonly::Array  our @CURRENT_RUNS    => ('run pending', 'run in progress', 'run on hold', 'run complete');
Readonly::Array  our @BLOCKING_RUNS   => ('run pending', 'run in progress', 'run on hold');

Readonly::Hash my %STATUS_CHANGE_AUTO => {
  'up'                  => 'wash required',
  'wash performed'      => 'up',
  'planned repair'      => 'down for repair',
  'planned service'     => 'down for service',
};

Readonly::Hash my %STATUS_GRAPH => {
  'up'               => ['planned service', 'planned repair', 'down for repair', 'wash required', 'wash in progress'],

  'wash required'    => ['wash in progress', 'wash performed', 'planned repair', 'planned service', 'down for repair'],
  'wash in progress' => ['wash performed', 'planned repair', 'planned service', 'down for repair'],
  'wash performed'   => ['up', 'wash required', 'down for repair'],

  'planned repair'   => ['down for repair'],
  'planned service'  => ['down for service', 'planned repair', 'down for repair'],

  'down for repair'  => ['wash required'],
  'down for service' => ['wash required', 'down for repair'],
};

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a('instrument_format');
__PACKAGE__->has_many(['instrument_mod']);
__PACKAGE__->has_many_through('annotation|instrument_annotation');
__PACKAGE__->has_many_through('designation|instrument_designation');
__PACKAGE__->has_all();

sub fields {
  return qw(id_instrument
            name
            external_name
            id_instrument_format
            serial
            iscurrent
            ipaddr
            instrument_comp
            mirroring_host
            staging_dir
            latest_contact
            percent_complete);
}

sub init {
  my $self = shift;

  if($self->{'name'} &&
     !$self->{'id_instrument'}) {
    my $query = q(SELECT id_instrument
                  FROM   instrument
                  WHERE  name = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->name());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{'id_instrument'} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub instrument_by_instrument_comp {
  my ($self, $instrument_comp) = @_;

  if($instrument_comp){
      return (grep {$_->instrument_comp() && $_->instrument_comp() eq $instrument_comp } @{$self->instruments()})[0];
  }

  return;
}

sub current_instruments {
  my $self  = shift;

  if(!$self->{current_instruments}) {
    my $pkg   = ref $self;
    my $query = qq(SELECT @{[join q(, ), $self->fields()]}
                   FROM   @{[$self->table()]}
                   WHERE  iscurrent = 1
                   ORDER BY id_instrument);
    $self->{current_instruments} = $self->gen_getarray($pkg, $query);
  }

  return $self->{current_instruments};
}

sub current_run {
  my $self  = shift;
  return $self->current_runs->[0];
}

sub current_runs {
  my $self  = shift;
  if(!$self->{current_runs}) {
    $self->{current_runs} = $self->runs_with_status(\@CURRENT_RUNS);
  }
  return $self->{current_runs};
}

sub blocking_runs {
  my $self  = shift;
  if(!$self->{blocking_runs}) {
    $self->{blocking_runs} = $self->runs_with_status(\@BLOCKING_RUNS);
  }
  return $self->{blocking_runs};
}

sub runs_with_status {
  my ($self, $run_statuses) = @_;

  if (!defined $run_statuses) {
    croak q[Reference to an array of run statuses should be given];
  }

  my $statuses = join q(, ), map { "'$_'" } @{$run_statuses};

  my $pkg   = 'npg::model::run';
  my $query = qq(SELECT @{[join q(, ), map { "r.$_" } $pkg->fields()]}
                   FROM   @{[$pkg->table()]} r,
                          run_status         rs,
                          run_status_dict    rsd
                   WHERE  r.id_instrument       = ?
                   AND    r.id_run              = rs.id_run
                   AND    rs.id_run_status_dict = rsd.id_run_status_dict
                   AND    rs.iscurrent          = 1
                   AND    rsd.description IN ($statuses)
                   ORDER BY date DESC
                  );
  return $self->gen_getarray($pkg,$query,$self->id_instrument());
}

sub model {
  my $self = shift;
  return $self->instrument_format->model();
}

sub id_manufacturer {
  my $self = shift;
  return $self->instrument_format->id_manufacturer();
}

sub manufacturer {
  my $self = shift;
  return $self->instrument_format->manufacturer();
}

sub runs {
  my ($self, $params) = @_;

  if($self->{runs}) {
    return $self->{runs};
  }

  $params ||= {};

  my $pkg    = 'npg::model::run';
  my $query  = q[];
  my @params = ($self->id_instrument());

  if($params->{id_run_status_dict}) {
    $query = qq[SELECT @{[join q[, ], map { "r.$_" } $pkg->fields()]}
                FROM   @{[$pkg->table()]} r,
                       run_status rs
                WHERE  r.id_instrument = ?
                AND    rs.id_run       = r.id_run
                AND    rs.iscurrent    = 1
                AND    rs.id_run_status_dict = ?
                ORDER BY rs.date DESC];
    push @params, $params->{id_run_status_dict};

  } else {
    $query = qq[SELECT @{[join q[, ], $pkg->fields()]}
                FROM   @{[$pkg->table()]}
                WHERE  id_instrument = ?
                ORDER BY id_run DESC];
  }

  if($params->{len} || $params->{start}) {
    $query = $self->util->driver->bounded_select($query,
                                                $params->{len},
                                                $params->{start});
  }

  return $self->gen_getarray($pkg, $query, @params);
}

sub count_runs {
  my ($self, $params) = @_;

  if(defined $self->{count_runs}) {
    return $self->{count_runs};
  }

  $params  ||= {};
  my $pkg    = 'npg::model::run';
  my $query  = q[];
  my @params = ($self->id_instrument());

  if($params->{id_run_status_dict}) {
    $query = qq[SELECT COUNT(*)
                FROM   @{[$pkg->table()]} r,
                       run_status rs
                WHERE  r.id_instrument = ?
                AND    rs.id_run       = r.id_run
                AND    rs.iscurrent    = 1
                AND id_run_status_dict = ?];
    push @params, $params->{id_run_status_dict};

  } else {
    $query = qq[SELECT COUNT(*)
                FROM   @{[$pkg->table()]}
                WHERE  id_instrument = ?];
  }

  my $ref = $self->util->dbh->selectall_arrayref($query, {}, @params);
  if(defined $ref->[0] &&
     defined $ref->[0]->[0]) {
    return $ref->[0]->[0];
  }

  return;
}

sub instrument_statuses {
  my $self = shift;

  my $pkg   = 'npg::model::instrument_status';
  my $query = qq(SELECT @{[join q(, ), map { "rs.$_" } $pkg->fields()]},
                          rsd.description AS description
                   FROM   @{[$pkg->table()]}     rs,
                          instrument_status_dict rsd
                   WHERE  rs.id_instrument             = ?
                   AND    rs.id_instrument_status_dict = rsd.id_instrument_status_dict
                   ORDER BY rs.id_instrument_status DESC);
  $self->{'instrument_statuses'} = $self->gen_getarray($pkg, $query, $self->id_instrument());
  return $self->{'instrument_statuses'};
}

sub current_instrument_mods {
  my $self = shift;
  if(!$self->{current_instrument_mods}) {
    my $dbh = $self->util->dbh();
    my $query = q(SELECT im.id_instrument, im.date_added, im.date_removed, im.id_user, im.iscurrent, im.id_instrument_mod, im.id_instrument_mod_dict, imd.description, imd.revision
                  FROM   instrument_mod im, instrument_mod_dict imd
                  WHERE  im.id_instrument = ?
                  AND    im.id_instrument_mod_dict = imd.id_instrument_mod_dict
                  AND    im.iscurrent = 1
                  ORDER BY imd.description);
    my $sth = $dbh->prepare($query);
    $sth->execute($self->id_instrument());
    while (my $href = $sth->fetchrow_hashref()) {
      my $description = lc$href->{description};
      $description =~ s/\s/_/gxms;
      $self->{current_instrument_mods}->{$description} = $href;
    }
  }
  return $self->{current_instrument_mods};
}

sub current_instrument_status {
  my ($self) = @_;

  my $pkg   = 'npg::model::instrument_status';
  my $query = qq(SELECT @{[join q(, ), $pkg->fields()]}
                   FROM   @{[$pkg->table()]}
                   WHERE  id_instrument = ?
                   AND    iscurrent     = 1
                   ORDER BY date DESC
                   LIMIT 1);
  $self->{'current_instrument_status'} = $self->gen_getarray($pkg, $query, $self->id_instrument())->[0];
  return $self->{'current_instrument_status'};
}

sub latest_instrument_annotation {
  my $self = shift;

  if(!$self->{latest_instrument_annotation}) {
    my $pkg   = 'npg::model::instrument_annotation';
    my $query = q[SELECT id_instrument_annotation
                  FROM   instrument_annotation ia,
                         annotation a
                  WHERE  id_instrument    = ?
                  AND    ia.id_annotation = a.id_annotation
                  AND    date          = (SELECT MAX(date)
                                          FROM   instrument_annotation ia,
                                                 annotation a
                                          WHERE  id_instrument    = ?
                                          AND    ia.id_annotation = a.id_annotation)];
    my $ref = $self->gen_getarray($pkg, $query, $self->id_instrument(), $self->id_instrument());
    if(scalar @{$ref}) {
      $self->{latest_instrument_annotation} = $ref->[0];
    }
  }

  return $self->{latest_instrument_annotation};
}

sub latest_annotation {
  my $self = shift;

  if(!$self->{latest_annotation}) {
    my $ia = $self->latest_instrument_annotation();
    if(!$ia) {
      return;
    }
    $self->{latest_annotation} = $ia->annotation();
  }

  return $self->{latest_annotation};
}

sub does_sequencing {
  my $self = shift;
  return ($self->instrument_format->model && $self->instrument_format->model ne $CBOT_INSTR_MODEL);
}

sub is_two_slot_instrument {
  my $self = shift;
  return ($self->instrument_format->model && $self->instrument_format->model =~ /\A$HISEQ_INSTR_MODEL/smx);
}

sub is_cbot_instrument {
  my $self = shift;
  return ($self->instrument_format->model && $self->instrument_format->model eq $CBOT_INSTR_MODEL);
}

sub is_miseq_instrument {
  my $self = shift;
  return ($self->instrument_format->model && $self->instrument_format->model eq $MISEQ_INSTR_MODEL);
}

sub current_run_by_id {
  my ($self, $id_run) = @_;
  foreach my $run (@{$self->current_runs}) {
    if ($run->id_run == $id_run) {
      return $run;
    }
  }
  return;
}

sub _fc_slots2runs {
  my ($self, $runs_type) = @_;

  if (!$self->is_two_slot_instrument) { return; }

  if (!defined $runs_type) {
    croak q[runs type should be defined];
  }
  if ($runs_type !~ /current|blocking/smx) {
    croak qq[Unknown run category $runs_type];
  }

  my $method = $runs_type . q[_runs];
  my $slots = {};
  foreach my $slot (@FC_SLOT_TAGS) {
      $slots->{$slot} = [];
  }

  foreach my $run (@{$self->$method}) {
    foreach my $tag (@{$run->tags}) {
      my $tag_value = $tag->tag;
      my @fcells =  grep { /^$tag_value$/smx } @FC_SLOT_TAGS;
      if (@fcells) {
        push @{$slots->{$fcells[0]}}, $run->id_run;
      }
    }
  }

  return $slots;
}

sub fc_slots2current_runs {
  my $self = shift;
  return $self->_fc_slots2runs(q[current]);
}

sub fc_slots2blocking_runs {
  my $self = shift;
  return $self->_fc_slots2runs(q[blocking]);
}

sub is_idle {
  my $self = shift;
  return @{$self->current_runs} ? 0 : 1;
}

sub status_to_change_to {
  my ($self, $run_status) = @_;

  my $cis = $self->current_instrument_status();
  if (!$cis ) { return; }
  my $current = $cis->instrument_status_dict()->description();
  if (!exists $STATUS_CHANGE_AUTO{$current}) {
    return;
  }
  my $next_auto = $STATUS_CHANGE_AUTO{$current};

  if ($self->does_sequencing) {
    if ( $self->is_idle() &&
      ($current eq 'planned repair' ||
       $current eq 'planned service')) {
        return $next_auto;
    }

    if ($current eq 'wash performed' ||
       ($current eq 'up' && $run_status &&
          ( $run_status eq 'run cancelled' ||
            $run_status eq 'run stopped early' ||
            $run_status eq 'run complete'
          ))
        ) {
      return $next_auto;
    }
  } elsif ($self->is_cbot_instrument && $current eq 'wash performed') {
    return $next_auto;
  }
  return;
}

sub status_reset {
  my ($self, $new_status) = @_;

  if (!$new_status) {
    croak q[Status to change to should be defined];
  }

  my $id = $self->id_instrument();

  eval {
    my $user = npg::model::user->new({
      util     => $self->util,
      username => 'pipeline',
    });

    my $new_status_obj = npg::model::instrument_status_dict->new({
      util        => $self->util,
      description => $new_status,
    });

    npg::model::instrument_status->new({
      util                      => $self->util(),
      id_instrument             => $id,
      id_instrument_status_dict => $new_status_obj->id_instrument_status_dict(),
      id_user                   => $user->id_user(),
      comment                   => 'automatic status update',
    })->create();

  } or do {
    croak qq[Unable to move instrument ID=$id status to $new_status: $EVAL_ERROR];
  };

  return 1;
}

sub autochange_status_if_needed {
  my ($self, $run_status) = @_;

  if ($self->does_sequencing) {
    if (!$run_status) {
      croak 'Run status needed';
    }
    my $new_instr_status = $self->status_to_change_to($run_status);
    if ($new_instr_status) {
      eval {
        $self->status_reset($new_instr_status);
        1;
      } or do {
        carp qq[Error when attempting to autochange status: $EVAL_ERROR];
      };
    }
  }
  return 0;
}

sub possible_next_statuses4status {
  my ($self, $status) = @_;

  $status ||= $self;
  if (!$status || ref $status) {
    croak 'Current status should be given';
  }
  if (!exists $STATUS_GRAPH{$status}) {
    croak "Status '$status' is nor registered in the status graph";
  }
  if (!$STATUS_GRAPH{$status} || !@{$STATUS_GRAPH{$status}}) {
    croak "No dependencies for status '$status' in the status graph";
  }
  return $STATUS_GRAPH{$status};
}


sub possible_next_statuses {
  my $self = shift;

  my $next_statuses = {};
  my $cis = $self->current_instrument_status();
  if ($cis) {
    my $dict_hash = {};
    foreach my $dict_entry (@{$cis->instrument_status_dict->instrument_status_dicts()}) {
      $dict_hash->{$dict_entry->description()} = $dict_entry->id_instrument_status_dict();
    }
    my $count = 1;
    foreach my $nxt ( @{$self->possible_next_statuses4status($cis->instrument_status_dict->description())}) {
      $next_statuses->{$count} = {$nxt => $dict_hash->{$nxt},};
      $count++;
    }
  }
  return $next_statuses;
}

1;
__END__

=head1 NAME

npg::model::instrument

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION
  Clearpress model for an instrument.
  To be replaced by DBIx model. Contains duplicates of functions in
  npg_tracking::Schema::Result::Instrument. When editing the code
  of this module consider if any changes are meeded in the other module. 

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - additional handling for creating instruments by name

  my $oInstrument = npg::model::instrument->new({
    'util' => $oUtil,
    'name' => $sInstrumentName, # e.g. 'IL1'
  });

=head2 instrument_format - npg::model::instrument_format of this instrument

  my $oInstrumentformat = $oInstrument->instrument_format();

=head2 instruments - arrayref of all npg::model::instruments

  my $arAllInstruments = $oInstrument->instruments();

=head2 instrument_by_ipaddr - npg::model::instrument by its IP address

  my $oInstrument = $oInstrument->instrument_by_ipaddr('127.0.0.1');
instrument_by_instrument_comp

=head2 instrument_by_instrument_comp - npg::model::instrument by its instrument_comp name

=head2 current_instruments - arrayref of all npg::model::instruments with iscurrent=1

  my $arCurrentInstruments = $oInstrument->current_instruments();

=head2 last_wash_instrument_status - npg::model::instrument_status (or undef) corresponding to the last 'wash performed' state

  my $oInstrumentStatus = $oInstrument->last_wash_instrument_status();

=head2 check_wash_status - boolean whether this instrument needs washing

Has a side-effect of updating an instrument's current instrument_status to 'wash required'

 $bNeedAWash = $oInstrument->check_wash_status();

=head2 runs - arrayref of npg::model::runs for this instrument

  my $arRuns = $oInstrument->runs();

  my $arRunsBounded = $oInstrument->runs({
    len   => 20,
    start => 40,
  });

  my $arRunsForStatus = $oInstrument->runs({
    id_instrument_status_dict => 11,
  });

=head2 count_runs - count of runs for this instrument

  my $iRunCount = $oInstrument->count_runs();

  my $iRunCount = $oInstrument->count_runs({
    id_run_status_dict => 11,
  });

=head2 current_run - the npg::model::run with the latest current_status for this instrument

  my $oRun = $oInstrument->current_run();

=head2 current_runs - a reference to an array of npg::model::run objects representing current runs on this instrument

  my $oRuns = $oInstrument->current_runs();

=head2 blocking_runs - a reference to an array of npg::model::run objects representing blocking runs on this instrument

=head2 runs_with_status - a reference to an array of npg::model::run objects representing blocking runs with certain statuses on this instrument, a list of statuses should be given as an argument
  my $oRuns = $oInstrument->runs_with_status(['some status', 'other status']);

=head2 model - model of this machine, via its instrument_format

  my $sModel = $oInstrument->model();

=head2 id_manufacturer - id_manufacturer of this machine, via its instrument_format

  my $iIdManufacturer = $oInstrument->id_manufacturer();

=head2 manufacturer - npg::model::manufacturer of this machine, via its instrument_format

  my $oManufacturer = $oInstrument->manufacturer();

=head2 instrument_statuses - arrayref of npg::model::instrument_statuses for this instrument

  my $arInstrumentStatuses = $oInstrument->instrument_statuses();

=head2 current_instrument_status - npg::model::instrument_status with iscurrent=1 for this instrument

  my $oInstrumentStatus = $oInstrument->current_instrument_status();

=head2 instrument_mods - returns array of instrument modifications for this instrument

  my $aInstrumentMods = $oInstrument->instrument_mods();

=head2 current_instrument_mods - returns the current instrument modifications (as hashref keyed on description) for this instrument

  my $hCurrentInstrumentMods = $oInstrument->current_instrument_mods();

=head2 latest_instrument_annotation - The most recent npg::model::instrument_annotation for this instrument

  my $oInstrumentAnnotation = $oInstrument->latest_instrument_annotation();

=head2 latest_annotation - The npg::model::annotation from latest_instrument_annotation

  my $oAnnotation = $oInstrument->latest_annotation();

=head2 fc_slots2current_runs - a hash reference mapping instrument flowcell slots to current runs; tags for slots are used as keys
=head2 fc_slots2blocking_runs - a hash reference mapping instrument flowcell slots to blocking runs; tags for slots are used as keys

=head2 does_sequencing - returns true is the instrument does sequencing, false otherwise

=head2 is_two_slot_instrument - returns true if this instrument has two slots, false otherwise

=head2 is_miseq_instrument

returns true if the instrument is a MiSeq, false otherwise

=head2 is_cbot_instrument - returns true if this instrument is CBot, false otherwise

=head2 current_run_by_id - returns one of current runs with teh argument id or nothing if a list of current runs does not contain a run with this id
 
 my $id_run = 22;
 my $run = $oInstrument->current_run_by_id($id_run);

=head2 is_idle - returns true if the instrument is idle false otherwise. The instrument is idle if it has not current runs associated with it.

=head2 status_to_change_to - returns a status teh instrument should be or undefined if no change is necessary

=head2 status_reset - resets the status of the instrument to a new status
 $oInstrument->status_reset('new status');

=head2 autochange_status_if_needed - automatic status change if needed. If the status has been changed, 1 is returned, the the change is not needed or it has changed, 0 is returned.

=head2 possible_next_statuses4status - returns an array ref of possible next statuses for an argument status

=head2 possible_next_statuses - returnes a hash ref with possible next statuses for this instrument together with their ids; the hash keys define the logical order of the statuse

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

=item npg::model::user

=item npg::model::run

=item npg::model::instrument_format

=item npg::model::instrument_status

=item npg::model::instrument_status_dict

=item npg::model::instrument_mod

=item DateTime

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

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

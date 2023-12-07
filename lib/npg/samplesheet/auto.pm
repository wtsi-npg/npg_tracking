package npg::samplesheet::auto;

use Moose;
use namespace::autoclean;
use Try::Tiny;
use File::Basename;
use Readonly;
use File::Copy;
use File::Spec::Functions;
use Carp;

use npg::samplesheet;
use npg_tracking::Schema;
use WTSI::DNAP::Warehouse::Schema;
use st::api::lims::samplesheet;

with q(MooseX::Log::Log4perl);

our $VERSION = '0';

Readonly::Scalar my $MISEQ_INSTRUMENT_FORMAT => 'MiSeq';
Readonly::Scalar my $DEFAULT_SLEEP => 90;

##no critic (Subroutines::ProhibitUnusedPrivateSubroutine)

=head1 NAME

npg::samplesheet::auto

=head1 VERSION

=head1 SYNOPSIS

  use npg::samplesheet::auto;
  use Log::Log4perl qw(:easy);
  BEGIN{ Log::Log4perl->easy_init({level=>$INFO,}); }
  npg::samplesheet::auto->new(instrument_format => 'MiSeq')->loop();

=head1 DESCRIPTION

Class for creating Illumina samplesheets automatically for runs which are
pending. Currently is implemented only for MiSeq instruments'

=head1 SUBROUTINES/METHODS

=head2 npg_tracking_schema

=cut

has 'npg_tracking_schema' => (
  'isa'        => 'npg_tracking::Schema',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build_npg_tracking_schema {
  return npg_tracking::Schema->connect();
}

=head2 mlwh_schema

=cut

has 'mlwh_schema' => (
  'isa'        => 'WTSI::DNAP::Warehouse::Schema',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build_mlwh_schema {
  return WTSI::DNAP::Warehouse::Schema->connect();
}

=head2 instrument_format

=cut

has 'instrument_format' => (
  'isa'     => 'Str',
  'is'      => 'ro',
  'default' => $MISEQ_INSTRUMENT_FORMAT,
);

=head2 sleep_interval

=cut

has 'sleep_interval' => (
  'is'      => 'ro',
  'isa'     => 'Int',
  'default' => $DEFAULT_SLEEP,
);

=head2 BUILD

Tests that a valid instrument format is used.

=cut

sub BUILD {
  my $self = shift;
  if ($self->instrument_format ne $MISEQ_INSTRUMENT_FORMAT) {
    my $m = sprintf
      'Samplesheet auto-generator is not implemented for %s instrument format',
      $self->instrument_format;
    $self->log->fatal($m);
    croak $m;
  }
  return;
}

=head2 loop

Repeat the process step with the intervening sleep interval.

=cut

sub loop {
  my $self = shift;
  while(1) { $self->process(); sleep $self->sleep_interval;}
  return;
};

=head2 process

Find all pending MiSeq runs and create an Illumina  samplesheet for each
of them if one does not already exist.

=cut

sub process {
  my $self = shift;

  my $rt = $self->_pending->run_statuses->search({iscurrent=>1})
                ->related_resultset(q(run));
  my $rs = $rt->search(
    {q(run.id_instrument_format) => $self->_instr_format_obj->id_instrument_format});
  $self->log->debug( $rs->count. q[ ] .($self->_instr_format_obj->model).
    q[ runs marked as ] .($self->_pending->description));

  while(my$r=$rs->next) { # Loop over pending runs for this instrument format;

    my $id_run = $r->id_run;
    $self->log->info('Considering ' . join q[,],$id_run,$r->instrument->name);

    my $ss = npg::samplesheet->new(
      run => $r, mlwh_schema => $self->mlwh_schema
    );
    my $method_name =
      '_valid_samplesheet_file_exists_for_' . $self->instrument_format;
    my $generate_new = !$self->$method_name($ss, $id_run);

    if ($generate_new) {
      # Do not overwrite existing file if it exists.
      my $o = $ss->output;
      $self->_move_samplesheet_if_needed($o);
      try {
        $ss->process;
        $self->log->info(qq($o created for run ).($r->id_run));
      } catch {
        $self->log->error(qq(Trying to create $o for run ).($r->id_run).
                          qq( experienced error: $_));
      }
    }
  }

  return;
}

has '_instr_format_obj' => (
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build__instr_format_obj {
  my $self=shift;
  my $row = $self->npg_tracking_schema->resultset(q(InstrumentFormat))
              ->find({q(model)=>$self->instrument_format});
  if (!$row) {
    croak sprintf 'Instrument format %s is not registered',
      $self->instrument_format;
  }
  return $row;
}

has '_pending' => (
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build__pending {
  my $self=shift;
  return $self->npg_tracking_schema->resultset(q(RunStatusDict))
              ->find({q(description)=>q(run pending)});
}

sub _id_run_from_samplesheet {
  my $file_path = shift;
  my $id_run;
  try {
    my $sh = st::api::lims::samplesheet->new(path => $file_path);
    $sh->data; # force to parse the file
    if ($sh->id_run) {
      $id_run = int $sh->id_run;
    }
  };
  return $id_run;
}

sub _move_samplesheet_if_needed {
  my ($self, $file_path) = @_;

  if (!-e $file_path) {
    return;
  }

  $self->log->info(qq(Will move existing $file_path));

  my($filename, $dirname) = fileparse($file_path);
  $dirname =~ s/\/$//smx; #drop last forward slash if any
  my $dirname_dest = $dirname . '_old';
  my $filename_dest = $filename . '_invalid';
  my $moved;
  if (-d $dirname_dest) {
    $moved = move($file_path, catdir($dirname_dest, $filename_dest));
  }
  if (!$moved) {
    move($file_path, catdir($dirname, $filename_dest));
  }
  return;
}

sub _valid_samplesheet_file_exists_for_MiSeq {##no critic (NamingConventions::Capitalization)
  my ($self, $ss_object, $id_run) = @_;

  my $o = $ss_object->output;
  if(-e $o) {
    my $other_id_run = _id_run_from_samplesheet($o);
    if ($other_id_run && $other_id_run == $id_run) {
      $self->log->info(qq($o already exists for $id_run));
      return 1;
    }
  }

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item File::Basename

=item File::Copy

=item Moose

=item namespace::autoclean

=item MooseX::Log::Log4perl

=item Readonly

=item File::Spec::Functions

=item Try::Tiny

=item Carp

=item npg_tracking::Schema

=item npg::samplesheet

=item st::api::lims::samplesheet

=item WTSI::DNAP::Warehouse::Schema

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012,2013,2014,2019,2021,2023 GRL.

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


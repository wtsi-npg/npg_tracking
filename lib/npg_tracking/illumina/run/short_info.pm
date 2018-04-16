package npg_tracking::illumina::run::short_info;

use Moose::Role;
use Moose::Util::TypeConstraints;
use File::Spec::Functions qw(splitdir);
use Carp;
use Try::Tiny;
use Readonly;

use npg_tracking::util::types;

our $VERSION = '0';

Readonly::Scalar my $INSTRUMENT_PATTERN              => '(IL|HS|HX|HF|MS)';
Readonly::Scalar my $NAME_PATTERN                    => $INSTRUMENT_PATTERN.'(\d+_)0*(\d+)';
Readonly::Scalar my $LONG_FOLDER_NAME_SUFFIX_PATTERN => '_(A|B)_?([0-9A-Z]{9}(?:-\d{3}V\d)?)';

has q{id_run}           => (
  isa           => q{NpgTrackingRunId},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
  documentation => 'Integer identifier for a sequencing run',
);

has q{name}              => (
  isa           => q{Str},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
  documentation => join q[ ],
                   qw/String identifier for a sequencing run/, q[,],
                   qw/usually contains a sequencing instrument
                      identifer and the id_run attribute value/,
);

has q{instrument_string} => (
  isa           => q{Str},
  is            => q{ro},
  lazy_build    => 1,
  documentation => q{Instrument name},
);

has q{slot}              => (
  isa           => q{Str},
  is            => q{ro},
  lazy_build    => 1,
  writer        => q{_set_slot},
  documentation => q{Instrument slot},
);

has q{flowcell_id}       => (
  isa           => q{Str},
  is            => q{ro},
  lazy_build    => 1,
  writer        => q{_set_flowcell_id},
  documentation => q{Flowcell identifier},
);

subtype __PACKAGE__.q(::folder)
  => as 'Str'
  => where {splitdir($_)==1};
coerce __PACKAGE__.q(::folder)
  => from 'Str'
  => via {first {$_ ne q()} reverse splitdir($_)};
has q{run_folder}        => (
  isa           => __PACKAGE__.q(::folder),
  is            => q{ro},
  lazy_build    => 1,
  documentation => 'Directory name of the run folder',
);

sub short_reference {
  my ($self) = @_;
  my $return_value = $self->has_run_folder()  ? $self->run_folder()
                   : $self->has_id_run()      ? $self->id_run()
                   :                            $self->name()
                   ;
  return $return_value;
}

###############
# private methods

###############

sub _build_id_run {
  my ($self) = @_;

  if ( !$self->has_run_folder() ) {
    try {
      $self->run_folder();
    } catch {
      croak qq{Unable to obtain id_run from run_folder : $_};
    };
  }

  my ($inst_t, $inst_i, $id_run) = $self->run_folder() =~ /$NAME_PATTERN/gmsx;

  if ( !( $inst_t && $inst_i && $id_run ) ) {
    if ($self->can(q(npg_tracking_schema)) and  $self->npg_tracking_schema()) {
      my $rs = $self->npg_tracking_schema()->resultset('Run')
               ->search({folder_name => $self->run_folder()});
      if ($rs->count == 1) {
        $id_run = $rs->next()->id_run();
      }
    }
  }

  return $id_run;
}

sub _build_name {
  my ($self) = @_;
  if( !( $self->has_id_run() || $self->has_run_folder() ) ) {
    try {
      $self->run_folder();
    } catch {
      croak qq{Unable to obtain name from run_folder : $_};
    };
  }
  my ($start, $middle, $end) = $self->run_folder() =~ /$NAME_PATTERN/xms;
  croak q{Unrecognised format for run folder name: } . $self->run_folder()
    if !( $start && $middle && $end );

  return $start.$middle.$end;
}

sub _build_instrument_string {
  my ( $self ) = @_;
  my ( $start, $end ) = $self->name() =~ /$INSTRUMENT_PATTERN(\d+)/xms;
  return $start . $end;
}

sub _build_slot {
  my ( $self ) = @_;
  $self->_hs_info();
  return $self->slot();
}

sub _build_flowcell_id {
  my ( $self ) = @_;
  $self->_hs_info();
  return $self->flowcell_id();
}

sub _hs_info {
  my ( $self ) = @_;

  my @parts = $self->run_folder() =~ m/${NAME_PATTERN}$LONG_FOLDER_NAME_SUFFIX_PATTERN/xms;
  my $flowcell_id = pop @parts;
  $self->_set_flowcell_id( $flowcell_id || q{});
  my $slot = pop @parts;
  $self->_set_slot( $slot || q{});

  return 1;
}

no Moose::Role;

1;
__END__

=head1 NAME

npg_tracking::illumina::run::short_info

=head1 VERSION

=head1 SYNOPSIS

  package Mypackage;
  use Moose;
  with q{npg_tracking::illumina::run::short_info};

=head1 DESCRIPTION

This Moose role ties together three attributes, id_run, name and run_folder,
which are central to tracking Illumina sequencing runs at the institute and
processing sequencing data.

The ability to infer two of these values given a third one relies on run folder
name following a certain string pattern. If access to a run tracking database
is available and the database contains relevant records, any non-empty string
can be used as a run folder name. Access to a run tracking database is made via
the npg_tracking_schema attribute, which can be provided by a class which
consumes this role.

See npg_tracking::illumina::run::folder for an example implementation of the
npg_tracking_schema attribute.

If your class consumes this role, you need either to provide the run_folder
attribute value on construction or implement a _build_run_folder method in your
class. Failure to do this WILL cause a run-time error along the lines of

  Mypackage does not support builder method '_build_run_folder' for attribute 'run_folder'

=head1 SUBROUTINES/METHODS

=head2 id_run

An attribute, can be set in the constructor or lazy-built assuming that the
run_folder attribute value is available or can be built.

  my $oPackage = Mypackage->new(id_run => $id_run);
  my $iIdRun = $oPackage->id_run();

=head2 name

An attribute, can be set in the constructor. It can also be lazy-built assuming
that id_run or run_folder was provided attribute value is available.
The ability to build this attribute without database support is not guaranteed.

  my $oPackage = Mypackage->new(name => $name);
  my $sName = $oPackage->name();

=head2 run_folder

An attribute, can be set in the constructor or lazy-built. A class consuming
this role should provide a _build_run_folder method. Failure to provide a builder
will cause a run-time error. Constrained to not contain file-system path -
anything which looks like such a path will be coerced to the last component of the path.

  my $oPackage = Mypackage->new(run_folder => $run_folder);
  my $sRunFolder = $oPackage->run_folder();

=head2 short_reference

A method. Returns the first it finds from run_folder, id_run, name.

  my $ShortReference = $oPackage->short_reference();

No guarantee that this method is going to be supported in future releases.
Deriving classes should not use it.

=head2 instrument_string

An attribute, the name of the instrument, will be lazy-built,
usually no need to set it via a constructor.

  my $sInstrumentString = $oPackage->instrument_string();

=head2 slot

An attribute, the name of the instrument slot, will be lazy-built,
usually no need to set it via a constructor.

  my $slot = $oPackage->slot();

=head2 flowcell_id

An attribute, will be lazy-built, usually no need to set it
via a constructor.
If the machine is a HiSeq, the flowcell id that was used.
If the machine is a MiSeq, the reagent kit id that was used.

  my $fid = $oPackage->flowcell_id();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Moose::Util::TypeConstraints

=item File::Spec::Functions

=item Carp

=item Try::Tiny

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Andy Brown

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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

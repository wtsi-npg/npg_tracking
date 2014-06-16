#############
# Created By: ajb
# Created On: 2009-09-30

package npg_tracking::illumina::run::short_info;
use Moose::Role;
use Moose::Util::TypeConstraints;
use File::Spec::Functions qw(splitdir);
use Carp;
use English qw{-no_match_vars};
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $INSTRUMENT_PATTERN => '(IL|HS|HX|MS)';
Readonly::Scalar our $NAME_PATTERN => $INSTRUMENT_PATTERN.'(\d+_)0*(\d+)';
Readonly::Scalar our $LONG_FOLDER_NAME_SUFFIX_PATTERN => '_(A|B)_?([0-9A-Z]{9}(?:-\d{5})?)';

# requires q{_build_run_folder}; Functionality not working in Moose

###############
# public methods

has q{id_run}            => ( isa => q{Int}, is => q{ro}, lazy_build => 1, writer => q{_set_id_run},
                            documentation => 'Integer identifier for a sequencing run, (typically a suffix of the name and run_folder)',);
has q{name}              => ( isa => q{Str}, is => q{ro}, lazy_build => 1,
                            documentation => 'String identifier for a sequencing run, (typically containing a machine identifer and the id_run, being a suffix of the run_folder, and forming the prefix of the cluster identifier in final output sequence files)',);

has q{instrument_string} => ( isa => q{Str}, is => q{ro}, lazy_build => 1,
                            documentation => q{String of the instrument name, worked out from the run name}, );

has q{slot}              => (
  isa => q{Str},
  is  => q{ro},
  lazy_build => 1,
  documentation => q{If the machine is a HS, the slot that is used for the flowcell (or A for a MS)},
  writer => q{_set_slot},
);

has q{flowcell_id}       => (
  isa => q{Str},
  is  => q{ro},
  lazy_build => 1,
  documentation => q{If the machine is a HS, the flowcell id that was used. If the machine is a MS, the reagent kit id that was used.},
  writer => q{_set_flowcell_id},
);

subtype __PACKAGE__.q(::folder)
  => as 'Str'
  => where {splitdir($_)==1};
coerce __PACKAGE__.q(::folder)
  => from 'Str'
  => via {first {$_ ne q()} reverse splitdir($_)};
has q{run_folder}      => ( isa => __PACKAGE__.q(::folder), is => q{ro}, lazy_build => 1,
                            documentation => 'Folder name used for the directory containing the information produced by the sequencing machine, (does not contain any path to the folder)',);

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
# builders



sub _build_id_run {
  my ($self) = @_;
  if ( !( $self->has_run_folder() || $self->has_name() ) ) {
      eval {
        $self->name();
      } or do {
        croak qq{Unable to obtain id_run from name : $EVAL_ERROR};
      };
  }

  my ($inst_t, $inst_i, $id_run) = $self->name() =~ /$NAME_PATTERN/gmsx;

  return $id_run;
}

sub _build_name {
  my ($self) = @_;
  if( !( $self->has_id_run() || $self->has_run_folder() ) ) {
    eval {
      $self->run_folder();
    } or do {
        croak qq{Unable to obtain name from run_folder : $EVAL_ERROR};
    };
  }
  my ($start, $middle, $end) = $self->run_folder() =~ /$NAME_PATTERN/xms;
  croak 'Unrecognised format for run folder name: ' . $self->run_folder()
    if !( $start && $middle && $end );

  return $start.$middle.$end;
}

sub _build_instrument_string {
  my ( $self ) = @_;
  my $name = $self->name();

  my ( $start, $end ) = $name =~ /$INSTRUMENT_PATTERN(\d+)/xms;

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

  $self->_set_slot( q{} );
  $self->_set_flowcell_id( q{} );

  my $run_folder = $self->run_folder();

  my @parts = $run_folder =~ m/${NAME_PATTERN}$LONG_FOLDER_NAME_SUFFIX_PATTERN/xms;

  my $flowcell_id = pop @parts;
  my $slot = pop @parts;
  if(defined $slot){ $self->_set_slot( $slot );}
  if(defined $flowcell_id){ $self->_set_flowcell_id( $flowcell_id );}
  return 1;
}


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

This role provides 4 methods for your Moose class object, id_run, name, run_folder and short_reference.

You need to either always provide run_folder on construction, or provide a _build_run_folder method in your class.
Failure to do this WILL cause a run_time error. The error will be along the lines of

  Mypackage does not support builder method '_build_run_folder' for attribute 'run_folder'

It is probably worth wrapping calls in an eval block to trap any croaks which will happen should information
be needed to work out something not provided be missing, or that there may be multiple paths to a run_folder
discovered.

=head1 SUBROUTINES/METHODS

=head2 id_run - can be set in the constructor, or called assuming that name or run_folder was provided

  my $oPackage = Mypackage->new({
    id_run => $id_run, # 1234
  });

  my $iIdRun = $oPackage->id_run();

=head2 name - can be set in the constructor, or called assuming that id_run or run_folder was provided

  my $oPackage = Mypackage->new({
    name => $name, # ILx_1234
  });

  my $sName = $oPackage->name();

=head2 run_folder - can be set in the constructor, or else you need to provide a _build_run_folder method. Failure to provide these WILL cause a run-time error
Constrained to not contain file-system path - anything which looks like such a path will be coerced to the last component of the path.

  my $oPackage = Mypackage->new({
    run_folder => $run_folder, # 123456_ILx_1234
  });

  my $sRunFolder = $oPackage->run_folder();

=head2 short_reference - returns the first it finds from run_folder, id_run, name

  my $ShortReference = $oPackage->short_reference();

=head2 instrument_string

returns the name of the instrument found

  my $sInstrumentString = Mypackage->instrument_string();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item English -no_match_vars

=item Readonly

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andy Brown

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 GRL by Andy Brown (ajb@sanger.ac.uk)

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

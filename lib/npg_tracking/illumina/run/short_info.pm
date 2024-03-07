package npg_tracking::illumina::run::short_info;

use Moose::Role;
use Moose::Util::TypeConstraints;
use File::Spec::Functions qw(splitdir);
use Carp;
use Try::Tiny;
use Readonly;

use npg_tracking::util::types;

our $VERSION = '0';

has q{id_run}           => (
  isa           => q{NpgTrackingRunId},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
  documentation => 'Integer identifier for a sequencing run',
);

my $run_folder_subtype_name = __PACKAGE__.q(::folder);
subtype $run_folder_subtype_name
  => as 'Str'
  => where { splitdir($_)==1 };

has q{run_folder}        => (
  isa           => $run_folder_subtype_name,
  is            => q{ro},
  lazy_build    => 1,
  documentation => 'Directory name of the run folder',
);

sub _build_id_run {
  my ($self) = @_;

  my $id_run;

  if ($self->can(q(npg_tracking_schema)) and  $self->npg_tracking_schema()) {
    if (!$self->has_run_folder()) {
      $self->run_folder(); # Force the build
    }
    my $rs = $self->npg_tracking_schema()->resultset('Run')
             ->search({folder_name => $self->run_folder()});
    if ($rs->count == 1) {
      $id_run = $rs->next()->id_run();
    }
  }

  # When no id_run is set, attempt to parse an id_run from the experiment name
  # recorded in the Illumina XML file.
  # We embed additional information in NovaSeqX samplesheets which have no
  # meaning here. See L<Samplesheet generator|npg::samplesheet::novaseq_xseries>
  if ( !$id_run && $self->can('experiment_name') && $self->experiment_name() ) {
    ($id_run, undef) = $self->experiment_name() =~ m{
      \A
      [\s]*
      ([\d]+)     # id_run
      ([\w\d\s]*) # instrument name or other embedded info
      \Z
    }xms;
  }

  if( !$id_run ) {
    croak q[Unable to identify id_run with data provided];
  }

  return $id_run;
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

=head1 SUBROUTINES/METHODS

=head2 id_run

NPG run identifier. If the value is not supplied, an attempt to build it is
made. 

If access to a run tracking database is available and the database contains
the run record and the run folder name is defined in the database record and
the run_folder attribute is defined or can be built, then its value is used
to retrieve the id_run value from the database.

Access to a run tracking database is made via the 'npg_tracking_schema'
attribute, which can be provided by a class which consumes this role. See
npg_tracking::illumina::run::folder for an example implementation of the
npg_tracking_schema attribute.

If 'experiment_name' accessor is provided by the class that inherits from
this role, then, in the absence of a database record, an attempt is made to parse
out run ID from the value returned by the 'experiment_name' accessor. See
npg_tracking::illumina::run::long_info for the implementation of this accessor.

=head2 run_folder

An attribute, can be set in the constructor or lazy-built. A class consuming
this role should provide a builder method '_build_run_folder'. Failure to
provide a builder might result in a run-time error. The attribute is constrained
to not contain a file-system path.

The implementation of the build method for this attribute should not try to
retrieve run record from the tracking database. 

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

Copyright (C) 2013,2014,2015,2016,2018,2023,2024 Genome Research Ltd.

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

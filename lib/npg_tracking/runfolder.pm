package npg_tracking::runfolder;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use File::Spec::Functions qw/catfile catdir/;
use Readonly;

use npg_tracking::elembio::runfolder;
use npg_tracking::illumina::runfolder;

our $VERSION = '0';

Readonly::Array my @RUNFOLDER_IMPLEMENTATIONS => (
  {
    class    => q{npg_tracking::elembio::runfolder},
    detector => \&_is_elembio_runfolder_path,
  },
  {
    class    => q{npg_tracking::illumina::runfolder},
    detector => \&_is_illumina_runfolder_path,
  },
);

Readonly::Array my @DELEGATED_METHODS => qw(
  expected_cycle_count
  manufacturer
  lane_count
  experiment_name
  instrument_name
  instrument_side
  workflow_type
  flowcell_id
  is_paired_read
  is_indexed
  is_dual_index
  index_length
  read_cycle_counts
  reads_indexed
  indexing_cycle_range
  read1_cycle_range
  read2_cycle_range
  index_read1_cycle_range
  index_read2_cycle_range
  platform_NovaSeq
  platform_NovaSeqX
  all_lanes_mergeable
);

=head1 NAME

npg_tracking::runfolder

=head1 SYNOPSIS

  my $rf = npg_tracking::runfolder->new(
    runfolder_path => '/path/to/runfolder'
  );

  my $paired = $rf->is_paired_read;

=head1 DESCRIPTION

A manufacturer-agnostic runfolder object. It provides the shared runfolder
path and staging behaviour, and delegates metadata parsing to a concrete
manufacturer-specific implementation.

=head1 SUBROUTINES/METHODS

=head2 manufacturer

Returns the manufacturer-specific runfolder implementation name.

=head2 runfolder_path_is_valid

Recognises either an Illumina or an Elembio runfolder root when inferring the
runfolder path from a subpath.

=cut

with 'npg_tracking::runfolder::folder';

has q{_delegate} => (
  isa        => q{Object},
  is         => q{ro},
  lazy_build => 1,
  init_arg   => undef,
  handles    => \@DELEGATED_METHODS,
);
sub _build__delegate {
  my $self = shift;

  my $runfolder_path = $self->runfolder_path;
  foreach my $implementation (@RUNFOLDER_IMPLEMENTATIONS) {
    if ($implementation->{detector}->($runfolder_path)) {
      my $class = $implementation->{class};
      return $class->new(runfolder_path => $runfolder_path);
    }
  }

  croak qq{No manufacturer-specific runfolder implementation matched $runfolder_path};
}

sub runfolder_path_is_valid {
  my ($self, $path) = @_;

  if (!-d $path) {
    return 0;
  }

  return 1 if -d catdir($path, q{Data});
  return 1 if -f catfile($path, q{RunParameters.json});

  return 0;
}

sub _is_elembio_runfolder_path {
  my ($path) = @_;
  return -f catfile($path, q{RunParameters.json});
}

sub _is_illumina_runfolder_path {
  my ($path) = @_;
  return (
    -d catdir($path, q{Data}) ||
    -f catfile($path, q{RunInfo.xml}) ||
    -f catfile($path, q{runParameters.xml}) ||
    -f catfile($path, q{RunParameters.xml})
  ) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 AUTHOR

Genome Research Ltd.

=head1 BUGS AND LIMITATIONS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Genome Research Ltd.

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify it under the terms
of the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

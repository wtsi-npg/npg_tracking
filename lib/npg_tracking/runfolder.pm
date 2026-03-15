package npg_tracking::runfolder;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Carp;
use File::Spec::Functions qw/splitdir catfile catdir/;

use npg_tracking::elembio::runfolder;

our $VERSION = '0';

=head1 NAME

npg_tracking::runfolder

=head1 SYNOPSIS

  my $rf = npg_tracking::runfolder->new(
    runfolder_path => '/path/to/runfolder'
  );

  my $paired = $rf->is_paired_read;

=head1 DESCRIPTION

A generic runfolder wrapper for NPG tracking. It preserves the existing
Illumina behaviour from C<npg_tracking::illumina::runfolder> and delegates to
C<npg_tracking::elembio::runfolder> when an Elembio C<RunParameters.json> is
present.

=head1 SUBROUTINES/METHODS

=head2 expected_cycle_count

Returns the expected cycle count for the run.

=head2 manufacturer

Returns the manufacturer name for the runfolder.

=head2 lane_count

Returns the number of lanes for the run.

=head2 is_paired_read

Returns true when the run is paired-end.

=head2 is_indexed

Returns true when the run includes at least one index read.

=head2 is_dual_index

Returns true when the run includes a second index read.

=head2 index_length

Returns the total index length.

=head2 read_cycle_counts

Returns cycle counts for reads in sequencing order.

=head2 reads_indexed

Returns flags indicating which reads are index reads.

=head2 indexing_cycle_range

Returns the cycle range for all index reads.

=head2 read1_cycle_range

Returns the cycle range for read 1.

=head2 read2_cycle_range

Returns the cycle range for read 2, if present.

=head2 index_read1_cycle_range

Returns the cycle range for index read 1, if present.

=head2 index_read2_cycle_range

Returns the cycle range for index read 2, if present.

=cut

extends 'npg_tracking::illumina::runfolder';

has q{_elembio_runfolder} => (
  isa        => q{Maybe[npg_tracking::elembio::runfolder]},
  is         => q{ro},
  lazy_build => 1,
  init_arg   => undef,
);
sub _build__elembio_runfolder {
  my $self = shift;

  my $runfolder_path = $self->runfolder_path;
  my $runparams_path = catfile($runfolder_path, q{RunParameters.json});
  return if !-f $runparams_path;

  return npg_tracking::elembio::runfolder->new(
    runfolder_path => $runfolder_path
  );
}

sub _build_runfolder_path {
  my ($self) = @_;

  my $path;
  my $runfolder_name = $self->has_run_folder ? $self->run_folder : undef;

  if ($self->subpath()) {
    $path = _get_path_from_given_path($self->subpath());
  }

  if ((not $path) and $self->npg_tracking_schema()) {
    if (not $self->tracking_run->is_tag_set(q(staging))) {
      croak sprintf 'NPG tracking reports run %i no longer on staging',
        $self->id_run;
    }
    my $db_runfolder_name = $self->tracking_run->folder_name;
    if ($db_runfolder_name) {
      if ($runfolder_name and ($db_runfolder_name ne $runfolder_name)) {
        carp sprintf 'Inconsistent db and given run folder name: %s, %s',
          $db_runfolder_name, $runfolder_name;
      }
      if (my $gpath = $self->tracking_run->folder_path_glob) {
        $path = $self->_get_path_from_glob_pattern(
          catfile($gpath, $db_runfolder_name)
        );
      }
    }
  }

  if ((not $path) and $runfolder_name) {
    $path = $self->_get_path_from_glob_pattern(
      $self->_folder_path_glob_pattern() . $runfolder_name
    );
  }

  $path or croak 'Failed to infer runfolder_path';

  return $path;
}

sub _runfolder_delegate {
  my ($self, $orig, $method, @args) = @_;
  my $elembio = $self->_elembio_runfolder;
  return $elembio->$method(@args) if $elembio;
  return $self->$orig(@args);
}

around q{expected_cycle_count} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{expected_cycle_count});
};

sub manufacturer {
  my $self = shift;
  my $elembio = $self->_elembio_runfolder;
  return $elembio->manufacturer if $elembio;
  return q{Illumina};
}

around q{lane_count} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{lane_count});
};

around q{is_paired_read} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{is_paired_read});
};

around q{is_indexed} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{is_indexed});
};

around q{is_dual_index} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{is_dual_index});
};

around q{index_length} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{index_length});
};

around q{read_cycle_counts} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{read_cycle_counts});
};

around q{reads_indexed} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{reads_indexed});
};

around q{indexing_cycle_range} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{indexing_cycle_range});
};

around q{read1_cycle_range} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{read1_cycle_range});
};

around q{read2_cycle_range} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{read2_cycle_range});
};

around q{index_read1_cycle_range} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{index_read1_cycle_range});
};

around q{index_read2_cycle_range} => sub {
  my ($orig, $self) = @_;
  return $self->_runfolder_delegate($orig, q{index_read2_cycle_range});
};

sub _get_path_from_given_path {
  my ($subpath) = @_;

  my @dirs = splitdir($subpath);
  while (@dirs) {
    my $path = catdir(@dirs);
    if (
      -d $path and
      (
        -d catdir($path, q{Data}) ||
        -f catfile($path, q{RunParameters.json})
      )
    ) {
      return $path;
    }
    pop @dirs;
  }

  croak qq{Nothing looks like a run folder in any subpath of $subpath};
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

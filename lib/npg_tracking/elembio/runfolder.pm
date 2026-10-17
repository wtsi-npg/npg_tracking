package npg_tracking::elembio::runfolder;

use Moose;
use namespace::autoclean;
use Readonly;
use File::Basename qw/basename/;

extends 'Monitor::Elembio::RunParametersParser';

our $VERSION = '0';

Readonly::Hash my %READ_NAME_TO_RANGE => (
  q{R1} => q{read1_cycle_range},
  q{R2} => q{read2_cycle_range},
  q{I1} => q{index_read1_cycle_range},
  q{I2} => q{index_read2_cycle_range},
);

=head1 NAME

npg_tracking::elembio::runfolder

=head1 SYNOPSIS

  my $rf = npg_tracking::elembio::runfolder->new(
    runfolder_path => '/path/to/elembio/runfolder'
  );

  my @cycle_counts = $rf->read_cycle_counts;

=head1 DESCRIPTION

An Elembio runfolder metadata object. It extends
C<Monitor::Elembio::RunParametersParser> and exposes a runfolder API matching
the subset of the Illumina runfolder interface that downstream code uses.

=head1 SUBROUTINES/METHODS

=head2 run_folder

Returns the on-disk Elembio run folder name.

=head2 metadata_folder_name

Returns the run folder name recorded in C<RunParameters.json>.

=head2 manufacturer

Returns the manufacturer name for Elembio runfolders.

=head2 is_paired_read

Returns true when a reverse read is present.

=head2 is_dual_index

Returns true when a second index read is present.

=head2 is_i5opposite

Returns true for dual-index Elembio runs, where observed data as of March 2026 indicates the i5 index should be treated as opposite-orientation. bases2fastq also infers index-read orientation from supplied tag sets during deplexing.

=head2 index_length

Returns the combined index length.

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

has q{_read_structure} => (
  isa        => q{HashRef},
  is         => q{ro},
  lazy_build => 1,
  init_arg   => undef,
);
sub _build__read_structure {
  my $self = shift;

  my $data = $self->_run_params_data;
  my $cycles = $data->{q{Cycles}} || {};
  my @order = grep { $_ ne q[] } split /,/smx, ($data->{q{ReadOrder}} || q[]);
  if (!@order) {
    @order = grep {
      exists $cycles->{$_} && int($cycles->{$_})
    } qw/R1 I1 I2 R2/;
  }

  my $read_structure = {
    read_cycle_counts       => [],
    reads_indexed           => [],
    indexing_cycle_range    => [],
    read1_cycle_range       => [],
    read2_cycle_range       => [],
    index_read1_cycle_range => [],
    index_read2_cycle_range => [],
  };

  my $first_cycle = 1;
  foreach my $read_name (@order) {
    my $cycle_count = exists $cycles->{$read_name} ? int($cycles->{$read_name}) : 0;
    next if !$cycle_count;

    my $last_cycle = $first_cycle + $cycle_count - 1;
    push @{$read_structure->{read_cycle_counts}}, $cycle_count;
    push @{$read_structure->{reads_indexed}},
      ($read_name =~ /\AI\d+\Z/smx) ? 1 : 0;

    if (exists $READ_NAME_TO_RANGE{$read_name}) {
      @{$read_structure->{$READ_NAME_TO_RANGE{$read_name}}} =
        ($first_cycle, $last_cycle);
    }

    if ($read_name =~ /\AI\d+\Z/smx) {
      if (!@{$read_structure->{indexing_cycle_range}}) {
        @{$read_structure->{indexing_cycle_range}} = ($first_cycle, $last_cycle);
      } else {
        $read_structure->{indexing_cycle_range}->[1] = $last_cycle;
      }
    }

    $first_cycle = $last_cycle + 1;
  }

  return $read_structure;
}

sub run_folder {
  my $self = shift;
  return basename $self->runfolder_path;
}

sub metadata_folder_name {
  my $self = shift;
  return $self->folder_name;
}

sub manufacturer {
  return q{Element Biosciences};
}

sub is_paired_read {
  my $self = shift;
  return $self->read2_cycle_range ? 1 : 0;
}

sub is_dual_index {
  my $self = shift;
  return $self->index_read2_cycle_range ? 1 : 0;
}

sub is_i5opposite {
  my $self = shift;
  # Empirically, dual-index Elembio runs have used opposite-orientation i5
  # over several months of observed data as of March 2026.
  # N.b. bases2fastq infers index-read orientation from the supplied tag
  # sets when deplexing so the manufacturer process is fairly robost to
  # getting this wrong - we may not exhibit such robustness to ill-defined
  # data if driving explicitly...
  return $self->is_dual_index ? 1 : 0;
}

sub index_length {
  my $self = shift;
  my ($start, $end) = $self->indexing_cycle_range;
  return ($start && $end) ? $end - $start + 1 : 0;
}

sub read_cycle_counts {
  my $self = shift;
  return @{$self->_read_structure->{read_cycle_counts}};
}

sub reads_indexed {
  my $self = shift;
  return @{$self->_read_structure->{reads_indexed}};
}

sub indexing_cycle_range {
  my $self = shift;
  return @{$self->_read_structure->{indexing_cycle_range}};
}

sub read1_cycle_range {
  my $self = shift;
  return @{$self->_read_structure->{read1_cycle_range}};
}

sub read2_cycle_range {
  my $self = shift;
  return @{$self->_read_structure->{read2_cycle_range}};
}

sub index_read1_cycle_range {
  my $self = shift;
  return @{$self->_read_structure->{index_read1_cycle_range}};
}

sub index_read2_cycle_range {
  my $self = shift;
  return @{$self->_read_structure->{index_read2_cycle_range}};
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

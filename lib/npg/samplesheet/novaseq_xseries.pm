package npg::samplesheet::novaseq_xseries;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use Carp;
use Text::CSV;
use List::MoreUtils qw(any none uniq);
use List::Util qw(first max);
use DateTime;
use Data::UUID;

use st::api::lims::samplesheet;

extends 'npg::samplesheet::base';
with    'MooseX::Getopt';

our $VERSION = '0';

Readonly::Scalar my $READ1_LENGTH => 151;
Readonly::Scalar my $READ2_LENGTH => 151;
Readonly::Scalar my $LIST_INDEX_TAG1  => 2;
Readonly::Scalar my $LIST_INDEX_TAG2  => 3;
Readonly::Scalar my $LIST_INDEX_REF   => 4;
Readonly::Scalar my $LIST_INDEX_LIBTYPE => 5;
Readonly::Array  my @RNA_ANALYSES_REFS => qw(tophat2 star hisat2);
Readonly::Array  my @RNA_ANALYSES_LIB_TYPES => qw(rna cdna);
Readonly::Array  my @TENX_ANALYSES_LIB_TYPES => qw(chromium haplotagging);
Readonly::Array  my @VAR_CALL_MODES   =>
  qw(None SmallVariantCaller AllVariantCallers);

Readonly::Hash my %REFERENCE_MAPING => (
  'Homo_sapiens' => 'hg38-alt_masked.cnv.graph.hla.rna-8-1667497097-2'
);

Readonly::Scalar my $DRAGEN_MAX_NUMBER_OF_CONFIGS => 4;
Readonly::Scalar my $END_OF_LINE => qq[\n];

=head1 NAME

npg::samplesheet::novaseq_xseries

=head1 SYNOPSIS

=head1 DESCRIPTION

Generation of a samplesheet that is used to configure a sequencing run on
the NovaSeq Series X instrument and the DRAGEN analysis of the data sequenced
on this instrument model.

The DRAGEN analysis can process a limited number of distinct analysis
configurations. The germline and RNA alignment sections of the generated
samplesheet will contain as many samples as possible within the limit set by
the C<dragen_max_number_of_configs> attribute. The default value for this
attribute is 4, which is the number of distinct configurations that the
on-board DRAGEN analysis can handle.

In the BCLConvert section, each combination of index lengths counts as a
unique configuration. If the number of these configurations exceeds the value
of the the C<dragen_max_number_of_configs> attribute, no DRAGEN analysis
sections are added to the samplesheet.

See specification in
L<https://support-docs.illumina.com/SHARE/SampleSheetv2/Content/SHARE/SampleSheetv2/Settings_fNV_mX.htm>

A full listing of analysis options is available in
L<https://support-docs.illumina.com/SW/DRAGEN_v41/Content/SW/DRAGEN/OptionReference.htm>

DRAGEN aligner info:
L<https://support-docs.illumina.com/SW/DRAGEN_v40/Content/SW/DRAGEN/GraphMapper_fDG.htm>

Prepare a reference:
L<https://support-docs.illumina.com/SW/DRAGEN_v41/Content/SW/DRAGEN/RefGenIntro.htm>
L<https://support-docs.illumina.com/SW/DRAGEN_v41/Content/SW/DRAGEN/RefGenPipe_fDG.htm>

Import a reference:
L<https://support-docs.illumina.com/IN/NovaSeqX/Content/IN/NovaSeqX/ImportResources.htm>

=head1 SUBROUTINES/METHODS

=cut

=head2 dragen_software_version

DRAGEN software version that is installed on the instrument where the run
is performed.

=cut

has 'dragen_software_version' => (
  'isa' => 'Str',
  'is'  => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
  'documentation' => 'DRAGEN software version',
);
sub _build_dragen_software_version {
  my $self = shift;

  if (!$self->has_id_run) {
    croak 'DRAGEN software version cannot be retrieved. ' .
      'Either supply it as an argument or supply existing id_run';
  }
  my $software_version =
    $self->run->instrument->latest_revision_for_modification('Dragen');
  if (!$software_version) {
    croak 'Failed to get DRAGEN software version from instrument records';
  }
  return $software_version;
};


has '+samplesheet_path' => (
  'documentation' => 'A directory where the samplesheet will be created, ' .
  'optional',
);


=head2 file_name

CSV file name to write the samplesheet data to.

=cut

has 'file_name' => (
  'isa'        => 'Str',
  'is'         => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
  'documentation' => 'CSV file name to write the samplesheet data to, ' .
                     'optional',
);
sub _build_file_name {
  my $self = shift;

  my $file_name;
  if ($self->has_id_run) {
    $file_name = join q[_],
      $self->run_name,
      q[ssbatch] . $self->batch_id;
  } else {
    $file_name = $self->run_name;
  }

  my $date = DateTime->now()->strftime('%y%m%d'); # 230602 for 2 June 2023
  $file_name = sprintf '%s_%s.csv', $date, $file_name;

  return $file_name;
}


=head2 output

A full path of the samplesheet file. If not supplied, is built using the
values of C<samplesheet_path> and C<file_name> attributes.

If the C<samplesheet_path> attribute is set to an empty string, the current
working directory is assumed.

Do not remove this attribute or change its name in order to be compliant with
the samplesheet daemon C<npg::samplesheet::auto>.

=cut

has 'output' => (
  'isa'        => 'Str',
  'is'         => 'ro',
  'lazy_build' => 1,
  'isa'        => 'Str',
  'documentation' => 'A path of the samplesheet file, optional',
);
sub _build_output {
  my $self = shift;

  my $dir = $self->samplesheet_path();
  my $path = $self->file_name;
  if ($dir) {
    $dir =~ s{[/]+\Z}{}xms; # Trim trailing slash if present.
    $path = join q[/], $dir, $path;
  }

  return $path;
}


has '+id_run' => (
  'documentation' => 'NPG run ID, optional; if supplied, the record for this '.
                     'run should exists in the run tracking database',
);


has '+batch_id' => (
  'documentation' => 'LIMS batch identifier, optional. If not set, will be ' .
                     'retrieved from the tracking database record for the run',
);

=head2 index_read_length

An array containing the length of the first and the second (if applicable)
indexing read.

If not set, is computed as the longest first and second barcode as reported
by the LIMS system.

=cut

has 'index_read_length' => (
  'isa'        => 'ArrayRef',
  'is'         => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
  'documentation' => 'An array containing the length of the first and the ' .
                     'second (if applicable) indexing read.',
);
sub _build_index_read_length {
  my $self = shift;
  my $index1_length = max (
    map { length $_->[$LIST_INDEX_TAG1] } $self->products
  );
  my $index2_length = max (
    map { length $_->[$LIST_INDEX_TAG2] } $self->products
  );
  return [$index1_length, $index2_length];
}


=head2 read_length

An array containing the length of the forward and the reverse read.
If not set, is currently hardcoded as [151, 151].

=cut

has 'read_length' => (
  'isa'        => 'ArrayRef',
  'is'         => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
  'documentation' => 'An array containing the length of the forward and ' .
                     'reverse read',
);
sub _build_read_length {
  return [$READ1_LENGTH, $READ2_LENGTH];
}


=head2 align

A boolean option, false by default; if set, the DRAGEN germline and/or
RNA analysis is added to the samplesheet if suitable samples are present.

=cut

has 'align' => (
  'isa'      => 'Bool',
  'is'       => 'ro',
  'required' => 0,
  'documentation' => 'A boolean option, false by default. If set, the DRAGEN '.
                     'germline analysis section is added to the file if ' .
                     'suitable samples are present.',
);


=head2 keep_fastq

A boolean option to keep FASTQ files for aligned data, false by default.

=cut

has 'keep_fastq' => (
  'isa'      => 'Bool',
  'is'       => 'ro',
  'required' => 0,
  'documentation' => 'An option to keep FASTQ files for aligned data, false ' .
                     'by default.',
);


=head2 varcall

Variant calling mode, defaults to C<None>, other valid options are
C<SmallVariantCaller> and C<AllVariantCallers>

=cut

has 'varcall' => (
  'isa'      => 'Str',
  'is'       => 'ro',
  'default'  => $VAR_CALL_MODES[0],
  'required' => 0,
  'documentation' => 'Variant calling mode, defaults to None, other valid ' .
                     'options are SmallVariantCaller and AllVariantCallers',
);


=head2 dragen_max_number_of_configs

=cut

has 'dragen_max_number_of_configs' => (
  'isa'      => 'NpgTrackingPositiveInt',
  'is'       => 'ro',
  'default'  => $DRAGEN_MAX_NUMBER_OF_CONFIGS,
  'required' => 0,
  'documentation' => 'DRAGEN analysis can deal with a limited number of ' .
                     'distinct configurations. Set this attribute if ' .
                     'processing not on-board',
);


=head2 run_name

=cut

has 'run_name' => (
  'isa'        => 'Str',
  'is'         => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
  'traits'     => [ 'NoGetopt' ],
);
sub _build_run_name {
  my $self = shift;

  my $run_name;
  if ($self->id_run()) {
    if ($self->run->instrument_format()->model() !~ /NovaSeqX/smx) {
      croak 'Instrument is not registered as NovaSeq X Series ' .
            'in the tracking database';
    }
    # Embed instrument's Sanger network name and slot
    $run_name = sprintf '%s_%s_%s', $self->id_run,
      $self->run->instrument->name, $self->get_instrument_side;
  } else {
    # Run is not tracked, generate a placeholder ID
    my $ug = Data::UUID->new();
    my @a = split /-/xms, $ug->to_string($ug->create());
    # Add a random string at the end so that the batch can be reused.
    $run_name = sprintf 'ssbatch%s_%s', $self->batch_id(), $a[0];
  }

  return $run_name;
}


=head2 products

A list of products as given by LIMS, a read-only accessor.

=cut

has '_products' => (
  'isa'        => 'ArrayRef',
  'traits'     => ['Array'],
  'is'         => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
  'handles'    => {
    'products' => 'elements',
  },
);
sub _build__products {
  my $self = shift;

  my @products = ();

  for my $lane (@{$self->lims}) {
    my $position = $lane->position;
    my @lane_products = $lane->is_pool ? $lane->children() : ($lane);
    for my $p (@lane_products) {
      push @products, [
        $position,
        $p->sample_name,
        $p->tag_sequences->[0] || q(),
        $p->tag_sequences->[1] || q(),
        $p->reference_genome() || q(),
        $p->library_type() || q()
      ];
    }
  }

  # Sort by sample name
  @products = sort { $a->[1] cmp $b->[1] } @products;

  return \@products;
}


=head2 process

Generates a samplesheet and saves it to a file.

Do not remove this method or change its name in order to stay compliant
with samplesheet daemon C<npg::samplesheet::auto>.

=cut

sub process {
  my $self = shift;

  $self->add_common_headers();
  $self->_add_line();
  my $num_samples = $self->add_bclconvert_section();
  carp "$num_samples samples are added to the BCLConvert section";

  if ($num_samples) {
    if ($self->align) {
      if ($self->_current_number_of_configs ==
          $self->dragen_max_number_of_configs) {
        carp sprintf 'Used max. number of analysis configurations, %i, ' .
          'will stop at BCLConvert', $self->dragen_max_number_of_configs;
      } else {
        $self->_add_line();
        $num_samples = $self->add_germline_section();
        carp "$num_samples samples are added to the Germline section";
        if ($num_samples) {
          $self->_add_line();
        }
        if ($self->_current_number_of_configs ==
            $self->dragen_max_number_of_configs) {
          carp sprintf 'Used max. number of analysis configurations, %i, ' .
            'will skip RNA section', $self->dragen_max_number_of_configs;
        } else {
          $num_samples = $self->add_rna_section();
          carp "$num_samples samples are added to the RNA section";
        }
      }
    }
  } else {
    carp 'Too many BCLConvert configurations, cannot run any DRAGEN analysis';
  }

  $self->_generate_output();

  return;
}

=head2 add_common_headers

Adds the top-level header section.

=cut

sub add_common_headers {
  my $self = shift;

  my ($index1_length, $index2_length) = @{$self->index_read_length()};
  $self->_add_line('[Header]');
  $self->_add_line(q[FileFormatVersion], 2);
  $self->_add_line(q[RunName], $self->run_name);
  $self->_add_line(qw(InstrumentPlatform NovaSeqXSeries));
  $self->_add_line(qw(InstrumentType NovaSeqXPlus));
  $self->_add_line();

  # Reads section
  $self->_add_line('[Reads]');
  $self->_add_line(q[Read1Cycles], $self->read_length()->[0]);
  $self->_add_line(q[Read2Cycles], $self->read_length()->[1]);
  if ($index1_length) {
    $self->_add_line('Index1Cycles', $index1_length);
    if ($index2_length) {
      $self->_add_line('Index2Cycles', $index2_length);
    }
  }

  $self->_add_line();
  $self->_add_line('[Sequencing_Settings]');

  return;
}


=head2 add_bclconvert_section

Adds BCLConvert_Settings and BCLConvert_Data sections.

Returns the number of samples added to the section or zero if the section
has not been added. The latter happens if the number of unique configurations
for BCLConvert exceeds the maximum number of allowed configurations.
In this case no further analysis sections should be added to the samplesheet.

The OverrideCycles column specifies the sequencing and indexing cycles to be
used when processing the sequencing data. Must adhere to the following
requirements:

- Must be same number of fields (delimited by semicolon) as sequencing and
  indexing reads specified in RunInfo.xml or 'Reads' section.

- Indexing reads are specified with 'I',
  sequencing reads are specified with 'Y',
  UMI cycles are specified with 'U',
  and trimmed reads are specified with 'N'.

- The number of cycles specified for each read must equal the number of cycles
  specified for that read in the RunInfo.xml file.

- Only one 'Y' or 'I' sequence can be specified per read.

=cut

sub add_bclconvert_section {
  my $self = shift;

  my ($index1_length, $index2_length) = @{$self->index_read_length()};
  my @lines = ();
  push @lines, ['[BCLConvert_Settings]'];
  push @lines, [q[SoftwareVersion], $self->dragen_software_version];
  push @lines, [qw(FastqCompressionFormat gzip)];
  push @lines, [];
  push @lines, ['[BCLConvert_Data]'];

  my @data_header = qw(Lane Sample_ID);
  if ($index1_length) {
    push @data_header, q[Index];
    if ($index2_length) {
      push @data_header, q[Index2];
    }
    push @data_header, q[OverrideCycles];
  }
  push @lines, \@data_header;

  my $index_override = sub {
    my ($max_length, $barcode) = @_;
    my $i_cycles_number = length $barcode;
    my $n_cycles_number = $max_length - $i_cycles_number;
    my $expression = q[];
    if ($i_cycles_number) {
      $expression .= q[I] . $i_cycles_number;
    }
    if ($n_cycles_number) {
      $expression .= q[N] . $n_cycles_number;
    }
    return $expression;
  };

  my $distinct_configs = {};
  for my $product ( $self->products() ) {

    my @product_data = ($product->[0], $product->[1]);

    my @override_cycles = ();
    # Not accounting for UMI cycles for now.
    if ($index1_length) {
      my $i7 = $product->[$LIST_INDEX_TAG1];
      push @product_data, $i7;
      push @override_cycles, q[Y] . $self->read_length()->[0];
      push @override_cycles,
        $index_override->($index1_length, $i7);
      if ($index2_length) {
        my $i5 = $product->[$LIST_INDEX_TAG2];
        push @product_data, $i5;
        push @override_cycles,
          $index_override->($index2_length, $i5);
      }
      push @override_cycles, q[Y] . $self->read_length()->[1];
    }
    my $override_cycles_string = join q[;], @override_cycles;
    # Might be an empty string ...
    my $config = $override_cycles_string;
    $config ||= 'no_deplex';
    if ($self->_can_add_sample($distinct_configs, $config)) {
      if (@override_cycles) {
        push @product_data, $override_cycles_string;
      }
      push @lines, \@product_data;
    } else {
      @lines = ();
      last;
    }
  }

  for my $line (@lines) {
    $self->_add_line(@{$line});
  }

  return scalar @lines;
}


=head2 add_germline_section

Conditionally adds the DragenGermline_Settings and DragenGermline_Data
sections.

=cut

sub add_germline_section {
  my $self = shift;

  if (none { $self->varcall eq $_ } @VAR_CALL_MODES) {
    croak 'Uknown mode for variang calling - ' . $self->varcall;
  }

  my @to_align = ();
  my @ref_matches = keys %REFERENCE_MAPING;
  my $distinct_configs = {};

  foreach my $p ( $self->products() ) {

    my $r = $p->[$LIST_INDEX_REF];
    my $lib_type = $p->[$LIST_INDEX_LIBTYPE];

    if ( can_do_alignment($r) && !(do_ref_rna_alignment_test($r) ||
           do_libtype_rna_alignment_test($lib_type) ||
           do_libtype_tenx_test($lib_type)) ) {

      my $match = first { $r =~ /$_/xms} @ref_matches;
      if ($self->_can_add_sample($distinct_configs, $match)) {
        # TODO Are all variant calling modes compatible with all
        # references?
        push @to_align, [$p->[1], $REFERENCE_MAPING{$match}, $self->varcall];
      }
    }
  }

  if (@to_align) {

    $self->_add_line('[DragenGermline_Settings]');
    $self->_add_line(q[SoftwareVersion], $self->dragen_software_version);
    $self->_add_line(qw(MapAlignOutFormat cram));
    # Accepted values are true or false. Not clear whether this can be
    # set per sample.
    $self->_add_line(q(KeepFastq), $self->keep_fastq ? 'TRUE' : 'FALSE');
    $self->_add_line();

    $self->_add_line(qw([DragenGermline_Data]));
    $self->_add_line(qw(Sample_ID ReferenceGenomeDir VariantCallingMode));
    $self->_add_samples(@to_align);
  }

  return scalar @to_align;
}


=head2 add_rna_section

Conditionally adds the DragenRNA_Settings and DragenRNA_Data sections.

=cut

sub add_rna_section {
  my $self = shift;

  my @to_align = ();
  my @ref_matches = keys %REFERENCE_MAPING;
  my $distinct_configs = {};

  foreach my $p ( $self->products() ) {

    my $r = $p->[$LIST_INDEX_REF];
    my $lib_type = $p->[$LIST_INDEX_LIBTYPE];

    if ( can_do_alignment($r) && (
           do_ref_rna_alignment_test($r) ||
           do_libtype_rna_alignment_test($lib_type)) ) {

      my $match = first { $r =~ /$_/xms} @ref_matches;
      if ($self->_can_add_sample($distinct_configs, $match)) {
        push @to_align, [$p->[1], $REFERENCE_MAPING{$match}];
      }
    }
  }

  if (@to_align) {
    $self->_add_line('[DragenRNA_Settings]');
    $self->_add_line(q(SoftwareVersion), $self->dragen_software_version);
    $self->_add_line(qw(MapAlignOutFormat cram));
    $self->_add_line(q(KeepFastq), $self->keep_fastq ? 'TRUE' : 'FALSE');
    $self->_add_line(qw(RnaPipelineMode FullPipeline));
    $self->_add_line();

    $self->_add_line('[DragenRNA_Data]');
    $self->_add_line(qw(Sample_ID ReferenceGenomeDir));
    $self->_add_samples(@to_align);
  }

  return scalar @to_align;
}


=head2 can_do_alignment

=cut

sub can_do_alignment {
  my $r = shift;
  return $r && !($r =~ /Not suitable/xmsi);
}


=head2 do_ref_rna_alignment_test

=cut

sub do_ref_rna_alignment_test {
  my $r = shift;
  return any { $r =~ /$_/xmsi } @RNA_ANALYSES_REFS;
}


=head2 do_libtype_rna_alignment_test

=cut

sub do_libtype_rna_alignment_test {
  my $lt = shift;
  return any { $lt =~ /$_/xmsi } @RNA_ANALYSES_LIB_TYPES;
}


=head2 do_libtype_tenx_test

=cut

sub do_libtype_tenx_test {
  my $lt = shift;
  return any { $lt =~ /$_/xmsi } @TENX_ANALYSES_LIB_TYPES;
}


=head2 get_instrument_side

Consult run tags to determine which slot/side of the instrument this run is
intended to be inserted into. Croaks when no value has been set.

=cut

sub get_instrument_side {
  my $self = shift;
  my $side = $self->run->is_tag_set('fc_slotA') ? 'A' :
            ($self->run->is_tag_set('fc_slotB') ? 'B' : q[]);
  if (! $side) {
    croak 'Slot is not set for run ' . $self->id_run;
  }
  return $side;
}

##################################################################
#  Private attributes and methods                                #
##################################################################

# A writable counter.
has '_current_number_of_configs' => (
  'isa'      => 'Int',
  'is'       => 'rw',
  'default'  => 0,
  'required' => 0,
);


has '_all_lines' => (
  'isa'        => 'ArrayRef',
  'is'         => 'ro',
  'default'    => sub { return []; } ,
  'required'   => 0,
);


sub _add_line {
  my ($self, @columns) = @_;
  push @{$self->_all_lines()}, @columns ? \@columns : [];
  return;
}

sub _add_samples {
  my ($self, @samples) = @_;

  my $done = {};
  foreach my $sample (@samples) {
    if (!$done->{$sample->[0]}) {
      $self->_add_line(@{$sample});
      $done->{$sample->[0]} = 1;
    }
  }

  return;
}


sub _can_add_sample {
  my ($self, $distinct_configs, $config) = @_;

  $config or return;

  # An existing configuration can always be added.
  if (!$distinct_configs->{$config}) { # This is a new configuration.
    if ($self->_current_number_of_configs < $self->dragen_max_number_of_configs) {
      # Add to the dictionary of distinct configs.
      $distinct_configs->{$config} = 1;
      # Increment the global count of distinct contigs.
      $self->_current_number_of_configs($self->_current_number_of_configs + 1);
    } else {
      return;
    }
  }

  return 1;
}


sub _generate_output {
  my $self = shift;

  my $csv = Text::CSV->new({
    eol => $END_OF_LINE,
    sep_char => $st::api::lims::samplesheet::SAMPLESHEET_RECORD_SEPARATOR
  });

  my $max_num_columns = max map { scalar @{$_} } @{$self->_all_lines};

  my $file_path = $self->output;
  ## no critic (InputOutput::RequireBriefOpen)
  open my $fh, q[>], $file_path
    or croak "Failed to open $file_path for writing";

  for my $line (@{$self->_all_lines}) {
    my @columns = @{$line};
    # Pad the row.
    while (scalar @columns < $max_num_columns) {
      push @columns, q[];
    }
    $csv->print($fh, \@columns);
  }

  close $fh or carp "Problems closing $file_path";
  ## use critic

  return;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item MooseX::Getopt

=item namespace::autoclean

=item Carp

=item Text::CSV

=item Readonly

=item List::MoreUtils

=item List::Util

=item DateTime

=item Data::UUID

=back

=head1 BUGS AND LIMITATIONS

=head1 INCOMPATIBILITIES

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2023 Genome Research Ltd.

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

=cut

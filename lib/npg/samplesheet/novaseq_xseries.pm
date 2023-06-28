package npg::samplesheet::novaseq_xseries;

use Moose;
use MooseX::StrictConstructor;
use namespace::autoclean;
use Readonly;
use Carp;
use Text::CSV;
use List::MoreUtils qw(any none uniq);
use List::Util qw(first max);
use Getopt::Long;
use Pod::Usage;
use DateTime;
use Data::UUID;

use st::api::lims;
use npg_tracking::Schema;
use npg_tracking::util::types;
use WTSI::DNAP::Warehouse::Schema;

with qw / MooseX::Getopt
          npg_tracking::glossary::run /;

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

# Not mapping PhiX on purpose - an easy way to avoid invoking
# an extra Germline pipeline in a situation when the number of
# unique analysis configurations is limited to 4 locally and 8
# in the cloud, with one of them being BCLConvert.
# Was 'PhiX' => 'phix-rna-8-1667499364-2'
Readonly::Hash my %REFERENCE_MAPING => (
    'Homo_sapiens'=> 'hg38-alt_masked.cnv.graph.hla.rna-8-1667497097-2',
    'Escherichia_coli' => 'eschColi_K12_1-rna-8-1667494624-2',
);

# The version of the software currently onboard.
Readonly::Scalar my $SOFTWARE_VERSION => '4.1.7';

# DRAGEN can process a limited number of distinct configurations.
# For on-board analysis it's 4.
Readonly::Scalar my $DRAGEN_MAX_NUMBER_OF_CONFIGS => 4;

=head1 NAME

npg::samplesheet::novaseq_xseries

=head1 SYNOPSIS

=head1 DESCRIPTION

Samplesheet generation to initiate DRAGEN analysis of the data sequenced on
the NovaSeq Series X instrument.

The DRAGEN analysis can process a limited number of distinct analysis
configurations. The germline and RNA alignment sections of the generated
samplesheet will contain as many samples as possible within the limit set by 
the C<dragen_max_number_of_configs> attribute. The default value for this
attribute is 4, which is the number of distinct configurations that the
on-board DRAGEN analysis can handle.

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

=head2 id_run

NPG run ID, an optional attribute. If supplied, the record for this run
should exists in the run tracking database.

=cut

has '+id_run' => (
  'required'  => 0,
  'documentation' => 'NPG run ID, optional; if supplied, the record for this '.
                     'run should exists in the run tracking database',
);

=head2 batch_id

LIMS batch ID, an optional attribute. If not set, the C<id_run> attribute
should be set.

=cut

has 'batch_id' => (
  'isa' => 'Str|Int',
  'is'  => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
  'documentation' => 'LIMS batch identifier, optional. If not set, will be ' .
                     'retrieved from the trackign database record for the run',
);
sub _build_batch_id {
  my $self = shift;
  if (!$self->has_id_run) {
    croak 'Run ID is not supplied, cannot get LIMS batch ID';
  }
  my $batch_id = $self->run()->batch_id();
  if (!defined $batch_id) {
    croak 'Batch ID is not set in the database record for run ' . $self->id_run;
  }

  return $batch_id;
}

=head2 align

A boolean option, false by default; if set, the DRAGEN germline iand/or
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

has '_current_number_of_configs' => (
  'isa'      => 'Int',
  'is'       => 'rw',
  'default'  => 0,
  'required' => 0,
);

=head2 npg_tracking_schema

DBIx Schema object for the tracking database.

=cut

has 'npg_tracking_schema' => (
  'isa'        => 'npg_tracking::Schema',
  'is'         => 'ro',
  'lazy_build' => 1,
  'traits'     => [ 'NoGetopt' ],
);
sub _build_npg_tracking_schema {
  return npg_tracking::Schema->connect();
}

=head2 mlwh_schema

DBIx Schema object for the mlwh database.

=cut

has 'mlwh_schema' => (
  'isa'        => 'WTSI::DNAP::Warehouse::Schema',
  'is'         => 'ro',
  'lazy_build' => 1,
  'traits'     => [ 'NoGetopt' ],
);
sub _build_mlwh_schema {
  return WTSI::DNAP::Warehouse::Schema->connect();
}

=head2 run

DBIx object for a row in the run table of the tracking database.

=cut

has 'run' => (
  'isa'        => 'npg_tracking::Schema::Result::Run',
  'is'         => 'ro',
  'predicate'  => 'has_tracking_run',
  'lazy_build' => 1,
  'traits'     => [ 'NoGetopt' ],
);
sub _build_run {
  my $self=shift;

  if (!$self->has_id_run) {
    croak 'Run ID is not supplied, cannot retrieve run database record';
  }
  my $run = $self->npg_tracking_schema->resultset(q(Run))->find($self->id_run);
  if (!$run) {
    croak 'The database record for run ' . $self->id_run  . ' does not exist';
  }
  if ($run->instrument_format()->model() !~ /NovaSeqX/smx) {
    croak 'Instrument model is not NovaSeq X Series';
  }

  return $run;
}

=head2 lims

An attribute, an array of C<st::api::lims> type objects.

If the attribute is not provided, it is built automatically.
c<ml_warehouse st::api::lims> driver is used to access LIMS data.

=cut

has 'lims' => (
  'isa'        => 'ArrayRef[st::api::lims]',
  'is'         => 'ro',
  'lazy_build' => 1,
  'traits'     => [ 'NoGetopt' ],
);
sub _build_lims {
  my $self=shift;
  return [st::api::lims->new(
            id_flowcell_lims => $self->batch_id,
            driver_type => q[ml_warehouse],
            mlwh_schema => $self->mlwh_schema
          )->children()];
}

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
  if ($self->has_id_run()) {
    $run_name = $self->id_run;
  } else {
    my $ug = Data::UUID->new();
    my @a = split /-/xms, $ug->to_string($ug->create());
    # Add a random string at the end so that the batch can be reused.
    $run_name = sprintf 'ssbatch%s_%s', $self->batch_id(), $a[0];
  }

  return $run_name;
}

=head2 file_name

=cut

has 'file_name' => (
  'isa'        => 'Str',
  'is'         => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
  'documentation' => 'CSV file name or path to write samplesheet data to',
);
sub _build_file_name {
  my $self = shift;

  my $file_name;
  if ($self->has_id_run) {
    my $side = $self->run->is_tag_set('fc_slotA') ? 'A' :
              ($self->run->is_tag_set('fc_slotB') ? 'B' : q[]);
    if (!$side) {
      croak 'Slot is not set for run ' . $self->id_run;
    }
    $file_name = join q[_],
      $self->run->instrument->name,
      $self->id_run,
      $side,
      q[ssbatch] . $self->batch_id;
  } else {
    $file_name = $self->run_name;
  }

  my $date =  DateTime->now()->strftime('%y%m%d'); # 230602 for 2 June 2023 
  $file_name = sprintf '%s_%s.csv', $date, $file_name;

  return $file_name;
}

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
      my $i7 = $p->tag_sequences->[0] || q();
      my $i5 = $p->tag_sequences->[1] || q();
      if ($i5) { # reverse-complement
        $i5 =~ tr/[ACGT]/[TGCA]/;
        $i5 = reverse $i5;
      }
      push @products, [
        $position,
        $p->sample_name,
        $i7,
        $i5,
        $p->reference_genome() || q(),
        $p->library_type() || q()
      ];
    }
  }

  # sort by sample ID
  @products = sort { $a->[1] cmp $b->[1] } @products;

  return \@products;
}

has '_index_reads_length' => (
  'isa'        => 'ArrayRef',
  'is'         => 'ro',
  'lazy_build' => 1,
  'required'   => 0,
);
sub _build__index_reads_length {
  my $self = shift;
  my $index1_length = max (
    map { length $_->[$LIST_INDEX_TAG1] } $self->products
  );
  my $index2_length = max (
    map { length $_->[$LIST_INDEX_TAG2] } $self->products
  );
  return [$index1_length, $index2_length];
}

=head2 process

Generates a samplesheet and saves it to a file.

=cut

sub process {
  my $self = shift;

  $self->add_common_headers();
  $self->_add_line();
  $self->add_bclconvert_section();
  $self->_current_number_of_configs(1);

  if ($self->align) {
    $self->_add_line();
    my $num_samples = $self->add_germline_section();
    carp "$num_samples samples are added to the Germline section";
    if ($num_samples) {
      $self->_add_line();
    }
    if ($self->_current_number_of_configs ==
        $self->dragen_max_number_of_configs) {
      carp sprintf 'Already used %i distinct analysis configurations, ' .
        'will skip RNA section', $self->dragen_max_number_of_configs;
    } else {
      $num_samples = $self->add_rna_section();
      carp "$num_samples samples are added to the RNA section";
    }
  }

  my $csv = Text::CSV->new({
    eol      => qq[\n],
    sep_char => q[,],
  });

  my $max_num_columns = max map { scalar @{$_} } @{$self->_all_lines};

  my $file_name = $self->file_name;
  ## no critic (InputOutput::RequireBriefOpen)
  open my $fh, q[>], $file_name
    or croak "Failed to open $file_name for writing";

  for my $line (@{$self->_all_lines}) {
    my @columns = @{$line};
    # Pad the row.
    while (scalar @columns < $max_num_columns) {
      push @columns, q[];
    }
    $csv->print($fh, \@columns);
  }

  close $fh or carp "Problems closing $file_name";
  ## use critic

  return;
}

=head2 add_bclconvert_section

Unconditionally adds BCLConvert_Settings and BCLConvert_Data sections.

=cut

sub add_bclconvert_section {
  my $self = shift;

  my ($index1_length, $index2_length) = @{$self->_index_reads_length()};

  $self->_add_line('[BCLConvert_Settings]');
  $self->_add_line(q[SoftwareVersion], $SOFTWARE_VERSION);

  # Not clear what CLI analysis option thie coresponds to.
  # Looks likely to be a list of lanes to run a tag collision check.
  # According to @srl, bcl-covert tries to correct one error by default
  # but it checks the tags allow this I.e that they all differ by at least
  # 3 bases, if they don't it disables the error correction
  # $add_line->(qw(CombinedIndexCollisionCheck 1;3;4;6));

  # CreateFastqForIndexReads might be an option. Do we need these files?
  # $add_line->(qw(CreateFastqForIndexReads 1));
  # When 1 will be appropriate for this trim?
  # $add_line->(qw(TrimUMI 0));
  # dragen is the other compression options
  $self->_add_line(qw(FastqCompressionFormat gzip));

  # Barcode mismatch tolerances, the default is 1.
  # These settings can be omitted.
  #if ($index1_length) {
  #  $add_line->(qw(BarcodeMismatchesIndex1 1));
  #  if ($index2_length) {
  #    $add_line->(qw(BarcodeMismatchesIndex2 1));
  #  }
  #}

  # Adapter trimming settings. The sequence of the Read 1 (or 2) adapter
  # to be masked or trimmed. To trim multiple adapters, separate the sequences
  # with a plus sign (+) indicating independent adapters that must be
  # independently assessed for masking or trimming for each read.
  # Characters must be A, C, G, or T.
  # It seems that this settign can also be a column in teh data section
  #
  # $add_line->(qw(AdapterRead1 SOME));
  # $add_line->(qw(AdapterRead2 OTHER));

  $self->_add_line();
  $self->_add_line('[BCLConvert_Data]');

  my @data_header = qw(Lane Sample_ID);
  if ($index1_length) {
    push @data_header, q[Index];
    if ($index2_length) {
      push @data_header, q[Index2];
    }
    push @data_header, q[OverrideCycles];
  }
  $self->_add_line(@data_header);

  # Override Cycles - Specifies the sequencing and indexing cycles to be used
  # when processing the sequencing data. Must adhere to the
  # following requirements:
  # - Must be same number of fields (delimited by semicolon) as sequencing and
  #   indexing reads specified in RunInfo.xml or Reads section.
  # - Indexing reads are specified with I, sequencing reads are specified with
  #   Y, UMI cycles are specified with U, and trimmed reads are specified with N.
  # - The number of cycles specified for each read must equal the number of
  #   cycles specified for that read in the RunInfo.xml file.
  # - Only one Y or I sequence can be specified per read.

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

  for my $product ( $self->products() ) {

    my @product_data = ($product->[0], $product->[1]);

    my @override_cycles = ();
    # Not accounting for UMI cycles for now.
    if ($index1_length) {
      my $i7 = $product->[$LIST_INDEX_TAG1];
      push @product_data, $i7;
      push @override_cycles, q[Y] . $READ1_LENGTH;
      push @override_cycles,
        $index_override->($index1_length, $i7);
      if ($index2_length) {
        my $i5 = $product->[$LIST_INDEX_TAG2];
        push @product_data, $i5;
        push @override_cycles,
          $index_override->($index2_length, $i5);
      }
      push @override_cycles, q[Y] . $READ2_LENGTH;
    }
    if (@override_cycles) {
      push @product_data, join q[;], @override_cycles;
    }
    $self->_add_line(@product_data);
  }

  return;
}

=head2 add_common_headers

Adds the top-level header section.

=cut

sub add_common_headers {
  my $self = shift;

  my ($index1_length, $index2_length) = @{$self->_index_reads_length()};
  $self->_add_line('[Header]');
  $self->_add_line(q[FileFormatVersion], 2);
  $self->_add_line(q[RunName], $self->run_name);
  $self->_add_line(qw(InstrumentPlatform NovaSeqXSeries));
  # NovaSeqxPlus or NovaSeqX.
  # If the run id is given, this should come from the tracking database
  # when we fix the type there.
  $self->_add_line(qw(InstrumentType NovaSeqXPlus));
  $self->_add_line();

  # Reads section                                                              
  $self->_add_line('[Reads]');
  $self->_add_line(q[Read1Cycles], $READ1_LENGTH);
  $self->_add_line(q[Read2Cycles], $READ2_LENGTH);
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
    $self->_add_line(q[SoftwareVersion], $SOFTWARE_VERSION);
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

    if ( can_do_alignment($r) &&
         (do_ref_rna_alignment_test($r) || do_libtype_rna_alignment_test($lib_type)) ) {

      my $match = first { $r =~ /$_/xms} @ref_matches;
      if ($self->_can_add_sample($distinct_configs, $match)) {
        push @to_align, [$p->[1], $REFERENCE_MAPING{$match}];
      }
    }
  }

  if (@to_align) {
    $self->_add_line('[DragenRNA_Settings]');
    $self->_add_line(q(SoftwareVersion), $SOFTWARE_VERSION);
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

=item Getopt::Long

=item Pod::Usage

=item DateTime

=item Data::UUID

=item st::api::lims

=item npg_tracking::Schema

=item npg_tracking::util::types

=item WTSI::DNAP::Warehouse::Schema

=back

=head1 BUGS AND LIMITATIONS

=head1 INCOMPATIBILITIES

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2023 Genome Research Ltd

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

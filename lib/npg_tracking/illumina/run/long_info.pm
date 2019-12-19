package npg_tracking::illumina::run::long_info;

use Moose::Role;
use Carp;
use List::Util qw(first sum);
use List::MoreUtils qw(pairwise);
use IO::All;
use File::Spec;
use XML::LibXML;
use Try::Tiny;

requires qw{runfolder_path};

our $VERSION = '0';

=head1 NAME

npg_tracking::illumina::run::long_info

=head1 VERSION

=head1 SYNOPSIS

  package Mypackage;
  use Moose;

  ... before consuming this role, you need to provide runfolder_path methods

  with q{npg_tracking::illumina::run::long_info};

=head1 DESCRIPTION

This role provides methods providing information about the run, ideally from the filesystem.

=head1 SUBROUTINES/METHODS

=cut

#########################################################
#       Public attributes and methods                   #
#########################################################

=head2 is_paired_read

Boolean determines if the run is a paired read or not, this can be set on object construction

  my $bIsPairedRead = $class->is_paired_read();

=cut

has q{is_paired_read} => (
  isa           => q{Bool},
  is            => q{ro},
  lazy_build    => 1,
  documentation => q{This run is a paired end read},
);
sub _build_is_paired_read {
  my $self = shift;
  return $self->read2_cycle_range ? 1 : 0;
}

=head2 is_indexed

Boolean determines if the run is indexed or not, this can be set on object construction

  my $bIsIndexed = $class->is_indexed();

=cut

has q{is_indexed} => (
  isa           => q{Bool},
  is            => q{ro},
  lazy_build    => 1,
  documentation => q{This run has at least one read},
);
sub _build_is_indexed {
  my $self = shift;
  return $self->indexing_cycle_range ? 1 : 0;
}

=head2 index_length

The length of the index 'barcode'

  my $iIndexLength = $class->index_length();

=cut

has q{index_length} => (
  isa           => q{Int},
  is            => q{ro},
  lazy_build    => 1,
  documentation => q{The length of the index 'barcode', normally the number of cycles performed},
);
sub _build_index_length {
  my $self = shift;

  # if not indexed, then the length would by default be 0
  if (!$self->is_indexed()) {
    return 0;
  }

  my ($start,$end) = $self->indexing_cycle_range();
  return $end - $start + 1;
}

=head2 is_dual_index

Boolean determines if the run has a second index read, this can be set on object construction

  my $bIsDualIndex = $class->is_dual_index();

=cut

has q{is_dual_index} => (
  isa           => q{Bool},
  is            => q{ro},
  lazy_build    => 1,
  documentation => q{This run is a paired end read},
);
sub _build_is_dual_index {
  my $self = shift;
  return $self->index_read2_cycle_range ? 1 : 0;
}

=head2 lane_count

Number of lanes configured for this run. May be set on Construction.

  my $iLaneCount = $self->lane_count();

=cut

has q{lane_count} => (
  is            => 'ro',
  isa           => 'Int',
  writer        => '_set_lane_count',
  predicate     => 'has_lane_count',
  documentation => q{The number of lanes on this run},
);

=head2 read_cycle_counts

List of cycle lengths configured for each read/index in order.

=cut

has q{_read_cycle_counts} => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => 'ArrayRef[Int]',
  default => sub { [] },
  handles => {
    _push_read_cycle_counts => 'push',
    read_cycle_counts       => 'elements',
    has_read_cycle_counts   => 'count',
  },
);

=head2 reads_indexed

List of booleans for each read indicating a multiplex index.

=cut

has q{_reads_indexed} => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => 'ArrayRef[Bool]',
  default => sub { [] },
  handles => {
    _push_reads_indexed => 'push',
    reads_indexed       => 'elements',
    has_reads_indexed   => 'count',
  },
);

=head2 indexing_cycle_range

First and last indexing cycles, or nothing returned if not indexed

=cut

has q{_indexing_cycle_range} => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => 'ArrayRef[Int]',
  default => sub { [] },
  handles => {
    _pop_indexing_cycle_range  => 'pop',
    _push_indexing_cycle_range => 'push',
    indexing_cycle_range       => 'elements',
    has_indexing_cycle_range   => 'count',
  },
);

=head2 read1_cycle_range

First and last cycles of read 1

=cut

has q{_read1_cycle_range} => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => 'ArrayRef[Int]',
  default => sub { [] },
  handles => {
    _push_read1_cycle_range  => 'push',
    read1_cycle_range        => 'elements',
    has_read1_cycle_range    => 'count',
  },
);

=head2 read2_cycle_range

First and last cycles of read 2, or nothing returned if no read 2

=cut

has _read2_cycle_range => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => 'ArrayRef[Int]',
  default => sub { [] },
  handles => {
    _push_read2_cycle_range => 'push',
    read2_cycle_range       => 'elements',
    has_read2_cycle_range   => 'count',
  },
);

=head2 index_read1_cycle_range

First and last cycles of index read 1, or nothing returned if no index_read 1

=cut

has q{_index_read1_cycle_range} => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => 'ArrayRef[Int]',
  default => sub { [] },
  handles => {
    _push_index_read1_cycle_range  => 'push',
    index_read1_cycle_range        => 'elements',
    has_index_read1_cycle_range    => 'count',
  },
);

=head2 index_read2_cycle_range

First and last cycles of index_read 2, or nothing returned if no index_read 2

=cut

has _index_read2_cycle_range => (
  traits  => ['Array'],
  is      => 'ro',
  isa     => 'ArrayRef[Int]',
  default => sub { [] },
  handles => {
    _push_index_read2_cycle_range => 'push',
    index_read2_cycle_range       => 'elements',
    has_index_read2_cycle_range   => 'count',
  },
);

=head2 expected_cycle_count

Number of cycles configured for this run and for which the output data (images or intensities or both) can be expected to be found below this folder. This number is extracted from the recipe file. It does not include the cycles for the paired read if that is performed as a separate run - the output data for that will be in a different runfolder.
May be set on construction.

  $iExpectedCycleCount = $self->expected_cycle_count();

=cut

has q{expected_cycle_count} => (
  is         => 'ro',
  isa        => 'Int',
  lazy_build => 1,
  writer     => '_set_expected_cycle_count',
);
sub _build_expected_cycle_count {
  my $self = shift;
  return sum $self->read_cycle_counts;
}

=head2 cycle_count

synonym for expected_cycle_count. May not be set on construction. Best to use expected_cycle_count.

=cut

sub cycle_count {
  my $self = shift;
  return $self->expected_cycle_count();
}

=head2 tilelayout_columns

The number of tile columns in a lane. May be set on construction.

  my $iTilelayoutColumns = $class->tilelayout_columns();

=cut

has q{tilelayout_columns} => (
  is            => 'ro',
  isa           => 'Int',
  writer        => '_set_tilelayout_columns',
  predicate     => 'has_tilelayout_columns',
  documentation => q{The number of tile columns in a lane},
);

=head2 tilelayout_rows

The number of tile rows in a lane. May be set on construction.

  my $iTilelayoutRows = $class->tilelayout_rows();

=cut

has q{tilelayout_rows} => (
  is            => 'ro',
  isa           => 'Int',
  writer        => '_set_tilelayout_rows',
  predicate     => 'has_tilelayout_rows',
  documentation => q{The number of tile rows in a lane},
);

=head2 tile_count

=cut

has q{tile_count} => (
  isa           => q{Int},
  is            => q{ro},
  lazy_build    => 1,
  writer        => '_set_tile_count',
  documentation => q{Number of tiles in a lane},
);
sub _build_tile_count {
  my ($self) = @_;
  my $tcount;
  try {
    my $lane_el = $self->_data_intensities_config_xml_object()->getElementsByTagName('Lane')->[0];
    $tcount = $lane_el->getElementsByTagName('Tile')->size();
  } catch {
    $tcount = $self->tilelayout_rows() * $self->tilelayout_columns();
  };
  return $tcount;
}

=head2 lane_tilecount

utilises the Data/Intensities/config.xml to generate a hashref of

  {lanes} = tilecount_value

=cut

has q{lane_tilecount} => (
  isa        => q{HashRef},
  is         => q{ro},
  lazy_build => 1,
);
sub _build_lane_tilecount {
  my ( $self ) = @_;
  my $lane_tilecount = {};
  try {
    my $run_el = ( $self->_data_intensities_config_xml_object()->getElementsByTagName( 'Run' ) )[0];

    for my $lane_el ( ( $run_el->getChildrenByTagName( 'TileSelection' ) )[0]->getChildrenByTagName( 'Lane' ) ) {
      my $lane = $lane_el->getAttribute( 'Index' );
      $lane_tilecount->{ $lane } = $lane_el->getElementsByTagName('Tile')->size();
    }
  } catch {
    my $lane_count = $self->lane_count();
    my $tile_count = $self->tile_count();
    for my $lane (1..$lane_count) {
      $lane_tilecount->{ $lane } = $tile_count;
    }
  };

  return $lane_tilecount;
}

=head2 experiment_name

For platforms HiSeq, HiSeqX, Hiseq4000 and NovaSeq experiment name loaded from
runParameters.xml.

=cut

has q{experiment_name} => (
  isa        => 'Maybe[Str]',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_experiment_name {
  my $self = shift;

  my $doc = $self->_run_params;
  my $experiment_name;

  $experiment_name = _get_single_element_text($doc, 'ExperimentName') || q[];

  return $experiment_name;
}

=head2 run_flowcell

flowcell loaded from RunInfo.xml for platforms HiSeq and NovaSeq and
ReagentKitBarcode from runParameters.xml for platform MiSeq

=cut

has q{run_flowcell} => (
  isa        => 'Str',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_run_flowcell {
  my $self = shift;

  my $flowcell;

  if ($self->platform_MiSeq()) {
    my $doc = $self->_run_params;
    $flowcell = _get_single_element_text($doc, 'ReagentKitBarcode');
  } else {
    my $doc = $self->_runinfo_document;
    $flowcell = _get_single_element_text($doc, 'Flowcell');
  }

  return $flowcell;
}

#########################################################
# 'before' attribute modifiers definitions              #
#########################################################

foreach my $f ( qw(expected_cycle_count
                   lane_count
                   read_cycle_counts
                   indexing_cycle_range
                   read1_cycle_range
                   read2_cycle_range
                   index_read1_cycle_range
                   index_read2_cycle_range
                   tilelayout_rows
                   tilelayout_columns) ) {
   before $f => sub {
     my $self = shift;
     my $has_method_name = join q[_], 'has', $f;
     if( !$self->$has_method_name ) { # If array is empty
       $self->_runinfo_store();
     }
   };
}

#########################################################
# End of 'before' attribute modifiers definitions       #
#########################################################

##no critic (NamingConventions::Capitalization)

=head2 platform_HiSeq

Method returns true if sequencing was performed on an Illumina
instrument belonging to an 'older' HiSeq platform (1000, 1500, 2000 and 2500).

=cut

sub platform_HiSeq {
  my $self = shift;
  return ( ($self->_software_application_name() =~ /HiSeq/xms) and
       not ($self->platform_HiSeqX() or $self->platform_HiSeq4000()) );
}

=head2 platform_HiSeq4000

Method returns true if sequencing was performed on an Illumina
instrument belonging to HiSeq 3000 or HiSeq 4000 platform.

=cut

sub platform_HiSeq4000 {
  my $self = shift;
  return $self->_flowcell_description() =~ /HiSeq\ 3000\/4000/xms;
}

=head2 platform_HiSeqX

Method returns true if sequencing was performed on an Illumina
instrument belonging to HiSeq X platform.

=cut

sub platform_HiSeqX {
  my $self = shift;
  return $self->_flowcell_description() =~ /HiSeq\ X/xms;
}

=head2 platform_MiniSeq

Method returns true if sequencing was performed on an Illumina
instrument belonging to MiniSeq platform.

=cut

sub platform_MiniSeq {
  my $self = shift;
  return $self->_run_params_version() =~ /MiniSeq/xms;
}

=head2 platform_MiSeq

Method returns true if sequencing was performed on an Illumina
instrument belonging to MiSeq platform.

=cut

sub platform_MiSeq {
  my $self = shift;
  return $self->_software_application_name() =~ /MiSeq/xms;
}

=head2 platform_NextSeq

Method returns true if sequencing was performed on an Illumina
instrument belonging to NextSeq platform.

=cut

sub platform_NextSeq {
  my $self = shift;
  return $self->_software_application_name() =~ /NextSeq/xms;
}

=head2 platform_NovaSeq

Method returns true if sequencing was performed on an Illumina
instrument belonging to NovaSeq platform.

=cut

sub platform_NovaSeq {
  my $self = shift;
  return $self->_software_application_name() =~ /NovaSeq/xms;
}

##use critic

=head2 workflow_type

=cut

has q{workflow_type} => (
  isa        => 'Str',
  is         => 'ro',
  lazy_build => 1,
);
sub _build_workflow_type {
  my $self = shift;
  return _get_single_element_text($self->_run_params(), 'WorkflowType');
}

=head2 all_lanes_mergeable

Method returns true if all lanes on the flowcell contain the
same library and the sequencing data are thus mergeable across
all lanes.

=cut

sub all_lanes_mergeable {
  my $self = shift;
  return (
    ($self->workflow_type() =~ /NovaSeqStandard/xms) # ie not NovaSeqXp
     or $self->is_rapid_run() # In our practice Rapid Runs always had the same
                              # library on both lanes.
         );
}

=head2 is_rapid_run

Method returns true if RapidRun mode was used.

=cut

sub is_rapid_run {
  my $self = shift;
  return $self->_run_mode() =~ /RapidRun/xms;
}

=head2 is_rapid_run_v1

Method returns true if Rapid Run Chemistry v1 was used.

=cut

sub is_rapid_run_v1 {
  my $self = shift;
  return $self->_flowcell_description() =~ /Rapid\ Flow\ Cell\ v1/xms;
}

=head2 is_rapid_run_v2

Method returns true if Rapid Run Chemistry v2 was used.

=cut

sub is_rapid_run_v2 {
  my $self = shift;
  return $self->_flowcell_description() =~ /Rapid\ Flow\ Cell\ v2/xms;
}

=head2 is_rapid_run_abovev2

Method returns true if Rapid Run Chemistry higher than v2 was used.

=cut

sub is_rapid_run_abovev2 {
  my $self = shift;
  my ($version) = $self->_flowcell_description() =~ /Rapid\ Flow\ Cell\ v(\d)/xms;
  return $version && ($version > 2);
}

=head2 is_i5opposite

A dual-indexed sequencing run on the MiniSeq, NextSeq, HiSeq 4000, or HiSeq 3000
performs the Index 2 Read after the Read 2 resynthesis step. This workflow
requires a reverse complement of the Index 2 (i5) primer sequence compared to
the primer sequence used on other Illumina platform, see
https://support.illumina.com/content/dam/illumina-support/documents/documentation/system_documentation/miseq/indexed-sequencing-overview-guide-15057455-04.pdf

Method returns true if this is the case.

=cut

sub is_i5opposite {
  my $self = shift;
  return ($self->platform_HiSeqX()  or $self->platform_HiSeq4000() or
          $self->platform_MiniSeq() or $self->platform_NextSeq());
}

=head2 uses_patterned_flowcell

HiSeqX, HiSeq3000/4000, and NovaSeq use patterned flowcells
https://www.illumina.com/science/technology/next-generation-sequencing/sequencing-technology/patterned-flow-cells.html

Method returns true if this is one of those platforms.

=cut

sub uses_patterned_flowcell {
  my $self = shift;

  return ($self->platform_HiSeqX
          or $self->platform_HiSeq4000
          or $self->platform_NovaSeq);
}

=head2 instrument_side

Returns the instrument side (A or B) if available or an empty string.

=cut

sub instrument_side {
  my $self = shift;
  return _get_single_element_text($self->_run_params(), 'Side') ||
    _get_single_element_text($self->_run_params(), 'FCPosition');
}

#########################################################
#       Private attributes                              #
#########################################################

has q{_run_params} => (
  is         => 'ro',
  isa        => 'XML::LibXML::Document',
  lazy_build => 1,
);
sub _build__run_params {
  my $self = shift;
  return $self->_get_xml_document(qr/[R|r]unParameters[.]xml/smx, $self->runfolder_path());
}

has q{_runinfo_document} => (
  is         => 'ro',
  isa        => 'XML::LibXML::Document',
  lazy_build => 1,
);
sub _build__runinfo_document {
  my $self = shift;

  return $self->_get_xml_document(qr/RunInfo[.]xml/smx, $self->runfolder_path());
};

has q{_flowcell_description} => (
  isa        => 'Str',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__flowcell_description {
  my $self = shift;
  return _get_single_element_text($self->_run_params(), 'Flowcell');
}

has q{_software_application_name} => (
  isa        => 'Str',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__software_application_name {
  my $self = shift;
  return (_get_single_element_text($self->_run_params(), 'ApplicationName') or
          _get_single_element_text($self->_run_params(), 'Application'));
}

has q{_run_params_version} => (
  isa        => 'Str',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__run_params_version {
  my $self = shift;
  return _get_single_element_text($self->_run_params(), 'RunParametersVersion');
}

has q{_run_mode} => (
  isa        => 'Str',
  is         => 'ro',
  lazy_build => 1,
);
sub _build__run_mode {
  my $self = shift;
  return _get_single_element_text($self->_run_params(), 'RunMode');
}

has q{_runinfo_store} => (
  is         => 'ro',
  isa        => 'Bool',
  lazy_build => 1,
);
sub _build__runinfo_store {
  my $self = shift;

  my $doc = $self->_runinfo_document;

  my $fcl_el = $doc->getElementsByTagName('FlowcellLayout')->[0];
  if(not defined $fcl_el) {
    $self->_set_lane_count($doc->getElementsByTagName('Lane')->size);
    $self->_set_expected_cycle_count($doc->getElementsByTagName('Cycles')->[0]->getAttribute('Incorporation'));

    my $rc = {
      count => 0, #restarts with each read
      start => 1, #start of current read
      index => 0, #from first read
      read_index => 1, #non-indexing/mutiplex read number
      indexingcurrent =>0,
    };

    my $indexprepelementfound;
    my @nodelist = $doc->getElementsByTagName('Reads')->[0]->getElementsByTagName('Read');
    foreach ( @nodelist){
      $rc->{start} = $_->getAttribute('FirstCycle');
      $rc->{index} = $_->getAttribute('LastCycle');
      $rc->{count} = $rc->{index} - $rc->{start} +1;
      if ( $_->getElementsByTagName('Index') and not $indexprepelementfound) {
        $rc->{indexingcurrent} = 1;
        $indexprepelementfound++;
      } else {
        $rc->{indexingcurrent} = 0;
      }
      $self->_set_values_at_end_of_read($rc);
    }

  }else{
    $self->_set_lane_count($fcl_el->getAttribute('LaneCount'));
    my $ncol = $fcl_el->getAttribute('SurfaceCount') * $fcl_el->getAttribute('SwathCount');
    my $nrow = $fcl_el->getAttribute('TileCount'); #informatic split on HiSeq
    $self->_set_tilelayout_columns($ncol);
    $self->_set_tilelayout_rows($nrow);
    $self->_set_tile_count($ncol * $nrow);

    my $rc = {
      count => 0, #restarts with each read
      start => 1, #start of current read
      index => 0, #from first read
      read_index => 1, #non-indexing/mutiplex read number
      indexingcurrent =>0,
    };

    my $count=0;
    my @nodelist = $doc->getElementsByTagName('Reads')->[0]->getElementsByTagName('Read');
    foreach ( @nodelist){
      my $inc_count = $_->getAttribute('NumCycles');
      $rc->{index} += $inc_count;
      $rc->{count} = $inc_count;
      $count += $inc_count;
      if ( $_->getAttribute('IsIndexedRead') eq 'Y' ) {
        $rc->{indexingcurrent} = 1;
      } else {
        $rc->{indexingcurrent} = 0;
      }
      $self->_set_values_at_end_of_read($rc);
    }
  }

  return 1; # So builder runs only once
}

has q{_data_intensities_config_xml_object} => (
  is         => q{ro},
  isa        => q{XML::LibXML::Document},
  lazy_build => 1,
);
sub _build__data_intensities_config_xml_object {
  my $self = shift;
  return $self->_get_xml_document( qr/config[.]xml/xms,
                File::Spec->catdir($self->runfolder_path(), qw(Data Intensities)));
}

#########################################################
#       Private methods                                 #
#########################################################

sub _get_xml_document {
  my ($self, $reg_expr, $dir) = @_;

  if (!$reg_expr) {
    croak 'Regular expression for name required';
  }
  if (!$dir) {
    croak 'Directory path required';
  }

  my @files = grep { m/\/$reg_expr\Z/xms } io($dir)->all;
  if (@files < 1) {
    croak qq{File not found for $reg_expr in $dir};
  }
  if (@files > 1) {
    croak 'Multiple files found: ' . join q(,) , @files;
  }

  return XML::LibXML->load_xml(location => $files[0]);
}

sub _get_single_element_text {
  my ($doc, $tag_name) = @_;
  my $nl = $doc->getElementsByTagName($tag_name);
  my $list_size = $nl->size();
  if ($list_size > 1) {
    croak qq{Multiple $tag_name tags};
  }
  my $text = q[];
  if ($list_size == 1) {
    $text = $nl->pop()->textContent() // q[];
  }
  return $text;
}

sub _set_values_at_end_of_read {
  my ($self,$rc) = @_;

  if ($rc->{count}) {

    $self->_push_read_cycle_counts( $rc->{count} );

    if ($rc->{indexingcurrent}) {
      $self->_push_reads_indexed(1);
      if ( $self->has_indexing_cycle_range ) {
        my ($start,$end) = $self->indexing_cycle_range;
        if ( $rc->{start} == $end + 1 ) {
          $self->_pop_indexing_cycle_range();
          $self->_push_indexing_cycle_range( $rc->{index} );
          $self->_push_index_read2_cycle_range( $rc->{start},$rc->{index} );
        } else {
          carp "Don't know how to deal with non adjacent indexing reads: $start,$end and $rc->{start},$rc->{index}"
        }
      } else {
        $self->_push_indexing_cycle_range( $rc->{start},$rc->{index} );
        $self->_push_index_read1_cycle_range( $rc->{start},$rc->{index} );
      }
    } else {
      $self->_push_reads_indexed(0);
      if ($rc->{read_index}==1) {
        $self->_push_read1_cycle_range( $rc->{start},$rc->{index} );
      } elsif ( not $self->has_read2_cycle_range ) {
        $self->_push_read2_cycle_range( $rc->{start},$rc->{index} );
      } else {
        carp "Don't know how to deal with more than 2 non index reads (read index $rc->{read_index}, last read range $rc->{start},$rc->{index})";
      }

      $rc->{read_index}++;
    }

    $rc->{count} = 0;
    $rc->{start} = $rc->{index} + 1;
  }
  return;
}

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Carp

=item List::Util

=item List::MoreUtils

=item IO::All

=item XML::LibXML

=item Try::Tiny

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Andy Brown

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 by GRL

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

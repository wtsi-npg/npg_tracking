#############
# $Id: long_info.pm 16549 2013-01-23 16:49:39Z mg8 $
# Created By: ajb
# Mast Maintained By: $Author: mg8 $
# Created On: 2009-09-30
# Last Changed On: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/illumina/run/long_info.pm $

package npg_tracking::illumina::run::long_info;
use Moose::Role;

use Moose::Util::TypeConstraints;
use MooseX::AttributeHelpers;

use strict;
use warnings;
use Carp;
use English qw{-no_match_vars};

use List::Util qw(first sum);
use List::MoreUtils qw(pairwise);
use IO::All;
use XML::LibXML;
use Try::Tiny;

requires qw{runfolder_path};
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 16549 $ =~ /(\d+)/mxs; $r; };

=head1 NAME

npg_tracking::illumina::run::long_info

=head1 VERSION

$LastChangedRevision: 16549 $

=head1 SYNOPSIS

  package Mypackage;
  use Moose;
  
  ... before consuming this role, you need to provide runfolder_path methods ...

  with q{npg_tracking::illumina::run::long_info};

=head1 DESCRIPTION

This role provides methods providing information about the run, ideally from the filesystem.

=head1 SUBROUTINES/METHODS

=head2 is_paired_read

Boolean determines if the run is a paired read or not, this can be set on object construction

  my $bIsPairedRead = $class->is_paired_read();

=cut

has q{is_paired_read} => (isa => q{Bool}, is => q{ro}, lazy_build => 1,
  documentation => q{This run is a paired end read},);

sub _build_is_paired_read {
  my ($self) = @_;

  return $self->read2_cycle_range ? 1 : 0;
}

=head2 is_indexed

Boolean determines if the run is indexed or not, this can be set on object construction

  my $bIsIndexed = $class->is_indexed();

=cut

has q{is_indexed} => (isa => q{Bool}, is => q{ro}, lazy_build => 1,
  documentation => q{This run is an indexed run},);

sub _build_is_indexed {
  my ($self) = @_;

  return $self->indexing_cycle_range ? 1 : 0;
}

=head2 index_length

The length of the index 'barcode'

  my $iIndexLength = $class->index_length();

=cut

has q{index_length} => (isa => q{Int}, is => q{ro}, lazy_build => 1,
  documentation => q{The length of the index 'barcode', normally the number of cycles performed},);

sub _build_index_length {
  my ($self) = @_;

  # if not indexed, then the length would by default be 0
  if (!$self->is_indexed()) {
    return 0;
  }

  my ($start,$end) = $self->indexing_cycle_range();
  return $end - $start + 1;
}

=head2 use_bases

The config string used by Illumina and other scripts to describe the run i.e. Y54,I6n,y54
can be set on object construction

  my $sUseBases = $class->use_bases();

=head2 read_config_string

synonym for use_bases - cannot be used to set on construction

=cut

#################
# note, much of the code below is stolen from srpipe::runfolder (perhaps to be swapped for this role)
#################

has q{use_bases} => (isa => q{Str}, is => q{ro}, lazy_build => 1,
  documentation => q{The config string used by Illumina and other scripts to describe the run i.e. Y54,I6n,y54},);

sub _build_use_bases {
  my ($self) = @_;
  my@rc=$self->read_cycle_counts();
  my@ri=$self->reads_indexed();
  my$l=0;
  return join q(,), pairwise { ( $b ? q(I) : ( $l++ ? q(y) : q(Y) ) ).$a } @rc, @ri;
}

sub read_config_string {
  my ($self) = @_;
  return $self->use_bases;
}

=head2 recipe

XML string from recipe file containing Illumina GA run instructions.

=cut

# if used as the attribute, causes a run_time error when called

sub recipe {
  my ($self) = @_;
  return $self->_recipe_store();
}

has _recipe_store => (
  is => 'ro',
  isa => 'Str',
  lazy_build => 1,
  init_arg => undef,
);

sub _fetch_recipe {
  my $self = shift;
  my @files = map { $self->runfolder_path.qq(/$_) } map { /Recipe\S*?[.]xml/smxg } io($self->runfolder_path)->all;
  if (@files < 1) {
    croak 'No recipe file found';
  }
  if (@files > 1) {
    croak 'Multiple recipe files found: ' . join q(,) , @files;
  }
  return io(shift @files)->slurp;
}

sub _build__recipe_store {
  my $self = shift;

  my $recipe = $self->_fetch_recipe();

  #Now parse recipe and record useful info...:
  my $doc = XML::LibXML->new()->parse_string($recipe);
  my @nodelist = $doc->getElementsByTagName('Protocol');

  $self->_set_lane_count($doc->getElementsByTagName('Lane')->size);
  $self->_set_expected_cycle_count(sum map { $_->getElementsByTagName('Incorporation')->size() } @nodelist);

  my $rc = {
    count => 0, #restarts with each read
    start => 1, #start of current read
    index => 0, #from first read
    read_index => 1, #non-indexing/mutiplex read number
    indexingcurrent =>0,
  };
  my $indexprepelementfound;

  foreach ( map { $_->getElementsByTagName(q(*)) } @nodelist){

    if ( $_->localname eq 'Incorporation' ) {

      $rc->{count}++; $rc->{index}++;

    } elsif ($_->localname eq 'ChemistryRef') {

      if ( $_->getAttribute('Name') =~ /(\AEnd)|(FirstBase\Z)/smx ) {

        $self->_set_values_at_end_of_read( $rc );
        if ( $indexprepelementfound or ( $_->getAttribute('Name') =~ /\AIndexing/smx ) ) {

          $rc->{indexingcurrent} = 1;
          $indexprepelementfound = 0;

        } else {

          $rc->{indexingcurrent} = 0;

        }

      } elsif ($_->getAttribute('Name') eq q(IndexingPreparation)) {

        $indexprepelementfound = 1;

      }

    }

  }

  $self->_set_values_at_end_of_read($rc);
  return $recipe;
}


=head2 runinfo

XML string from runinfo file containing Illumina run config.

=cut

# if used as the attribute, causes a run_time error when called - presumably (as code copied from above)

sub runinfo {
  my ($self) = @_;
  return $self->_runinfo_store();
}

has _runinfo_store => (
  is => 'ro',
  isa => 'Str',
  lazy_build => 1,
  init_arg => undef,
);

sub _fetch_runinfo {
  my $self = shift;
  return io(join q(/),$self->runfolder_path,'RunInfo.xml' )->slurp;
}

sub _build__runinfo_store {
  my $self = shift;

  my $runinfo = $self->_fetch_runinfo();

  #Now parse runinfo and record useful info...:
  my $doc = XML::LibXML->new()->parse_string($runinfo);

  my $formatversion=$doc->getElementsByTagName('RunInfo')->[0]->getAttribute('Version');
  if(not defined $formatversion){
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

  }elsif($formatversion == 2){
    my $fcl_el = $doc->getElementsByTagName('FlowcellLayout')->[0];
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

  }else{
    croak "unknown RunInfo.xml Version $formatversion";
  }

  return $runinfo;
}

sub _set_values_at_end_of_read {
  my ($self,$rc) = @_;

  if ($rc->{count}) {

    $self->_push_read_cycle_counts( $rc->{count} );

    if ($rc->{indexingcurrent}) {
      $self->_push_reads_indexed(1);
      if ( $self->has_indexing_cycle_range ) {
        my ($start,$end) = $self->indexing_cycle_range;
        if ( $end != $rc->{start} + 1 ) {
          $self->_pop_indexing_cycle_range();
          $self->_push_indexing_cycle_range( $rc->{index} );
        } else {
          carp "Don't know how to deal with no adjacent indexing reads: $start,$end and $rc->{start},$rc->{index}"
        }
      } else {
        $self->_push_indexing_cycle_range( $rc->{start},$rc->{index} );
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

=head2 lane_count

Number of lanes configured for this run. May be set on Construction.

  my $iLaneCount = $self->lane_count();

=cut

has lane_count => (
  is => 'ro',
  isa => 'Int',
  writer => '_set_lane_count',
  predicate => 'has_lane_count',
  documentation => q{The number of lanes on this run},
);


=head2 read_cycle_counts

List of cycle lengths configured for each read/index in order.

=cut

has _read_cycle_counts => (
  traits => ['Array'],
  is => 'ro',
  isa => 'ArrayRef[Int]',
  default   => sub { [] },
  handles  => {
    _push_read_cycle_counts => 'push',
    read_cycle_counts => 'elements',
    has_read_cycle_counts => 'count',
  },
  #look at before loop lower down
);

=head2 reads_indexed

List of booleans for each read indicating a multiplex index.

=cut

has _reads_indexed => (
  traits => ['Array'],
  is => 'ro',
  isa => 'ArrayRef[Bool]',
  default   => sub { [] },
  handles  => {
    _push_reads_indexed => 'push',
    reads_indexed => 'elements',
    has_reads_indexed => 'count',
  },
);



=head2 indexing_cycle_range

First and last indexing cycles, or nothing returned if not indexed

=cut

has _indexing_cycle_range => (
  traits => ['Array'],
  is => 'ro',
  isa => 'ArrayRef[Int]',
  default   => sub { [] },
  handles  => {
    _pop_indexing_cycle_range => 'pop',
    _push_indexing_cycle_range => 'push',
    indexing_cycle_range => 'elements',
    has_indexing_cycle_range => 'count',
  },
  #look at before loop lower down
);


=head2 read1_cycle_range

First and last cycles of read 1

=cut

has _read1_cycle_range => (
  traits => ['Array'],
  is => 'ro',
  isa => 'ArrayRef[Int]',
  default   => sub { [] },
  handles  => {
    _push_read1_cycle_range => 'push',
    read1_cycle_range => 'elements',
    has_read1_cycle_range => 'count',
  },
  #look at before loop lower down
);


=head2 read2_cycle_range

First and last cycles of read 2, or nothing returned if no read 2

=cut

has _read2_cycle_range => (
  traits => ['Array'],
  is => 'ro',
  isa => 'ArrayRef[Int]',
  default   => sub { [] },
  handles  => {
    _push_read2_cycle_range => 'push',
    read2_cycle_range => 'elements',
    has_read2_cycle_range => 'count',
  },
  #look at before loop lower down
);


=head2 expected_cycle_count

Number of cycles configured for this run and for which the output data (images or intensities or both) can be expected to be found below this folder. This number is extracted from the recipe file. It does not include the cycles for the paired read if that is performed as a separate run - the output data for that will be in a different runfolder.
May be set on construction.

  $iExpectedCycleCount = $self->expected_cycle_count();

=cut

has expected_cycle_count => (
  is => 'ro',
  isa => 'Int',
#  predicate => 'has_expected_cycle_count',
  lazy_build => 1,
  writer => '_set_expected_cycle_count',
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

#loop for extracting cycle info from recipe or runinfo

foreach my $f (qw(expected_cycle_count lane_count read_cycle_counts indexing_cycle_range read1_cycle_range read2_cycle_range)){
  before $f => sub{
    my $self=shift;
    my $hf = "has_$f";
    if(not $self->$hf){
      try {
        $self->runinfo;
      } catch {
        $self->recipe;
      };
    }
  };
}

=head2 tilelayout

XML from the Config/TileLayout.xml file.

=cut

sub tilelayout {
  my ($self) = @_;
  return $self->_tilelayout_store();
}

has _tilelayout_store  => (
  is => 'ro',
  isa => 'Str',
  lazy_build => 1,
  init_arg => undef,
);


sub _build__tilelayout_store {
  my $self = shift;

  my $tilelayout = io( join q(/),$self->runfolder_path,'Config','TileLayout.xml' )->slurp ;
  #Now parse file and record useful info...:
  my $doc = XML::LibXML->new()->parse_string($tilelayout);
  my $tl_element = $doc->getElementsByTagName('TileLayout')->[0];

  $self->_set_tilelayout_columns($tl_element->getAttribute('Columns'));
  $self->_set_tilelayout_rows($tl_element->getAttribute('Rows'));

  return $tilelayout;
}

=head2 tilelayout_columns

The number of tile columns in a lane. May be set on construction.

  my $iTilelayoutColumns = $class->tilelayout_columns();

=cut

has tilelayout_columns => (
  is => 'ro',
  isa => 'Int',
  writer => '_set_tilelayout_columns',
  predicate => 'has_tilelayout_columns',
  documentation => q{The number of tile columns in a lane},
);

=head2 tilelayout_rows

The number of tile rows in a lane. May be set on construction.

  my $iTilelayoutRows = $class->tilelayout_rows();

=cut

has tilelayout_rows => (
  is => 'ro',
  isa => 'Int',
  writer => '_set_tilelayout_rows',
  predicate => 'has_tilelayout_rows',
  documentation => q{The number of tile rows in a lane},
);

#loop for extracting tile info from tilelayout or runinfo

foreach my $f (qw(tilelayout_rows tilelayout_columns)){
  before $f => sub{
    my $self=shift;
    my $hf = "has_$f";
    if(not $self->$hf){
      try {
        $self->runinfo;
      };
      if(not $self->$hf) {
        $self->tilelayout;
      };
    }
  };
}


=head2 tile_count

=cut

has q{tile_count} => (
  isa => q{Int},
  is => q{ro},
  lazy_build => 1,
  writer => '_set_tile_count',
  documentation => q{Number of tiles in a lane},
);

sub _build_tile_count {
  my ($self) = @_;
  my $tcount;
  try {
#    $self->data_intensities_config;
#    $tcount = $self->tile_count;
    my $lane_el = $self->data_intensities_config_xml_object()->getElementsByTagName('Lane')->[0];
    $tcount = $lane_el->getElementsByTagName('Tile')->size();
  } catch {
    $tcount = $self->tilelayout_rows() * $self->tilelayout_columns();
  };
  return $tcount;
}

=head2 data_intensities_config

The string contents of the Data/Intensities/config.xml file

=cut

has data_intensities_config => (
  is => 'ro',
  isa => 'Str',
  lazy_build => 1,
);

sub _build_data_intensities_config {
  my ($self) = @_;
  my $c = io( join q(/), $self->runfolder_path, qw(Data Intensities config.xml) )->slurp ;
#  my $doc = XML::LibXML->new()->parse_string($c);
#  $self->_set_tile_count($doc->getElementsByTagName('Lane')->[0]->getElementsByTagName('Tile')->size());
  return $c;
}

=head2 data_intensities_config_xml_object

The data intensities config.xml as an XML::LibXML::Document object

=cut

has data_intensities_config_xml_object => (
  is => q{ro},
  isa => q{XML::LibXML::Document},
  lazy_build => 1,
);

sub _build_data_intensities_config_xml_object {
  my ($self) = @_;
  return XML::LibXML->new()->parse_string( $self->data_intensities_config() );
}

=head2 is_rta

Is there evidence for Illumina RTA having been run in this folder (useful as it implies single runfolder for paired reads).
This may be set on construction.

  my $bIsRTA => $class->is_rta();

=cut

has is_rta => (
  is => 'ro',
  isa => 'Bool',
  lazy_build => 1,
  documentation => q{This run is an Illumina RTA run},
);

sub _build_is_rta {
  my $self = shift;
  return io(join q(/),$self->runfolder_path, qw(Data Intensities) )->exists;
}

=head2 lane_tile_clustercount

utilises the Data/Intensities/config.xml to generate a hashref of

  {lanes}->{tiles} = clustercount_value

On initialisation, the clustercount may not be available, so it will be left as undef, so this can be used
as a reference to the tile 'names' expected to be found on each lane

=cut

has q{lane_tile_clustercount} => (
  isa => q{HashRef},
  is  => q{ro},
  lazy_build => 1,
);

sub _build_lane_tile_clustercount {
  my ( $self ) = @_;

  my $run_el = ( $self->data_intensities_config_xml_object()->getElementsByTagName( 'Run' ) )[0];

  my $lane_tile_clustercount = {};
  for my $lane_el ( ( $run_el->getChildrenByTagName( 'TileSelection' ) )[0]->getChildrenByTagName( 'Lane' ) ) {
    my $lane = $lane_el->getAttribute( 'Index' );
    for my $tile_el ( $lane_el->getChildrenByTagName( 'Tile' ) ){
      $lane_tile_clustercount->{ $lane }->{ $tile_el->textContent } = undef;
    }
  }

  return $lane_tile_clustercount;
}


1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose::Role

=item Moose::Util::TypeConstraints
=item MooseX::AttributeHelpers

=item strict
=item warnings
=item Readonly
=item Carp
=item English qw{-no_match_vars}

=item List::Util qw(first sum)
=item IO::All
=item XML::LibXML

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: mg8 $

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 Andy Brown (ajb@sanger.ac.uk)

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

#########
# Author:        Marina Gourtovaia
# Created:       20 July 2011
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/st/api/lims.pm, r16549
#

package st::api::lims::xml;

use Carp;
use English qw(-no_match_vars);
use Moose;
use MooseX::StrictConstructor;
use XML::LibXML;
use Readonly;

use npg::api::run;
use st::api::batch;
use npg_tracking::util::types;

with qw/  npg_tracking::glossary::run
          npg_tracking::glossary::lane
          npg_tracking::glossary::tag
       /;

=head1 NAME

st::api::lims::xml

=head1 SYNOPSIS

 $lims = st::api::lims::xml->new(id_run => 333) #run (batch) level object
 $lims = st::api::lims::xml->new(batch_id => 222) # as above
 $lims = st::api::lims::xml->new(batch_id => 222, position => 3) # lane level object
 $lims = st::api::lims::xml->new(id_run => 333, position => 3, tag_index => 44) # plex level object

=head1 DESCRIPTION

Gateway to Sequencescape LIMS.

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar our $BAD_SAMPLE_ID     => 4;
Readonly::Scalar our $PROC_NAME_INDEX   => 3;
Readonly::Hash   our %QC_EVAL_MAPPING   => {'pass' => 1, 'fail' => 0, 'pending' => undef, };
Readonly::Array  our @LIMS_OBJECTS      => qw/sample study project/;

Readonly::Hash our %DELEGATION      => {
    'sample'       => {
                           sample_name              => 'name',
                           organism_taxon_id        => 'taxon_id',
                           organism                 => 'organism',
                           sample_common_name       => 'common_name',
                           sample_public_name       => 'public_name',
                           sample_accession_number  => 'accession_number',
                           sample_consent_withdrawn => 'consent_withdrawn',
                           sample_description       => 'description',
                     },
    'study'        => {
                           study_name                   => 'name',
                           email_addresses              => 'email_addresses',
                           email_addresses_of_managers  => 'email_addresses_of_managers',
                           email_addresses_of_followers => 'email_addresses_of_followers',
                           email_addresses_of_owners    => 'email_addresses_of_owners',
                           alignments_in_bam            => 'alignments_in_bam',
                           study_accession_number       => 'accession_number',
                           study_title                  => 'title',
                           study_description            => 'description',
    },
    'project'      => {
                           project_name      => 'name',
                           project_cost_code => 'project_cost_code',
    },
};

=head2 id_run

Run id, optional attribute. If not set, batch_id should be set.

=cut
has '+id_run'   =>        (required        => 0,);

=head2 position

Position, optional attribute.

=cut
has '+position' =>        (required        => 0,);

=head2 batch_id

Batch id, optional attribute. If not set, id_run should be set.

=cut
has 'batch_id'  =>        (isa             => 'NpgTrackingPositiveInt',
                           is              => 'ro',
                           lazy_build      => 1,
                          );
sub _build_batch_id {
  my $self = shift;

  if ($self->id_run) {
    return $self->npg_api_run->batch_id;
  }
  croak q[Cannot build batch_id: id_run is not supplied];
}

=head2 npg_api_run

np::api::run object when id_run given, otherwise undefined

=cut
has 'npg_api_run'  => (isa             => 'Maybe[npg::api::run]',
                       is              => 'ro',
                       lazy_build      => 1,
                      );

sub _build_npg_api_run {
   my $self = shift;

   my $run_obj = undef;
   if ( $self->id_run ) {
     $run_obj = npg::api::run->new({id_run => $self->id_run,});
   }
   return $run_obj;
}

has '_lane_elements' =>   (isa             => 'ArrayRef',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build__lane_elements {
  my $self = shift;
  my $doc = st::api::batch->new({id => $self->batch_id,})->read();
  if(!$doc) {
    croak q[Failed to load XML for batch] . $self->batch_id;
  }
  my $lanes = $doc->getElementsByTagName(q[lanes])->[0];
  if (!$lanes) {
    croak q[Lanes element is not defined in batch ] . $self->batch_id;
  }
  my @nodes = $lanes->getElementsByTagName(q[lane]);
  return \@nodes;
}

=head2 _associated_lims

Private accessor, not possible to set from the constructor.
Use associated_lims method.

=cut
has '_associated_lims'  => (isa             => 'Maybe[ArrayRef]',
                            is              => 'ro',
                            init_arg        => undef,
                            lazy_build      => 1,
                            clearer         => 'free_children',
                           );
sub _build__associated_lims {
  my $self = shift;

  my $lims = [];

  if (!defined $self->position) {
    foreach my $lane_el (@{$self->_lane_elements}) {
      my $position = $lane_el->getAttribute(q[position]);
      if (!$position) {
        croak q[Position is not defined for one of the lanes in batch ] . $self->batch_id;
      }

      my $h = {
                batch_id          => $self->batch_id,
                position          => $position,
                _lane_xml_element => $lane_el,
              };
      if (defined $self->id_run) { $h->{id_run} = $self->id_run; }
      push @{$lims}, st::api::lims::xml->new($h);
    }
  } else {
    if ($self->is_pool && !$self->tag_index) { #now use XPath to find tag indexes for lane...:
      foreach my $tag_index (sort {$a <=> $b} map{$_->textContent}$self->_lane_xml_element->findnodes(q(*/sample/tag/index))) {
        my $h = {
                  batch_id          => $self->batch_id,
                  position          => $self->position,
                  tag_index         => $tag_index,
                  _lane_xml_element => $self->_lane_xml_element,
                };
        if (defined $self->id_run) { $h->{id_run} = $self->id_run; }
        push @{$lims}, st::api::lims::xml->new($h);
      }
    }
  }
  return $lims;
}

=head2 _lane_xml_element

Private accessor. XML::LibXML::Element fragment of batch xml representing a lane.
Build only if the position accessor is set.

=cut
has '_lane_xml_element' => (isa             => 'Maybe[XML::LibXML::Element]',
                            is              => 'ro',
                            lazy_build      => 1,
                           );
sub _build__lane_xml_element {
  my $self = shift;

  if (!defined $self->position) { return; }

  foreach my $lane_el (@{$self->_lane_elements}) {
    if($self->position == $lane_el->getAttribute(q[position])) {
      return $lane_el;
    }
  }
  croak q[Lane ] . $self->position . q[ is not defined in ] . $self->to_string;
}

=head2 _entity_xml_element

Private accessor. XML::LibXML::Element fragment of batch xml representing a low-lelel entity,
such as library, whether a whole lane, a plex, a control, or spiked phix.
Build only if the position accessor is set.

=cut
has '_entity_xml_element' => (isa             => 'Maybe[XML::LibXML::Element]',
                              is              => 'ro',
                              init_arg        => undef,
                              lazy_build      => 1,
                             );
sub _build__entity_xml_element {
  my $self = shift;

  if (!$self->_lane_xml_element) { return; }

  my $element;
  my $is_control = $self->_lane_xml_element->getChildrenByTagName(q[control]) ? 1 : 0;
  my $has_pool_element = $self->_lane_xml_element->getChildrenByTagName(q[pool]) ? 1 :0;
  my $is_pool = ! defined $self->tag_index && $has_pool_element ? 1 :0;

  my $plexes =
    $has_pool_element ? $self->_lane_xml_element->getElementsByTagName(q[sample]) : undef;
  if ($self->tag_index) {
    if (!$plexes || !@{$plexes}) {
      croak 'No plexes defined for lane ' . $self->position . q[ in batch ] . $self->batch_id;
    }
    if ($plexes) {
      foreach my $plex (@{$plexes}) {
        my $iel = $plex->getElementsByTagName(q[index]);
        if ($iel) {
          my $index = $iel->[0]->textContent();
          if($self->tag_index == $index) {
            $element = $plex;
            $is_control ||= $plex->parentNode->nodeName() eq q{hyb_buffer} ? 1 : 0;
            last;
          }
          	      }
      }
    }

    if (!$element) {
      my $buffer = $self->_lane_xml_element->getChildrenByTagName(q[hyb_buffer]);
      if ($buffer) {
        $buffer = $buffer->[0];
        my $el = $buffer->getElementsByTagName(q[index]);
        if ($el) {
          if ($el->[0]->textContent() == $self->tag_index) {
            $is_control = 1;
            $element = $buffer;
          }
        }
      }
    }

    if (!$element) {
      croak q[No tag with index ] . $self->tag_index . q[ in lane ] . $self->position . q[ batch ] . $self->batch_id;
    }
  } else {
    $is_pool = $plexes ? 1 : 0;
    my $control = $self->_lane_xml_element->getChildrenByTagName(q[control]);
    if ($control && @{$control}) {
      $element = $control->[0];
      $is_control = 1;
    } else {
      my $ename = $is_pool ? q[pool] : q[library];
      $element = $self->_lane_xml_element->getChildrenByTagName($ename)->[0];
    }
  }

  $self->_set_is_control($is_control);
  $self->_set_is_pool($is_pool);

  return $element;
}

=head2 _subentity_xml_element

Private accessor. XML::LibXML::Element fragment of batch xml representing a sample element
(where available) within _entity_xml_element.
Build only if the position accessor is set.

=cut
has '_subentity_xml_element' => (isa             => 'Maybe[XML::LibXML::Element]',
                                 is              => 'ro',
                                 init_arg        => undef,
                                 lazy_build      => 1,
                                );
sub _build__subentity_xml_element {
  my $self = shift;

  if (!$self->_entity_xml_element || $self->is_pool || defined $self->tag_index) { return; }
  my $subentity = $self->_entity_xml_element->getChildrenByTagName(q[sample])->[0] || undef;
  return $subentity;
}

=head2 default_tag_sequence

Read-only string accessor, not possible to set from the constructor.
Undefined on a lane level and for zero tag_index.

=cut
has 'default_tag_sequence' =>    (isa             => 'Maybe[Str]',
                          is              => 'ro',
                          init_arg        => undef,
                          lazy_build      => 1,
                         );
sub _build_default_tag_sequence {
  my $self = shift;
  my $seq;
  if ($self->tag_index) {
    if (!$seq && $self->_entity_xml_element) {
      my $sel = $self->_entity_xml_element->getElementsByTagName(q[expected_sequence]);
      if ($sel) {
        $seq = $sel->[0]->textContent();
      }
    }
  }
  return $seq;
}

=head2 spiked_phix_tag_index

Read-only integer accessor, not possible to set from the constructor.
Defined only on a lane level if the lane is spiked with phix

=cut
has 'spiked_phix_tag_index' =>  (isa             => 'Maybe[NpgTrackingTagIndex]',
                                 is              => 'ro',
                                 init_arg        => undef,
                                 lazy_build      => 1,
                                );
sub _build_spiked_phix_tag_index {
  my $self = shift;

  if ($self->_lane_xml_element) {
    my $buffer = $self->_lane_xml_element->getElementsByTagName(q[hyb_buffer]);
    if ($buffer) {
      my $el = $buffer->[0]->getElementsByTagName(q[index]);
      if ($el) {
        return $el->[0]->textContent();
      } else {
        croak 'should be spiked phix, but tag index is not defined';
      }
    }
  }
  return;
}

=head2 is_control

Read-only boolean accessor, not possible to set from the constructor.
True for a control lane and for the spiked phix plex, otherwise false.

=cut
has 'is_control' =>       (isa             => 'Bool',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                           writer          => '_set_is_control',
                          );
sub _build_is_control {
  my $self = shift;
  return $self->_entity_xml_element ? $self->is_control : 0;
}

=head2 is_pool

Read-only boolean accessor, not possible to set from the constructor.
True for a pooled lane on a lane level, otherwise false.

=cut
has 'is_pool' =>          (isa             => 'Bool',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                           writer          => '_set_is_pool',
                          );
sub _build_is_pool {
  my $self = shift;
  return $self->_entity_xml_element ? $self->is_pool : 0;
}

has 'bait_name' => (isa        => 'Maybe[Str]',
                    is         => 'ro',
                    init_arg   => undef,
                    lazy_build => 1,
                   );

=head2 bait_name

Read-only accessor, not possible to set from the constructor.
Returns the name of the bait if given. For a pooled lane, for a control of if no bait given,
returns undefined value.

=cut
sub _build_bait_name {
   my $self = shift;

   my $bait_name;
   if (!$self->is_pool && !$self->is_control && $self->_entity_xml_element) {
      my $be = $self->_entity_xml_element->getElementsByTagName(q[bait]);
      if ($be) {
        $be = $be->[0]->getElementsByTagName('name');
        if ($be) {
	  $bait_name = $be->[0]->textContent();
	}
      }
   }
   $bait_name ||= undef;
   return $bait_name;
}

=head2 lane_id

For a lane level object returns the unique id (asset id) of the lane,
for other levels undefined. Read-only accessor, not possible to set from the constructor.

=cut
has 'lane_id' =>                 ( isa        => 'Maybe[Int]',
                                   is         => 'ro',
                                   init_arg   => undef,
                                   lazy_build => 1,
                                 );
sub _build_lane_id {
  my $self = shift;

  my $id;
  if ( defined $self->position() && !defined $self->tag_index() ) {
    $id = $self->_lane_xml_element()->getAttribute('id');
  }
  $id ||= undef;
  return $id;
}

=head2 lane_priority

For a lane level object returns this lane priority,
for other levels undefined. Read-only accessor, not possible to set from the constructor.

=cut
has 'lane_priority' =>           ( isa        => 'Maybe[Int]',
                                   is         => 'ro',
                                   init_arg   => undef,
                                   lazy_build => 1,
                                 );
sub _build_lane_priority {
  my $self = shift;

  my $id = undef;
  if ( defined $self->position() && !defined $self->tag_index() ) {
    $id = $self->_lane_xml_element()->getAttribute('priority');
  }
  return $id;
}

=head2 library_id

Read-only accessor, not possible to set from the constructor.

=cut
has 'library_id' =>       (isa             => 'Maybe[Int]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_library_id {
  my $self = shift;

  if(!$self->_xml_element_exists(q[entity])) { return; }

  my $id = $self->_entity_xml_element->getAttribute('id');
  if (!$id) {
    $id = $self->_entity_xml_element->getAttribute('library_id');
  }
  $id ||= undef;
  return $id;
}

=head2 library_name

Read-only accessor, not possible to set from the constructor.

=cut
has 'library_name' =>     (isa             => 'Maybe[Str]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_library_name {
  my $self = shift;

  if(!$self->_xml_element_exists(q[entity])) { return; }

  my $name;
  my $element = $self->_entity_xml_element;
  if ($self->is_pool) {
    $name = $element->getAttribute(q[name]);
  } else {
    if (!$self->tag_index) {
      $element = $self->_subentity_xml_element;
    }
    if ($element) {
      $name = $element->getAttribute(q[library_name]);
    }
  }
  $name ||= undef;
  return $name;
}

=head2 default_library_type

Read-only accessor, not possible to set from the constructor.

=cut
has 'default_library_type' =>     (isa             => 'Maybe[Str]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_default_library_type {
  my $self = shift;

  if(!$self->_xml_element_exists(q[entity]) || $self->is_pool) { return; }

  my $element = $self->tag_index ? $self->_entity_xml_element : $self->_subentity_xml_element;
  my $type;
  if ($element) {
    $type = $element->getAttribute(q[library_type]);
  }
  $type ||= undef;
  return $type;
}

=head2 sample_id

Read-only accessor, not possible to set from the constructor.

=cut
has 'sample_id' =>        (isa             => 'Maybe[Int]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_sample_id {
  my $self = shift;

  if(!$self->_xml_element_exists(q[entity])) { return; }

  my $sample_id = $self->_entity_xml_element->getAttribute(q[sample_id]);
  if (!$sample_id && $self->_subentity_xml_element) {
    $sample_id = $self->_subentity_xml_element->getAttribute(q[sample_id]);
  }
  if ($sample_id && $sample_id == $BAD_SAMPLE_ID) {
      warn qq[Resetting magic sample id $BAD_SAMPLE_ID to undef\n];
    $sample_id = undef;
  }
  $sample_id ||= undef;
  return $sample_id;
}

=head2 study_id

Read-only accessor, not possible to set from the constructor.

=cut
has 'study_id' =>         (isa             => 'Maybe[Int]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_study_id {
  my $self = shift;
  if(!$self->_xml_element_exists(q[entity])) { return; }
  my $study_id =  $self->_entity_xml_element->getAttribute(q[study_id]);
  if (!$study_id && $self->_subentity_xml_element) {
    $study_id = $self->_subentity_xml_element->getAttribute(q[study_id]);
  }
  $study_id ||= undef;
  return $study_id;
}

=head2 project_id

Read-only accessor, not possible to set from the constructor.

=cut
has 'project_id' =>       (isa             => 'Maybe[Int]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_project_id {
  my $self = shift;

  if(!$self->_xml_element_exists(q[entity])) { return; }
  my $project_id = $self->_entity_xml_element->getAttribute(q[project_id]);
  if (!$project_id && $self->_subentity_xml_element) {
    $project_id = $self->_subentity_xml_element->getAttribute(q[project_id]);
  }
  $project_id ||= undef;
  return $project_id;
}

=head2 request_id

Read-only accessor, not possible to set from the constructor.

=cut
has 'request_id' =>       (isa             => 'Maybe[Int]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_request_id {
  my $self = shift;

  if(!$self->_xml_element_exists(q[entity])) { return; }
  my $request_id = $self->_entity_xml_element->getAttribute(q[request_id]) || undef;
  return $request_id;
}

=head2 seq_qc_state

Read-only accessor, not possible to set from the constructor.
Returned 1 for passes, 0 for failed, indef if the value is not set.

=cut
has 'seq_qc_state' =>     (isa             => 'Maybe[Bool]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_seq_qc_state {
  my $self = shift;

  if(!$self->_xml_element_exists(q[entity])) { return; }
  my $mqc = $self->_entity_xml_element->getAttribute(q[qc_state]);
  if ($mqc) {
    if (!exists  $QC_EVAL_MAPPING{$mqc}) {
      croak qq[Unexpected value '$mqc' for seq qc state in ] . $self->to_string;
    }
    return $QC_EVAL_MAPPING{$mqc};
  }
  return;
}

sub _build__library_object {
  my $self = shift;
  return $self->_lims_object(q[library]);
}
sub _build__sample_object {
  my $self = shift;
  return $self->_lims_object(q[sample]);
}
sub _build__study_object {
  my $self = shift;
  return $self->_lims_object(q[study]);
}
sub _build__project_object {
  my $self = shift;
  return $self->_lims_object(q[project]);
}
sub _build__request_object {
  my $self = shift;
  return $self->_lims_object(q[request]);
}

foreach my $object_type ( @LIMS_OBJECTS ) {

  my $st_type = $object_type eq q[library] ? q[asset] : $object_type;
  my $isa = q{Maybe[st::api::} . $st_type . q{]};
  my $attr_name =  join q[_], q[], $object_type, q[object];
  has $attr_name => ( is => 'ro', isa => $isa, init_arg => undef, lazy_build => 1, handles => $DELEGATION{$object_type});

  if (scalar keys %{$DELEGATION{$object_type}} == 0) { next; }
  for my $func (keys %{$DELEGATION{$object_type}}) {
    around $func => sub {
      my ($orig, $self) = @_;
      return $self->$attr_name ? $self->$orig() : undef;
    };
  }
}

=head2 required_insert_size_range

Read-only accessor, not possible to set from the constructor.
Returns a has reference of expected insert sizes.

=cut
has 'required_insert_size_range'  => (isa             => 'HashRef',
                                is              => 'ro',
                                init_arg        => undef,
                                lazy_build      => 1,
                               );
sub _build_required_insert_size_range {
  my $self = shift;

  my $is_hash = {};
  if (!$self->is_control) {
   my $is_element = $self->_entity_xml_element->getElementsByTagName(q[insert_size]);
   if ($is_element) {
      $is_element = $is_element->[0];
   }
   if ($is_element) {
      foreach my $key (qw/to from/) {
        my $value = $is_element->getAttribute($key);
        if ($value) {
	  $is_hash->{$key} = $value;
        }
      }
    }
  }
  return $is_hash;
}

=head2 sample_reference_genome

Read-only accessor, not possible to set from the constructor.
Returns sample reference genome

=cut
has 'sample_reference_genome' => (isa             => 'Maybe[Str]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_sample_reference_genome {
  my $self = shift;
  my $rg;
  if ($self->_sample_object) {
    $rg = $self->_sample_object->reference_genome;
  }
  return $rg;
}

=head2 study_reference_genome

Read-only accessor, not possible to set from the constructor.
Returns study reference genome

=cut
has 'study_reference_genome' => (isa             => 'Maybe[Str]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_study_reference_genome {
  my $self = shift;
  my $rg;
  if ($self->_study_object) {
    $rg = $self->_study_object->reference_genome;
  }
  return $rg;
}

=head2 study_contains_nonconsented_human

Read-only accessor, not possible to set from the constructor.
For a library, control on non-zero plex returns the value of the
contains_nonconsented_human on the relevant study object. For a pool
or a zero plex returns 1 if any of the studies in the pool
contein unconcented human.

On a batch level or if no associated study found, returns 0.

=cut
has 'study_contains_nonconsented_human' => (isa             => 'Bool',
                                      is              => 'ro',
                                      init_arg        => undef,
                                      lazy_build      => 1,
                                     );
sub _build_study_contains_nonconsented_human {
  my $self = shift;

  my $cuh = 0;
  if ($self->position && $self->_study_object) {
    $cuh = $self->_study_object->contains_nonconsented_human;
  }
  if (!$cuh) { $cuh = 0; }
  return $cuh;
}

=head2 study_contains_nonconsented_xahuman

Read-only accessor, not possible to set from the constructor.
For a library, control on non-zero plex returns the value of the
contains_nonconsented_xahuman on the relevant study object. For a pool
or a zero plex returns 1 if any of the studies in the pool
contain unconcented X and autosomal human.

On a batch level or if no associated study found, returns 0.

=cut
has 'study_contains_nonconsented_xahuman' => (isa             => 'Bool',
                                        is              => 'ro',
                                        init_arg        => undef,
                                        lazy_build      => 1,
                                       );
sub _build_study_contains_nonconsented_xahuman {
  my $self = shift;

  my $cuh = 0;
  if ($self->position && $self->_study_object) {
    $cuh = $self->_study_object->contains_nonconsented_xahuman;
  }
  if (!$cuh) { $cuh = 0; }
  return $cuh;
}

=head2 children

Method returning a list of st::api::lims::xml objects that are associated with this object
and belong to the next (one lower) level. An empty list for a non-pool lane and for a plex.
For a pooled lane contains plex-level objects. On a batch level, when the position 
accessor is not set, returns lane level objects.

=cut
sub children {
  my $self = shift;
  return @{$self->_associated_lims};
}


=head2 method_list

Method returning a sorted list of useful accessors and methods.

=cut
sub method_list {
  my $self = shift;
  my @attrs = ();
  foreach my $name (__PACKAGE__->meta->get_attribute_list) {
    if ($name =~ /^\_/smx) {
      next;
    }
    push @attrs, $name;
  }

  foreach my $object_type ( @LIMS_OBJECTS ) {
    my @functions = keys %{$DELEGATION{$object_type}};
    if (@functions) {
      push @attrs, @functions;
    }
  }

  @attrs = sort @attrs;
  return @attrs;
}

sub _lims_object {
  my ($self, $object_type) = @_;

  my $class = q[st::api::] . $object_type;
  my $method = join q[_], $object_type, q[id];
  my $id = $self->$method;

  if ($id) {
    ## no critic (ProhibitStringyEval RequireCheckingReturnValueOfEval)
    eval "require $class";
    ## use critic
    return $class->new({id => $id,});
  }
  return;
}

sub _xml_element_exists {
  my ($self, $el_type) = @_;

  if ($el_type ne q[lane] && $el_type ne q[entity]) {
    croak qq[Unknown xml element type $el_type in _validate_xml_element];
  }

  my $attr = join q[_], q[], $el_type, q[xml], q[element];
  if(!$self->$attr) {
    if ($self->position) {
      croak qq[$attr attribute not defined in ] . $self->to_string;
    }
    return 0;
  }
  return 1;
}

=head2 to_string

Human friendly description of the object

=cut
sub to_string {
  my $self = shift;

  my $s = __PACKAGE__ . q[ object for batch ] . $self->batch_id;
  if (defined $self->position) {
    $s .= q[ position ] . $self->position;
  }
  if (defined $self->tag_index) {
    $s .= q[ tag_index ] . $self->tag_index;
  }
  return $s;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item Carp

=item English

=item Readonly

=item XML::LibXML

=item npg::api::run

=item st::api::batch

=item npg_tracking::util::types

=item npg_tracking::glossary::run

=item npg_tracking::glossary::lane

=item npg_tracking::glossary::tag

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Marina Gourtovaia

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
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

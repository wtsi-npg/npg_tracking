#######
# Author:        Marina Gourtovaia
# Created:       July 2013
# copied from: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/st/api/lims.pm, r16549
#

package st::api::lims;

use Carp;
use English qw(-no_match_vars);
use Moose;
use MooseX::StrictConstructor;
use MooseX::Aliases;
use MooseX::ClassAttribute;
use Readonly;
use List::MoreUtils qw/none/;

use npg_tracking::util::types;

with qw/  npg_tracking::glossary::run
          npg_tracking::glossary::lane
          npg_tracking::glossary::tag
       /;

=head1 NAME

st::api::lims

=head1 SYNOPSIS

 $lims = st::api::lims->new(id_run => 333) #run (batch) level object
 $lims = st::api::lims->new(batch_id => 222) # as above
 $lims = st::api::lims->new(batch_id => 222, position => 3) # lane level object
 $lims = st::api::lims->new(id_run => 333, position => 3, tag_index => 44) # plex level object

=head1 DESCRIPTION

Generic NPG pipeline oriented LIMS wrapper capable of retrieving data from multiple sources
(drivers).

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar my  $PROC_NAME_INDEX   => 3;
Readonly::Hash   my  %QC_EVAL_MAPPING   => {'pass' => 1, 'fail' => 0, 'pending' => undef, };
Readonly::Scalar my  $INLINE_INDEX_END  => 10;

Readonly::Hash   my  %METHODS           => {

    'general'    =>   [qw/ spiked_phix_tag_index
                           is_control
                           is_pool
                           bait_name
                           default_tag_sequence
                           required_insert_size_range
                           qc_state
                      /],

    'lane'         => [qw/ lane_id
                           lane_priority
                      /],

    'library'      => [qw/ library_id
                           library_name
                           default_library_type
                      /],

    'sample'       => [qw/ sample_id
                           sample_name
                           organism_taxon_id
                           organism
                           sample_common_name
                           sample_public_name
                           sample_accession_number
                           sample_consent_withdrawn
                           sample_description
                           sample_reference_genome
                      /],

    'study'        => [qw/ study_id
                           study_name
                           email_addresses
                           email_addresses_of_managers
                           email_addresses_of_followers
                           email_addresses_of_owners
                           alignments_in_bam
                           study_accession_number
                           study_title
                           study_description
                           study_reference_genome
                           study_contains_nonconsented_xahuman
                           study_contains_nonconsented_human
                           separate_y_chromosome_data
                      /],

    'project'      => [qw/ project_id
                           project_name
                           project_cost_code
                      /],

    'request'      => [qw/ request_id
                      /],
};

Readonly::Array  my @IMPLEMENTED_DRIVERS => qw/xml samplesheet/;
Readonly::Array our @DELEGATED_METHODS => sort map { @{$_} } values %METHODS;

=head2 driver_type

Driver type (xml, etc), currently defaults to xml

=cut
has 'driver_type' => (
                        isa     => 'Str',
                        is      => 'ro',
                        default => $IMPLEMENTED_DRIVERS[0],
                     );

=head2 driver

Driver object (xml, warehouse, samplesheet)

=cut
has 'driver' => (
                          'is'      => 'ro',
                          'lazy'    => 1,
                          'builder' => '_build_driver',
);
sub _build_driver {
  my $self = shift;
  my $d_package = $self->_driver_package_name;
  ##no critic (ProhibitStringyEval RequireCheckingReturnValueOfEval)
  eval "require $d_package";
  ##use critic
  my $ref = {};
  foreach my $attr (qw/tag_index position id_run path/) {
    if (defined $self->$attr) {
      $ref->{$attr} = $self->$attr;
    }
    if ($self->has_batch_id) {
      $ref->{'batch_id'} = $self->batch_id;
    }
  }
  return $d_package->new($ref);
}

sub _driver_package_name {
  my $self = shift;
  my $type = $self->driver_type;
  if (none {$type} @IMPLEMENTED_DRIVERS) {
    croak qq[Driver type '$type' not implemented.\n Implemented drivers: ] .
             join q[,], @IMPLEMENTED_DRIVERS;
  }
  return join q[::], __PACKAGE__ , $type;
}

for my$m ( @DELEGATED_METHODS ){
  __PACKAGE__->meta->add_method($m, sub{my$d=shift->driver; if( $d->can($m) ){ return $d->$m(@_) } return; });
}

=head2 inline_index_end

inlined index end, class method 

=cut
class_has 'inline_index_end' => (isa => 'Int',
                                 is => 'ro',
                                 required => 0,
                                 default => $INLINE_INDEX_END,
                                );

=head2 path

Samplesheet path

=cut
has 'path' => (
                  isa      => 'Str',
                  is       => 'ro',
                  required => 0,
              );

=head2 id_run

Run id, optional attribute.

=cut
has '+id_run'   =>        (required        => 0,);

=head2 position

Position, optional attribute.

=cut
has '+position' =>        (required        => 0,);

=head2 tag_index

Tag index, optional attribute.

=cut

=head2 batch_id

Batch id, optional attribute.

=cut
has 'batch_id'  =>        (isa             => 'NpgTrackingPositiveInt',
                           is              => 'ro',
                           lazy_build      => 1,
                          );
sub _build_batch_id {
  my $self = shift;

  if ($self->id_run) {
    if ($self->driver_type eq 'xml') {
      return $self->driver->batch_id;
    }
    croak q[Cannot build batch_id from id_run for driver type ] . $self->driver_type;
  }
  croak q[Cannot build batch_id: id_run is not supplied];
}

=head2 tag_sequence

Read-only string accessor, not possible to set from the constructor.
Undefined on a lane level and for zero tag_index.

=cut
has 'tag_sequence' =>    (isa             => 'Maybe[Str]',
                          is              => 'ro',
                          init_arg        => undef,
                          lazy_build      => 1,
                         );
sub _build_tag_sequence {
  my $self = shift;
  my $seq;
  if ($self->tag_index) {
    if (!$self->spiked_phix_tag_index || $self->tag_index != $self->spiked_phix_tag_index) {
      if ($self->sample_description) {
        $seq = _tag_sequence_from_sample_description($self->sample_description);
      }
    }
    if (!$seq) {
      return $self->default_tag_sequence;
    }
  }
  return $seq;
}

=head2 tags

Read-only accessor, not possible to set from the constructor.
For a pooled lane returns the mapping of tag indices to tag sequences,
including spiked phix tag index if appropriate. Undefined in other cases.

=cut
has 'tags'                 =>   (isa             => 'Maybe[HashRef]',
                                 is              => 'ro',
                                 init_arg        => undef,
                                 lazy_build      => 1,
                                );

sub _build_tags {
  my $self = shift;
  my $indices  = {};
  foreach my $plex ($self->children) {
    if(my $ti = $plex->tag_index){
      $indices->{$ti} = $plex->tag_sequence;
    }
  }
  if(keys %{$indices}) { return $indices;}
  return;
}


=head2 required_insert_size

Read-only accessor, not possible to set from the constructor.
Returns a has reference of expected insert sizes.

=cut
has 'required_insert_size'  => (isa             => 'HashRef',
                                is              => 'ro',
                                init_arg        => undef,
                                lazy_build      => 1,
                               );
sub _build_required_insert_size {
  my $self = shift;

  my $is_hash = {};
  my $size_element_defined = 0;
  if (defined $self->position && !$self->is_control) {
    my @alims = $self->associated_lims;
    if (!@alims) {
      @alims = ($self);
    }
    foreach my $lims (@alims) {
      $self->_entity_required_insert_size($lims, $is_hash, \$size_element_defined);
    }
  }
  return $is_hash;
}
sub _entity_required_insert_size {
  my ($self, $lims, $is_hash, $isize_defined) = @_;

  if (!$is_hash) {
    croak q[Isize hash ref should be supplied];
  }
  if (!$lims) {
    croak q[Lims object should be supplied];
  }

  if (!$lims->is_control) {
    my $is = $lims->required_insert_size_range;
    if ($is && keys %{$is}) {
      ${$isize_defined} = 1;
      foreach my $key (qw/to from/) {
        my $value = $is->{$key};
        if ($value) {
	  my $lib_key = $lims->library_id || $lims->tag_index || $lims->sample_id;
	  $is_hash->{$lib_key}->{$key} = $value;
        }
      }
    }
  }
  return;
}

=head2 seq_qc_state

 1 for passes, 0 for failed, undef if the value is not set

=cut
sub  seq_qc_state {
  my $self = shift;
  my $state = $self->driver->qc_state;
  if (!defined $state || $state eq '1' || $state eq '0') {
    return $state;
  }
  if ($state eq q[]) {
    return;
  }
  if (!exists  $QC_EVAL_MAPPING{$state}) {
    croak qq[Unexpected value '$state' for seq qc state in ] . $self->to_string;
  }
  return $QC_EVAL_MAPPING{$state};
}

=head2 reference_genome

Read-only accessor, not possible to set from the constructor.
Returns pre-set reference genome, retrieving it either from a sample,
or, failing that, from a study.

=cut
has 'reference_genome' => (isa             => 'Maybe[Str]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_reference_genome {
  my $self = shift;
  my $rg = $self->sample_reference_genome;
  if (!$rg ) {
    $rg = $self->study_reference_genome;
  }
  return $rg;
}

=head2 contains_nonconsented_human

Read-only accessor, not possible to set from the constructor.
For a library, control on non-zero plex returns the value of the
contains_nonconsented_human on the relevant study object. For a pool
or a zero plex returns 1 if any of the studies in the pool
contein unconcented human.

On a batch level or if no associated study found, returns 0.

=cut
has 'contains_nonconsented_human' => (isa             => 'Bool',
                                      is              => 'ro',
                                      init_arg        => undef,
                                      lazy_build      => 1,
                                      alias           => 'contains_unconsented_human',
                                     );
sub _build_contains_nonconsented_human {
  my $self = shift;

  my $cuh = 0;
  if ($self->position) {
    my @lims =  ($self->is_pool && !$self->tag_index) ? $self->children : ($self);
    foreach my $l (@lims) {
      $cuh = $l->study_contains_nonconsented_human;
      if ($cuh) { last; }
    }
  }
  if (!$cuh) { $cuh = 0; }
  return $cuh;
}

=head2 contains_nonconsented_xahuman

Read-only accessor, not possible to set from the constructor.
For a library, control on non-zero plex returns the value of the
contains_nonconsented_xahuman on the relevant study object. For a pool
or a zero plex returns 1 if any of the studies in the pool
contain unconcented X and autosomal human.

On a batch level or if no associated study found, returns 0.

=cut
has 'contains_nonconsented_xahuman' => (isa             => 'Bool',
                                        is              => 'ro',
                                        init_arg        => undef,
                                        lazy_build      => 1,
                                       );
sub _build_contains_nonconsented_xahuman {
  my $self = shift;

  my $cuh = 0;
  if ($self->position) {
    my @lims =  ($self->is_pool && !$self->tag_index) ? $self->children : ($self);
    foreach my $l (@lims) {
      $cuh = $l->study_contains_nonconsented_xahuman;
      if ($cuh) {
        return 1;
      }
    }
  }
  if (!$cuh) { $cuh = 0; }
  return $cuh;
}

has '_cached_children'              => (isa             => 'ArrayRef',
                                        is              => 'ro',
                                        init_arg        => undef,
                                        lazy_build      => 1,
                                       );
sub _build__cached_children {
  my $self = shift;
  my @children = ();
  if($self->driver->can('children')) {
    foreach my $c ($self->driver->children) {
      my $init = {'driver_type' => $self->driver_type, 'driver' => $c};
      foreach my $attr (qw/id_run position tag_index/) {
        if(my $attr_value=$self->$attr || ($c->can($attr) ? $c->$attr : undef)) {
          $init->{$attr}=$attr_value;
        }
      }
      push @children, st::api::lims->new($init);
    }
    if($self->driver->can('free_children')) {
      $self->driver->free_children;
    }
  }
  return \@children;
}

=head2 children

Method returning a list of st::api::lims objects that are associated with this object
and belong to the next (one lower) level. An empty list for a non-pool lane and for a plex.
For a pooled lane contains plex-level objects. On a run level, when the position 
accessor is not set, returns lane level objects.

=cut
sub children {
  my $self = shift;
  return @{$self->_cached_children};
}

=head2 descendants

Method returning a list of all st::api::lims descendants objects for this object.
An empty list for a non-pool lane and for a plex. For a pooled lane contains plex-level
objects. On a run level, when the position accessor is not set, returns objects of both
lane and, if appropriate, plex level.

=cut
sub descendants {
  my $self = shift;
  my @lims = $self->children;
  if (!defined $self->position) {
    foreach my $alims (@lims) {
      push @lims, $alims->children;
    }
  }
  return @lims;
}

=head2 associated_lims

The same as descendants. Retained for backward compatibility

=cut
*associated_lims = \&descendants; #backward compat

=head2 associated_child_lims

The same as children. Retained for backward compatibility

=cut
*associated_child_lims = \&children; #backward compat

=head2 children_ia

Method providing fast (index-based) access to child lims object.
Returns a hash ref of st::api::lims children objects
An empty hash for a non-pool lane and for a plex.
For a pooled lane contains plex-level objects. On a run level, when the position 
accessor is not set, returns lane level objects. The hash keys are lane numbers (positions)
or tag indices. _ia stands for index access.

=cut
sub children_ia {
  my $self = shift;
  my $h = {};
  foreach my $alims ($self->children) {
    my $key = $alims->tag_index ? $alims->tag_index : $alims->position;
    $h->{$key} = $alims;
  }
  return $h;
}

=head2 study_publishable_name

Study publishable name

=cut
sub study_publishable_name {
  my $self = shift;
  return $self->study_accession_number() || $self->study_title() || $self->study_name();
}

=head2 sample_publishable_name

Sample publishable name

=cut
sub sample_publishable_name {
  my $self = shift;
  return $self->sample_accession_number() || $self->sample_public_name() || $self->sample_name();
}

=head2 associated_child_lims_ia

The same as children_ia. Retained for backward compatibility

=cut
*associated_child_lims_ia = \&children_ia; #backward compat

sub _list_of_properties {
  my ($self, $prop, $object_type, $with_spiked_control) = @_;

  if ($object_type !~ /^library|sample|study|project$/smx) {
    croak qq[Invalid object type $object_type in ] . ( caller 0 )[$PROC_NAME_INDEX];
  }
  if ($prop !~ /^name|id$/smx) {
    croak qq[Invalid property $prop in ] . ( caller 0 )[$PROC_NAME_INDEX]
  }

  if (!defined $self->position) { my @l = (); return @l; }

  if (!defined $with_spiked_control) { $with_spiked_control = 1; }
  my $attr_name = join q[_], $object_type, $prop;

  my @objects = ();
  if ($self->is_pool) {
    foreach my $tlims ($self->children) {
      if (!$with_spiked_control && $self->spiked_phix_tag_index && $self->spiked_phix_tag_index == $tlims->tag_index) {
        next;
      }
      push @objects, $tlims;
    }
  } else {
    push @objects, $self;
  }

  my $names_hash = {};
  foreach my $object (@objects) {
    if ($object->$attr_name) {
      $names_hash->{$object->$attr_name} = 1;
    }
  }

  my @l = sort keys %{$names_hash};
  return @l;
}


=head2 library_names

A list of library names. if $self->is_pool is true, returns unique library
names of plex-level objects, otherwise returns object's own library name.
Takes an optional argument with_spiked_control, wich defaults to true.

=cut
sub library_names {
  my ($self, $with_spiked_control) = @_;
  return $self->_list_of_properties(q[name], q[library], $with_spiked_control);
}

=head2 sample_names

A list of sample names. if $self->is_pool is true, returns unique sample
names of plex-level objects, otherwise returns object's own sample name.
Takes an optional argument with_spiked_control, wich defaults to true.

=cut
sub sample_names {
  my ($self, $with_spiked_control) = @_;
  return $self->_list_of_properties(q[name], q[sample], $with_spiked_control);
}

=head2 study_names

A list of study names. if $self->is_pool is true, returns unique study
names of plex-level objects, otherwise returns object's own study name.
Takes an optional argument with_spiked_control, wich defaults to true.

=cut
sub study_names {
  my ($self, $with_spiked_control) = @_;
  return $self->_list_of_properties(q[name], q[study], $with_spiked_control);
}

=head2 library_ids

Similar to library_names, but for ids

=cut
sub library_ids {
  my ($self, $with_spiked_control) = @_;
  return $self->_list_of_properties(q[id], q[library], $with_spiked_control);
}

=head2 sample_ids

Similar to sample_names, but for ids

=cut
sub sample_ids {
  my ($self, $with_spiked_control) = @_;
  return $self->_list_of_properties(q[id], q[sample], $with_spiked_control);
}

=head2 study_ids

Similar to study_names, but for ids

=cut
sub study_ids {
  my ($self, $with_spiked_control) = @_;
  return $self->_list_of_properties(q[id], q[study], $with_spiked_control);
}

=head2 project_ids

A list of project ids, similar to study_ids

=cut
sub project_ids {
  my ($self, $with_spiked_control) = @_;
  return $self->_list_of_properties(q[id], q[project], $with_spiked_control);
}

=head2 library_type

Read-only accessor, not possible to set from the constructor.

=cut
has 'library_type' =>     (isa             => 'Maybe[Str]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_library_type {
  my $self = shift;
  if($self->is_pool) { return; }
  return _derived_library_type($self);
}

sub _derived_library_type {
  my $o = shift;
  my $type = $o->default_library_type;
  if ($o->tag_index && $o->sample_description &&
      _tag_sequence_from_sample_description($o->sample_description)) {
    $type = '3 prime poly-A pulldown';
  }
  $type ||= undef;
  return $type;
}

sub _tag_sequence_from_sample_description {
  my $desc = shift;
  my $tag;
  if ($desc && (($desc =~ m/base\ indexing\ sequence/ismx) && ($desc =~ m/enriched\ mRNA/ismx))){
    ($tag) = $desc =~ /\(([ACGT]+)\)/smx;
  }
  return $tag;
}

=head2 library_types

A list of library types, excluding spiked phix library

=cut
sub library_types {
  my ($self) = @_;
  if (!defined $self->position) { my @l = (); return @l; }

  my @objects = ();
  if ($self->is_pool) {
    foreach my $tlims ($self->children) {
      if ($self->spiked_phix_tag_index && $self->spiked_phix_tag_index == $tlims->tag_index) {
        next;
      }
      push @objects, $tlims;
    }
  } else {
    @objects = ($self);
  }
  my $lt_hash = {};
  foreach my $o (@objects) {
    my $ltype = _derived_library_type($o);
    if ($ltype) {
      $lt_hash->{$ltype} = 1;
    }
  }
  my @t = sort keys %{$lt_hash};
  return @t;
}

=head2 method_list

A sorted list of public accessors (methods and attributes)

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
  push @attrs, @DELEGATED_METHODS;
  @attrs = sort @attrs;
  return @attrs;
}

=head2 to_string

Human friendly description of the object

=cut
sub to_string {
  my $self = shift;

  my $d = ref $self->driver;
  ($d)= $d=~/::(\w+?)\z/smx;
  my $s = __PACKAGE__ . q[ object, driver - ] . $d;
  foreach my $attr (sort qw(id_run batch_id position tag_index)) {
    my $value=$self->$attr;
    if (defined $value){
      $s .= q[, ] . join q[ ], $attr, $value;
    }
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

=item MooseX::Aliases

=item MooseX::ClassAttribute

=item MooseX::StrictConstructor

=item List::MoreUtils

=item Carp

=item English

=item Readonly

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

Copyright (C) 2013 GRL, by Marina Gourtovaia

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

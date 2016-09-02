package st::api::lims;

use Carp;
use Moose;
use MooseX::Aliases;
use Moose::Meta::Class;
use namespace::autoclean;
use Readonly;
use List::MoreUtils qw/any none uniq/;
use Class::Load qw/load_class/;

use npg_tracking::util::types;
use npg_tracking::glossary::rpt;

our $VERSION = '0';

=head1 NAME

st::api::lims

=head1 SYNOPSIS

 $lims = st::api::lims->new(id_run => 333);   #run (batch) level object
 $lims = st::api::lims->new(batch_id => 222); # as above
 $lims = st::api::lims->new(batch_id => 222, position => 3); # lane level object
 $lims = st::api::lims->new(id_run => 333, position => 3, tag_index => 44); # plex level object
 $lims = st::api::lims->new(rpt_list => '333:3:44'); # object for a one-component composition
 $lims = st::api::lims->new(rpt_list => '333:3:44;333:4:44;'); # object for a two-component composition
 $lims = st::api::lims->new(driver_type => q(ml_warehouse), flowcell_barcode => q(HTC3HADXX),
                            position => 2, tag_index => 40); # plex level object from ml_warehouse
 $lims = st::api::lims->new(driver_type => q(ml_warehouse), flowcell_barcode => q(HTC3HADXX),
                            position => 2, tag_index => 40, mlwh_schema=>$suitable_dbic_schema);

=head1 DESCRIPTION

Generic NPG pipeline oriented LIMS wrapper capable of retrieving data from multiple sources
(drivers). Provides methods performing "business" logic independent of data source.

Note the set of valid arguments to the constructor are a function of the driver_type passed.

Any driver attribute can be passed through to the driver's constructor via this objects's
constructor. Not all of the attributes passed through to the driver will be available
as this object's accessors. Example:

 $lims = st::api::lims->new(
                             id_flowcell_lims => 34567,
                             position         => 5,
                             driver_type      => 'ml_warehouse',
                             iseq_flowcell    => $iseq_flowcell
                           );
 print $lims->position();         # 5
 print $lims->id_flowcell_lims(); # 34567
 print $lims->driver_type;        # ml_warehouse
 print $lims->iseq_flowcell();    # ERROR

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar our $CACHED_SAMPLESHEET_FILE_VAR_NAME => 'NPG_CACHED_SAMPLESHEET_FILE';
Readonly::Scalar my $DEFAULT_DRIVER_TYPE              => 'xml';
Readonly::Scalar my $SAMPLESHEET_DRIVER_TYPE          => 'samplesheet';

Readonly::Scalar my $PROC_NAME_INDEX       => 3;
Readonly::Hash   my %QC_EVAL_MAPPING       => {'pass' => 1, 'fail' => 0, 'pending' => undef, };
Readonly::Scalar my $INLINE_INDEX_END      => 10;
Readonly::Scalar my $DUAL_INDEX_TAG_LENGTH => 16;

Readonly::Hash   my  %METHODS_PER_CATEGORY => {
    'primary'    =>   [qw/ tag_index
                           position
                           id_run
                           path
                           id_flowcell_lims
                           batch_id
                           flowcell_barcode
                           rpt_list
                      /],

    'general'    =>   [qw/ spiked_phix_tag_index
                           is_pool
                           is_control
                           bait_name
                           default_tag_sequence
                           default_tagtwo_sequence
                           required_insert_size_range
                           qc_state
                           purpose
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
                           sample_supplier_name
                           sample_cohort
                           sample_donor_id
                      /],

    'study'        => [qw/ study_id
                           study_name
                           email_addresses
                           email_addresses_of_managers
                           email_addresses_of_followers
                           email_addresses_of_owners
                           study_alignments_in_bam
                           study_accession_number
                           study_title
                           study_description
                           study_reference_genome
                           study_contains_nonconsented_xahuman
                           study_contains_nonconsented_human
                           study_separate_y_chromosome_data
                      /],

    'project'      => [qw/ project_id
                           project_name
                           project_cost_code
                      /],

    'request'      => [qw/ request_id /],
};

Readonly::Array my @METHODS             => sort map { @{$_} } values %METHODS_PER_CATEGORY;
Readonly::Array my @DELEGATED_METHODS   => sort map { @{$METHODS_PER_CATEGORY{$_}} }
                                             grep {$_ ne 'primary'} keys %METHODS_PER_CATEGORY;

has '_driver_arguments' => (
                        isa      => 'HashRef',
                        is       => 'ro',
                        init_arg => undef,
                        writer   => '_set__driver_arguments',
                        default  => sub { {} },
);

has '_primary_arguments' => (
                        isa      => 'HashRef',
                        is       => 'ro',
                        init_arg => undef,
                        writer   => '_set__primary_arguments',
                        default  => sub { {} },
);

=head2 BUILD

Custom post construction method to help propagate varied arguments to driver constructors

=cut
sub BUILD {
  my $self = shift;
  my %args = %{shift||{}};
  delete $args{'driver'}; # better not to have this extra reference
  $self->_set__driver_arguments(\%args);
  my %dargs=();
  my %pargs=();
  my %primary_arg_type = map {$_ => 1} @{$METHODS_PER_CATEGORY{'primary'}};

  my $driver_class=$self->_driver_package_name;

  foreach my$k (grep {defined && $_ !~ /^_/smx} map{ $_->has_init_arg ? $_->init_arg : $_->name}
                $driver_class->meta->get_all_attributes) {
    if(exists $args{$k}){
      $dargs{$k}=$args{$k};
      if ( not $primary_arg_type{$k} ){ #allow caching of primary args later even if driver provides methods - important for when passing tag_index=>0 and a lane level lims driver object to constructor
        delete $args{$k};
      }
    }
  }
  $self->_set__driver_arguments(\%dargs);

  foreach my$k (grep {defined} map{$_->has_init_arg ? $_->init_arg : $_->name}
      __PACKAGE__->meta->get_all_attributes) {
    delete $args{$k};
  }

  #only allow primary args - to recreate Strictness of constructor
  foreach my$k( @{$METHODS_PER_CATEGORY{'primary'}} ) {
    if(exists $args{$k}) {
      $pargs{$k}=$args{$k};
      delete $args{$k};
    }
  }
  croak 'Unknown attributes: '.join q(, ), keys %args if keys %args;
  $self->_set__primary_arguments(\%pargs);
  return;
}

# Mapping of LIMS object types to attributes for which methods are to
# be generated. These generated methods are 'plural' methods which
# return an array of that attributes e.g. $lims->library_ids (returns
# an array of library_id values), $lims->sample_public_names (returns
# an array of of sample_public_name values).
Readonly::Hash my %ATTRIBUTE_LIST_METHODS => {
    'library'      => [qw/ id
                           name
                         /],
    'project'      => [qw/ id

                         /],
    'sample'       => [qw/ accession_number
                           cohort
                           common_name
                           donor_id
                           id
                           name
                           public_name
                           supplier_name
                         /],
    'study'        => [qw/ accession_number
                           id
                           name
                           title
                         /]
};

foreach my $object_type (keys %ATTRIBUTE_LIST_METHODS) {
  foreach my $property (@{$ATTRIBUTE_LIST_METHODS{$object_type}}) {
    my $attr_name   = join q[_], $object_type, $property;
    my $method_name = $attr_name . q[s];

    my $method_body = sub {
      my ($self, $with_spiked_control) = @_;

      return $self->_list_of_attributes($attr_name, $with_spiked_control);
    };

    __PACKAGE__->meta->add_method($method_name, $method_body);
  }
}

=head2 driver_type

Driver type (xml, etc), currently defaults to xml

=cut
has 'driver_type' => ( isa        => 'Str',
                       is         => 'ro',
                       lazy_build => 1,
                       writer     => '_set_driver_type',
                     );
sub _build_driver_type {
  my $self = shift;
  if($self->has_driver && $self->driver){
    my $type = ref $self->driver;
    my $prefix = __PACKAGE__ . q(::);
    $type =~ s/\A\Q$prefix\E//smx;
    return $type;
  }

  if ($ENV{$CACHED_SAMPLESHEET_FILE_VAR_NAME}) {
    return $SAMPLESHEET_DRIVER_TYPE;
  }

  return $DEFAULT_DRIVER_TYPE;
}

=head2 driver

Driver object (xml, warehouse, mlwarehouse, samplesheet ...)

=cut
has 'driver' => ( 'isa'       => 'Maybe[Object]',
                  'is'        => 'ro',
                  'lazy'      => 1,
                  'builder'   => '_build_driver',
                  'predicate' => 'has_driver',
                );
sub _build_driver {
  my $self = shift;
  if (!$self->_primary_arguments->{'rpt_list'}) {
    return $self->_driver_package_name()->new($self->_driver_arguments());
  }
  return;
}

sub _driver_package_name {
  my $self = shift;
  my $class = join q[::], __PACKAGE__ , $self->driver_type;
  load_class($class);
  return $class;
}

for my $m ( @METHODS ){
  __PACKAGE__->meta->add_method($m, sub{
    my $l = shift;
    if(exists $l->_primary_arguments()->{$m}){
      return $l->_primary_arguments()->{$m};
    }
    my $d = $l->driver;
    my $r = ($d && $d->can($m)) ? $d->$m(@_) : undef;
    if( defined $r and length $r){ #if method exists and it returns a defined and non-empty result
      return $d->$m(@_); # call again here in case it returns different info in list context
    }
    if($m eq q(is_pool)){ # avoid obvious recursion
      if($l->_primary_arguments()->{'rpt_list'}){
        return;
      }
      return scalar $l->children;
    }
    if(any {$_ eq $m} @{$METHODS_PER_CATEGORY{'primary'}} ){
      return $r;
    }
    if($l->is_pool || $l->is_composition){ # else try any children
      return $l->_single_attribute($m,0); # 0 to ignore spike
    }
    return;
  });
}

=head2 is_composition

=cut

sub is_composition {
  my $self = shift;
  return $self->rpt_list ? 1 : 0;
}

=head2 inline_index_read

index read

=cut

has 'inline_index_read' => (isa        => 'Maybe[Int]',
                            is         => 'ro',
                            init_arg   => undef,
                            lazy_build => 1,
                           );

sub _build_inline_index_read {
  my $self = shift;
  my @x = _parse_sample_description($self->_sample_description);
  return $x[3];  ## no critic (ProhibitMagicNumbers)
}

has 'inline_index_end' => (isa        => 'Maybe[Int]',
                           is         => 'ro',
                           init_arg   => undef,
                           lazy_build => 1,
                          );

=head2 inline_index_end

index end

=cut

sub _build_inline_index_end {
  my $self = shift;
  my @x = _parse_sample_description($self->_sample_description);
  return $x[2];
}

=head2 inline_index_start

index start

=cut

has 'inline_index_start' => (isa        => 'Maybe[Int]',
                             is         => 'ro',
                             init_arg   => undef,
                             lazy_build => 1,
                            );

sub _build_inline_index_start {
  my $self = shift;
  my @x = _parse_sample_description($self->_sample_description);
  return $x[1];
}

=head2 inline_index_exists

=cut

has 'inline_index_exists' => (isa        => 'Bool',
                              is         => 'ro',
                              init_arg   => undef,
                              lazy_build => 1,
                             );

sub _build_inline_index_exists {
  my $self = shift;
  return _tag_sequence_from_sample_description($self->_sample_description) ? 1 : 0;
}

has '_sample_description' => (isa        => 'Maybe[Str]',
                              is         => 'ro',
                              init_arg   => undef,
                              lazy_build => 1,
                             );

sub _build__sample_description {
  my $self = shift;
  return $self->sample_description if ($self->sample_description);
  foreach my $c ($self->children) {
    return $c->sample_description if ($c->sample_description);
  }
  return;
}

=head2 is_phix_spike

If plex library and is the spiked phiX.

=cut

sub is_phix_spike {
  my $self = shift;
  if(my $ti = $self->tag_index and my $spti = $self->spiked_phix_tag_index) {
     return $ti == $spti;
  }
  return;
}

=head2 tag_sequence

Read-only string accessor, not possible to set from the constructor.
Undefined on a lane level and for zero tag_index.
Multiple indexes are concatenated.

=cut
has 'tag_sequence' =>    (isa             => 'Maybe[Str]',
                          is              => 'ro',
                          init_arg        => undef,
                          lazy_build      => 1,
                         );
sub _build_tag_sequence {
  my $self = shift;
  if( @{$self->tag_sequences} ) {
    return join q[], @{$self->tag_sequences};
  }
  return;
}

=head2 tag_sequences

Read-only array accessor, not possible to set from the constructor.
Empty array on a lane level and for zero tag_index.

Might return not the index given by LIMs, but the one contained in the
sample description.

If dual index is used, the array contains two sequences. The secons index
might come from LIMS or, if LIMs has one long index, it will be split in two.

=cut
has 'tag_sequences' =>   (isa             => 'ArrayRef',
                          is              => 'ro',
                          init_arg        => undef,
                          lazy_build      => 1,
                         );
sub _build_tag_sequences {
  my $self = shift;

  my ($seq, $seq2);
  if ($self->tag_index) {
    if (!$self->spiked_phix_tag_index || $self->tag_index != $self->spiked_phix_tag_index) {
      if ($self->sample_description) {
        $seq = _tag_sequence_from_sample_description($self->sample_description);
      }
    }
    if (!$seq) {
      $seq = $self->default_tag_sequence;
      if ($seq && $self->default_tagtwo_sequence) {
        $seq2 = $self->default_tagtwo_sequence;
      }
    }
  }

  my @sqs = ();
  if ($seq) {
    push @sqs, $seq;
  }
  if ($seq2) {
    push @sqs, $seq2;
  }

  if (scalar @sqs == 1) {
    if (length($sqs[0]) == $DUAL_INDEX_TAG_LENGTH) {
      my $tag_length = $DUAL_INDEX_TAG_LENGTH/2;
      push @sqs, substr $sqs[0], $tag_length;
      $sqs[0] = substr $sqs[0], 0, $tag_length;
    }
  }

  return \@sqs;
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

 1 for passes, 0 for failed, undef if the value is not set.

 This method is deprecated as of 08 March 2016. It should not be used in any
 new code. The only place where this method is used in production code is
 the old warehouse loader. Deprecation warning is not appropriate because the
 old wh loader logs will be flooded.

=cut
sub  seq_qc_state {
  my $self = shift;
  my $state = $self->driver ? $self->driver->qc_state : q[];
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
  my $rg = $self->_trim_value($self->sample_reference_genome);
  if (!$rg ) {
    $rg = $self->_trim_value($self->study_reference_genome);
  }
  return $rg;
}

sub _trim_value {
  my ($self, $value) = @_;
  if ($value) {
    $value =~ s/^\s+|\s+$//gxms;
  }
  $value ||= undef;
  return $value;
}

sub _helper_over_pool_for_boolean_build_methods {
  my ($self,$method) = @_;

  my $cuh = 0;
  if ($self->position) {
    my @lims =  ($self->is_pool && !$self->tag_index) ? $self->children : ($self);
    foreach my $l (@lims) {
      $cuh = $l->$method;
      if ($cuh) {
        return 1;
      }
    }
  }
  return $cuh ? 1 : 0;
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
  return $self->_helper_over_pool_for_boolean_build_methods('study_contains_nonconsented_human');
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
  return $self->_helper_over_pool_for_boolean_build_methods('study_contains_nonconsented_xahuman');
}

=head2 any_sample_consent_withdrawn

Read-only accessor, not possible to set from the constructor.

Return true if any sample, when representing a multiple sample scope,
has had its consent withdrawn, or false otherwise.

=cut

has 'any_sample_consent_withdrawn' => (isa             => 'Bool',
                                       is              => 'ro',
                                       init_arg        => undef,
                                       lazy_build      => 1,
                                      );
sub _build_any_sample_consent_withdrawn {
  my $self = shift;
  return $self->_helper_over_pool_for_boolean_build_methods
    ('sample_consent_withdrawn');
}

=head2 alignments_in_bam

Read-only accessor, not possible to set from the constructor.
For a library, control on non-zero plex returns the value of the
contains_nonconsented_xahuman on the relevant study object. For a pool
or a zero plex returns 1 if any of the studies in the pool
has study_alignments_in_bam

On a batch level or if no associated study found, returns 0.

=cut
has 'alignments_in_bam' =>             (isa             => 'Bool',
                                        is              => 'ro',
                                        init_arg        => undef,
                                        lazy_build      => 1,
                                       );
sub _build_alignments_in_bam {
  my $self = shift;
  return $self->_helper_over_pool_for_boolean_build_methods('study_alignments_in_bam');
}

=head2 separate_y_chromosome_data

Read-only accessor, not possible to set from the constructor.
For a library, control on non-zero plex returns the value of the
contains_nonconsented_xahuman on the relevant study object. For a pool
or a zero plex returns 1 if any of the studies in the pool
has study_separate_y_chromosome_data

On a batch level or if no associated study found, returns 0.

=cut
has 'separate_y_chromosome_data' =>    (isa             => 'Bool',
                                        is              => 'ro',
                                        init_arg        => undef,
                                        lazy_build      => 1,
                                       );
sub _build_separate_y_chromosome_data {
  my $self = shift;
  return $self->_helper_over_pool_for_boolean_build_methods('study_separate_y_chromosome_data');
}

=head2 children

Method returning a list of st::api::lims objects that are associated with this object
and belong to the next (one lower) level. An empty list for a non-pool lane and for a plex.
For a pooled lane contains plex-level objects. On a run level, when the position 
accessor is not set, returns lane level objects.

=cut

=head2 num_children

Returns the number of children objects, ie the length children list.

=cut

has '_cached_children'              => (isa             => 'ArrayRef[Object]',
                                        traits          => [ qw/Array/ ],
                                        is              => 'bare',
                                        required        => 0,
                                        init_arg        => undef,
                                        lazy_build      => 1,
                                        handles   => {
                                         'num_children' => 'count',
                                         'children'     => 'elements',
                                                     },
                                       );
sub _build__cached_children {
  my $self = shift;

  my @children = ();
  my @basic_attrs = qw/id_run position tag_index/;

  if ($self->driver) {
    if($self->driver->can('children')) {
      foreach my $c ($self->driver->children) {
        my $init = {'driver_type' => $self->driver_type, 'driver' => $c};
        foreach my $attr (@basic_attrs) {
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
  } else {
    my $rpt_list = $self->_primary_arguments->{'rpt_list'};
    if ($rpt_list) {
      my $package_name = __PACKAGE__ . '::rpt_composition_factory';
      my $class=Moose::Meta::Class->create($package_name);
      $class->add_attribute('rpt_list', {isa =>'Str', is=>'ro', required =>1});
      my $composition = Moose::Meta::Class->create_anon_class(
        superclasses => [$package_name],
        roles        => [
         'npg_tracking::glossary::composition::factory::rpt' =>
         {'component_class' => 'npg_tracking::glossary::composition::component::illumina'}
                        ]
      )->new_object(rpt_list => $rpt_list)->create_composition();

      my @components = $composition->components_list();
      my $driver_type = $self->driver_type;
      if ($driver_type eq $SAMPLESHEET_DRIVER_TYPE) {
        my @unique_ids = uniq map { $_->id_run } @components;
        if (@unique_ids != 1) {
          croak qq[Cannot use $SAMPLESHEET_DRIVER_TYPE driver with components from multiple runs];
        }
      }

      foreach my $component (@components) {
        my %init = %{$self->_driver_arguments()};
        $init{'driver_type'} = $driver_type;
        foreach my $attr (@basic_attrs) {
          $init{$attr} = $component->$attr;
        }
        push @children, __PACKAGE__->new(\%init);
      }
    }
  }
  return \@children;
}

=head2 cached_samplesheet_var_name

Returns the name of the env. variable for storing the full path of the cached
samplesheet. If this variable is set and the driver is not given explicitly,
a samplesheet driver is used by this class.

=cut
sub cached_samplesheet_var_name {
  return $CACHED_SAMPLESHEET_FILE_VAR_NAME;
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
    my $key;
    if ($self->rpt_list) {
      $key = npg_tracking::glossary::rpt->deflate_rpt($alims);
    } else {
      $key = $alims->tag_index ? $alims->tag_index : $alims->position;
    }
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

sub _list_of_attributes {
  my ($self, $attr_name, $with_spiked_control) = @_;
  my @l = ();
  if (!defined $self->position && !$self->is_composition) {
    return @l;
  }

  if (!defined $with_spiked_control) { $with_spiked_control = 1; }

  @l = sort {$a cmp $b}
       uniq
       grep {defined and length}
       map {$_->$attr_name}
    ($self->is_pool || $self->is_composition) ?
    $attr_name ne 'spiked_phix_tag_index' ? # avoid unintended recursion
      grep { $with_spiked_control || ! $_->is_phix_spike } $self->children :
      () :
    ($self);
  return @l;
}

sub _single_attribute {
  my ($self, $attr_name, $with_spiked_control) = @_;
  my @a = $self->_list_of_attributes($attr_name, $with_spiked_control);
  if(1==@a) { return $a[0];}
  return;
}

=head2 library_names

A list of library names. if $self->is_pool is true, returns unique library
names of plex-level objects, otherwise returns object's own library name.
Takes an optional argument with_spiked_control, wich defaults to true.


=cut

=head2 library_ids

Similar to library_names, but for ids.

=cut


=head2 sample_names

A list of sample names. if $self->is_pool is true, returns unique sample
names of plex-level objects, otherwise returns object's own sample name.
Takes an optional argument with_spiked_control, wich defaults to true.

=cut


=head2 sample_cohorts

Similar to sample_names, but for cohorts.

=cut


=head2 sample_donor_ids

Similar to sample_names, but for donor_ids.

=cut


=head2 sample_ids

Similar to sample_names, but for ids.

=cut


=head2 sample_public_names

Similar to sample_names, but for public_names.

=cut


=head2 sample_supplier_names

Similar to sample_names, but for supplier_names.

=cut


=head2 study_names

A list of study names. if $self->is_pool is true, returns unique study
names of plex-level objects, otherwise returns object's own study name.
Takes an optional argument with_spiked_control, wich defaults to true.

=cut


=head2 study_accession_numbers

Similar to study_names, but for accession_numbers.

=cut


=head2 study_ids

Similar to study_names, but for ids.

=cut


=head2 study_titles

Similar to study_names, but for study_titles.

=cut


=head2 project_ids

A list of project ids, similar to study_ids.

=cut


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
  my @x = _parse_sample_description($desc);
  return $x[0];
}

sub _parse_sample_description {
  my $desc = shift;
  my $tag=undef;
  my $start=undef;
  my $end=undef;
  my $read=undef;
  if ($desc && (($desc =~ m/base\ indexing\ sequence/ismx) && ($desc =~ m/enriched\ mRNA/ismx))) {
    ($tag) = $desc =~ /\(([ACGT]+)\)/smx;
    if ($desc =~ /bases\ (\d+)\ to\ (\d+)\ of\ read\ 1/smx) {
        ($start, $end, $read) = ($1, $2, 1);
    } elsif ($desc =~ /bases\ (\d+)\ to\ (\d+)\ of\ non\-index\ read\ (\d)/smx) {
        ($start, $end, $read) = ($1, $2, $3);
    } else {
        croak q[Error parsing sample description ] . $desc;
    }
  }
  return ($tag, $start, $end, $read);
}

=head2 library_types

A list of library types, excluding spiked phix library

=cut
sub library_types {
  my ($self) = @_;
  return $self->_list_of_attributes('_derived_library_type',0);
}

=head2 driver_method_list

A sorted list of methods that should be implemented by a driver

=cut
sub driver_method_list {
  return @DELEGATED_METHODS;
}

=head2 driver_method_list_short

A sorted list of methods that should be implemented by a driver

=cut
sub driver_method_list_short {
  my @remove = @_;
  my @methods = @DELEGATED_METHODS;
  if (@remove) {
    if ($remove[0] eq __PACKAGE__ || ref $remove[0] eq __PACKAGE__) {
      shift @remove;
    }
    if (@remove) {
      @methods = grep { my $delegated = $_; none {$_ eq $delegated} @remove } @DELEGATED_METHODS;
    }
  }
  return @methods;
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
  push @attrs, @METHODS;
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
  my $s = __PACKAGE__ . q[ object];
  if ($d) {
    $s .= ", driver - $d";
  }
  foreach my $attr ( sort @{$METHODS_PER_CATEGORY{'primary'}} ) {
    my $value=$self->$attr;
    if (defined $value){
      $s .= q[, ] . join q[ ], $attr, $value;
    }
  }
  return $s;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::Aliases

=item Moose::Meta::Class

=item Class::Load

=item namespace::autoclean

=item List::MoreUtils

=item Carp

=item Readonly

=item npg_tracking::util::types

=item npg_tracking::glossary::rpt

=item npg_tracking::glossary::composition::factory::rpt

=item npg_tracking::glossary::composition::component::illumina

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2016 Genome Research Ltd

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

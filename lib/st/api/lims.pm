package st::api::lims;

use Carp;
use Moose;
use MooseX::Aliases;
use Moose::Meta::Class;
use namespace::autoclean;
use Readonly;
use List::MoreUtils qw/any none uniq each_arrayref/;
use Class::Load qw/load_class/;

use npg_tracking::util::types;
use npg_tracking::glossary::rpt;
use npg_tracking::glossary::composition::factory::rpt_list;
use npg_tracking::data::reference::find;

our $VERSION = '0';

=head1 NAME

st::api::lims

=head1 SYNOPSIS

 # Run level object
 $lims = st::api::lims->new(id_run => 333);
 $lims = st::api::lims->new(driver_type => q(ml_warehouse),
                            flowcell_barcode => q(HTC3HADXX));

 # Lane level object
 $lims = st::api::lims->new(id_run => 333, position => 3);

 # Plex level object
 $lims = st::api::lims->new(id_run => 333, position => 3, tag_index => 44);
 $lims = st::api::lims->new(driver_type => q(ml_warehouse),
                            id_flowcell_lims => 222,
                            position => 2,
                            tag_index => 40,
                            mlwh_schema=>$suitable_dbic_schema);

 # Objects defined via a list of one or more rpt values
 $lims = st::api::lims->new(rpt_list => '333:3:44');
 $lims = st::api::lims->new(rpt_list => '333:3:44;333:4:44;');

=head1 DESCRIPTION

Generic NPG LIMS wrapper capable of retrieving data from multiple sources via
a number of source-specific drivers. Provides methods implementing business
logic that is independent of data source.

A set of valid arguments to the constructor depends on the driver type. The
drivers are implemented as st::api::lims::<driver_name> classes.

The default driver type is 'samplesheet'. The path to the samplesheet can be
set either in the 'path' constructor attribute or by setting the env. variable
NPG_CACHED_SAMPLESHEET_FILE.

All flavours of the ml_warehouse driver require access to the ml warehouse
database. If the mlwh_schema constructor argument is not set, a connection
to the database defined in a standard NPG configuration file is be used.

Any driver attribute can be passed through to the driver's constructor via
the constructor of the st::api::lims object. Not all of the attributes passed
through to the driver are be available as this object's attributes. Example:

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
Readonly::Scalar my $SAMPLESHEET_DRIVER_TYPE => 'samplesheet';
Readonly::Scalar my $DEFAULT_DRIVER_TYPE => $SAMPLESHEET_DRIVER_TYPE;

Readonly::Scalar my $DUAL_INDEX_TAG_LENGTH => 16;

Readonly::Scalar my $TAG_INDEX_4_UNDEFINED => -1;

Readonly::Hash   my  %METHODS_PER_CATEGORY => {
    'primary'    =>   [qw/ tag_index
                           position
                           id_run
                           path
                           id_flowcell_lims
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
                           gbs_plex_name
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
                           sample_is_control
                           sample_control_type
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

    'project'      => [qw/ project_cost_code /],
};

Readonly::Array my @METHODS           => sort map { @{$_} } values %METHODS_PER_CATEGORY;
Readonly::Array my @DELEGATED_METHODS => sort map { @{$METHODS_PER_CATEGORY{$_}} }
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

=head2 copy_init_args

Returns a hash reference that can be used to initialise st::api::lims
objects similar to this object. The driver details, if present in this
object, are returned under the 'driver_type' key and, if relevant,
'mlwh_schema' key. 

=cut
sub copy_init_args {
  my $self = shift;

  my %init = %{$self->_driver_arguments()};
  if ($self->driver_type()) {
    $init{'driver_type'} = $self->driver_type();
    if (!$init{'mlwh_schema'} && $init{'driver_type'} =~ /warehouse/smx) {
      $init{'mlwh_schema'} =  $self->driver()->mlwh_schema;
    }
  }

  return \%init;
}

# Mapping of LIMS object types to attributes for which methods are to
# be generated. These generated methods are 'plural' methods which
# return an array of that attributes e.g. $lims->library_ids (returns
# an array of library_id values), $lims->sample_public_names (returns
# an array of of sample_public_name values).
Readonly::Hash my %ATTRIBUTE_LIST_METHODS => {
    'library'      => [qw/ id
                           name
                           type
                         /],
    'sample'       => [qw/ accession_number
                           cohort
                           common_name
                           donor_id
                           id
                           name
                           public_name
                           reference_genome
                           supplier_name
                         /],
    'study'        => [qw/ accession_number
                           id
                           name
                           title
                         /]
};

=head2 library_names

A list of library names. if $self->is_pool is true, returns unique library
names of plex-level objects, otherwise returns object's own library name.
Takes an optional argument with_spiked_control, wich defaults to true.

=head2 library_ids

Similar to library_names, but for ids.

=head2 library_types

Similar to library_names, but for types.

=head2 sample_names

A list of sample names. if $self->is_pool is true, returns unique sample
names of plex-level objects, otherwise returns object's own sample name.
Takes an optional argument with_spiked_control, wich defaults to true.

=head2 sample_cohorts

Similar to sample_names, but for cohorts.

=head2 sample_donor_ids

Similar to sample_names, but for donor_ids.

=head2 sample_ids

Similar to sample_names, but for ids.

=head2 sample_public_names

Similar to sample_names, but for public_names.

=head2 sample_supplier_names

Similar to sample_names, but for supplier_names.

=head2 study_names

A list of study names. if $self->is_pool is true, returns unique study
names of plex-level objects, otherwise returns object's own study name.
Takes an optional argument with_spiked_control, wich defaults to true.

=head2 study_accession_numbers

Similar to study_names, but for accession_numbers.

=head2 study_ids

Similar to study_names, but for ids.

=head2 study_titles

Similar to study_names, but for study_titles.

=cut

# Dynamicaly generate methods for getting 'plural' values.
# The methods are documented above.
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

Driver type, currently defaults to 'samplesheet'

=cut
has 'driver_type' => ( isa        => 'Str',
                       is         => 'ro',
                       lazy_build => 1,
                       writer     => '_set_driver_type',
                     );
sub _build_driver_type {
  my $self = shift;
  if ($self->has_driver && $self->driver){
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

Driver object (mlwarehouse, samplesheet)

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

# All methods are created, now aliases for methods can be defined.
alias primer_panel => 'gbs_plex_name';

=head2 is_phix_spike

True for a plex library that is the spiked phiX.

=cut

sub is_phix_spike {
  my $self = shift;
  if ($self->is_composition) {
    return ($self->children)[0]->is_phix_spike;
  } elsif (my $ti = $self->tag_index and my $spti = $self->spiked_phix_tag_index) {
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

  my @sqs = ();

  if ($self->tag_index) {
    my $seq = $self->default_tag_sequence;
    if ($seq) {
      push @sqs, $seq;
      $seq = $self->default_tagtwo_sequence;
      if ($seq) {
        push @sqs, $seq;
      }
    }

    if (scalar @sqs == 1) {
      if (length($sqs[0]) == $DUAL_INDEX_TAG_LENGTH) {
        my $tag_length = $DUAL_INDEX_TAG_LENGTH/2;
        push @sqs, substr $sqs[0], $tag_length;
        $sqs[0] = substr $sqs[0], 0, $tag_length;
      }
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
Returns a hash reference of expected insert sizes.

=cut
has 'required_insert_size'  => (isa             => 'HashRef',
                                is              => 'ro',
                                init_arg        => undef,
                                lazy_build      => 1,
                               );
sub _build_required_insert_size {
  my $self = shift;

  my $is_hash = {};
  if (defined $self->position or defined $self->rpt_list) {
    my @alims = $self->descendants;
    @alims = @alims ? @alims : ($self);
    foreach my $lims (@alims) {
      if ($lims->is_control) {
        next;
      }
      my $is = $lims->required_insert_size_range || {};
      foreach my $key (qw/to from/) {
        my $value = $is->{$key};
        if ($value) {
          my $lib_key = $lims->library_id || $lims->sample_id;
          $is_hash->{$lib_key}->{$key} = $value;
        }
      }
    }
  }

  return $is_hash;
}

=head2 reference_genome

Read-only accessor, not possible to set from the constructor.
Returns pre-set reference genome, retrieving it either from a sample,
or, failing that, from a study. The exception from the latter rule is
tag zero or lane objects, where a fall-back to the study genome is
disabled if the child objects have different sample reference genomes.

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
    if ($self->is_pool || $self->is_composition) {
      my @children = $self->children();
      if ($self->is_composition) {
        # Tag zero and lane components have their own children.
        my @tmp_children = map { ($_->children) } @children;
        if (@tmp_children) {
          @children = @tmp_children;
        }
      }
      my @sample_ref_genomes =
        grep { $_ }
        map { $self->_trim_value($_->sample_reference_genome) }
        grep { !$_->is_phix_spike }
        @children;
      if (@sample_ref_genomes) {
        return;
      }
    }
    $rg = $self->_trim_value($self->study_reference_genome);
  }
  return $rg;
}

=head2 species_from_reference_genome

Extracts the species name from the value of the C<reference_genome> attribute
and returns it. Returns an undefined value if the value of the C<reference_genome>
attribute is not defined or if the the C<reference_genome> string does not match
the expected pattern.

Examples:

 reference_genome: 'Homo_sapiens (GRCh38_full_analysis_set_plus_decoy_hla)'
 species: 'Homo_sapiens'

 reference_genome: 'Mus_musculus (GRCm38 + ensembl_84_transcriptome)'
 species: 'Mus_musculus'
=cut
sub species_from_reference_genome {
  my $self = shift;

  if ($self->reference_genome) {
    my @genome_as_array = npg_tracking::data::reference::find
      ->parse_reference_genome($self->reference_genome);
    if (@genome_as_array) {
      return $genome_as_array[0];
    }
  }
  return;
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
  if ($self->position || $self->is_composition) {
    my @lims =  (($self->is_pool && !$self->tag_index) || $self->is_composition) ? $self->children : ($self);
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
accessor is not set, returns lane level objects. For the st::api::lims type object that
was instantiated with an rpt_list attribute, returns a list of st::api::lims type objects
corresponding to individual components of the composition defined by the rpt_list attribute
value.

=head2 num_children

Returns the number of children objects.

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
  my @basic_attrs = @{$METHODS_PER_CATEGORY{'primary'}};
  my $driver_type = $self->driver_type;

  if ($self->driver) {
    if($self->driver->can('children')) {
      foreach my $c ($self->driver->children) {
        my $init = {'driver_type' => $driver_type, 'driver' => $c};
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

      foreach my $component ($composition->components_list()) {
        my %init = %{$self->_driver_arguments()};
        $init{'driver_type'} = $driver_type;
        foreach my $attr (@basic_attrs) {
          if ($component->can($attr)) {
            $init{$attr} = $component->$attr;
          }
        }
        push @children, __PACKAGE__->new(\%init);
      }
    }
  }
  return \@children;
}

=head2 is_composition

=cut

sub is_composition {
  my $self = shift;
  return $self->rpt_list ? 1 : 0;
}

=head2 aggregate_libraries

Given a list of lane-level C<st::api::lims> objects, finds their children,
which can be merged and analysed together across all or some of the lanes.
If children are not present, considers lane-level object as a single
library. The second optional argument is a list of lanes (positions) that
should be excluded from the merge.

All argument lane objects should belong to the same run. It is assumed that
they all use the same C<st::api::lims> driver type.

Returns two lists of objects, one for merged entities and one for singletons,
which are wrapped into a dictionary. Either of these lists can be empty. The
two lists are guaranteed not to be empty at the same time.

Tag zero objects are neither added nor explicitly removed. Objects for
spiked-in controls (if present) are always added to the list of singletons.

The lists of singletons and merges are returned as sorted lists. For a given
set of input lane-level  C<st::api::lims> objects the same lists are always
returned.

Criteria for entities to be eligible for a merge:

  they are not controls,
  they belong to the same library,
  they share the same tag index,
  they belong to different lanes, one per lane,
  they belong to the same study,
  they do not belong to a list of excluded lanes.

This method can be used both as instance and as a class method.

  my $all_lims = st::api::lims->aggregate_libraries($run_lims->children());
  for my $l (@{$all_lims->{'singles'}}) {
    print 'No merge for ' . $l->to_string;    
  }
  for my $l (@{$all_lims->{'merges'}}) {
    print 'Merged entity ' . $l->to_string;
  }

  # Exclude lanes 2 and 3 from the merge. Entities belonging to this lane
  # will appear under the 'singles' key.
  $all_lims = st::api::lims->aggregate_libraries($run_lims->children(), [2,3]);
  for my $l (@{$all_lims->{'singles'}}) {
    print 'No merge for ' . $l->to_string;
  }

=cut

sub aggregate_libraries {
  my ($self, $lane_lims_array, $do_not_merge_lanes) = @_;

  # This restriction might be lifted in future.
  _check_value_is_unique('id_run', 'run IDs', $lane_lims_array);
  $do_not_merge_lanes ||= [];
  my @lanes_to_exclude_from_merge = @{$do_not_merge_lanes};
  _validate_lane_numbers(@lanes_to_exclude_from_merge);

  my $lims_objects_by_library = {};
  my @singles = ();
  my @all_single_lims_objs = map { $_->is_pool ? $_->children() : $_ }
                             @{$lane_lims_array};
  foreach my $obj (@all_single_lims_objs) {
    if ($obj->is_control() ||
        any { $obj->position == $_ } @lanes_to_exclude_from_merge) {
      push @singles, $obj;
    } else {
      push @{$lims_objects_by_library->{_hash_key4lib_aggregation($obj)}}, $obj;
    }
  }

  # Get the common st::api::lims driver arguments, which will be used
  # to create objects for merged entities.
  # Do not use $self for copying the driver arguments in order to retain
  # ability to use this method as a class method.
  my $init = $lane_lims_array->[0]->copy_init_args();
  delete $init->{position};
  delete $init->{id_run};

  my @non_control_singles = map { $_->[0] }
                            grep { scalar @{$_} == 1 }
                            values %{$lims_objects_by_library};
  push @singles, @non_control_singles;

  my %lanes_with_singles = map { $_->position => 1 }
                           @non_control_singles;

  my $merges = {};
  my $lane_set_delim = q[,];
  foreach my $hashing_key (keys %{$lims_objects_by_library}) {
    my @lib_lims = @{$lims_objects_by_library->{$hashing_key}};
    if (@lib_lims > 1) {

      # If some libraries from the lane cannot be merged, other libraries
      # will not be merged either. This might change in future.
      if (any { exists $lanes_with_singles{$_->position} } @lib_lims) {
        push @singles, @lib_lims;
        next;
      }

      _check_merge_correctness(\@lib_lims);
      my $lane_set = join $lane_set_delim,
        sort { $a <=> $b } map { $_->position } @lib_lims;
      my $tag_index = $lib_lims[0]->tag_index ;
      if (!defined $tag_index) {
        $tag_index = $TAG_INDEX_4_UNDEFINED;
      }
      #####
      # rpt_list which we use to instantiate the object below has to be
      # ordered correctly. Wrong order might not change the properties of
      # the resulting st::api::lims object. However, difficult to track
      # bugs might result in a situation when the value of this
      # attribute for the object itself and for the composition object
      # for this object differs.
      my $rpt_list = npg_tracking::glossary::rpt->deflate_rpts(\@lib_lims);
      $rpt_list = npg_tracking::glossary::composition::factory::rpt_list
        ->new(rpt_list => $rpt_list)->create_composition()
        ->freeze2rpt();
      $merges->{$lane_set}->{$tag_index} = __PACKAGE__->new(
        %{$init}, rpt_list => $rpt_list
      );
    }
  }

  # Lane sets should not intersect. Error if a lane belongs to multiple sets.
  my @all_lanes_in_merged_sets = map { (split /$lane_set_delim/smx, $_) }
                                 keys %{$merges};
  if (@all_lanes_in_merged_sets != uniq @all_lanes_in_merged_sets) {
    croak 'No clean split between lanes in potential merges';
  }

  my $all_lims_objects = {'singles' => [], 'merges' => []};
  # Arrange in a predictable consistent orger.
  foreach my $lane_set ( sort keys %{$merges} ) {
    my @tag_indexes = sort { $a <=> $b } keys %{$merges->{$lane_set}};
    push @{$all_lims_objects->{'merges'}},
      (map { $merges->{$lane_set}->{$_} } @tag_indexes);
  }
  $all_lims_objects->{'singles'} = [
    sort {##no critic (BuiltinFunctions::ProhibitReverseSortBlock BuiltinFunctions::RequireSimpleSortBlock)
      my $index_a = defined $a->tag_index ?
        $a->tag_index : $TAG_INDEX_4_UNDEFINED;
      my $index_b = defined $b->tag_index ?
        $b->tag_index : $TAG_INDEX_4_UNDEFINED;
      $a->position <=> $b->position || $index_a <=> $index_b
    }
    @singles
  ];

  # Sanity check.
  my $num_objects = @{$all_lims_objects->{'merges'}} +
                    @{$all_lims_objects->{'singles'}};
  if ($num_objects == 0) {
    croak 'Invalid aggregation by library, no objects returned';
  }

  return $all_lims_objects;
}

sub _hash_key4lib_aggregation {
  my $lims_obj = shift;
  my $key = $lims_obj->library_id;
  if (defined $lims_obj->tag_index) {
    $key .= q[:] . $lims_obj->tag_index;
  }
  return $key;
}

sub _check_merge_correctness {
  my $lib_lims = shift;
  my @lanes = uniq  map {$_->position} @{$lib_lims};
  if (@lanes != @{$lib_lims}) { # An unlikely mistake somewhere upstream.
    croak 'Intra-lane merge is detected';
  }
  _check_value_is_unique('study_id', 'studies', $lib_lims);
  return;
}

sub _check_value_is_unique {
  my ($method_name, $property_name, $objects) = @_;
  my @values = uniq
               map { defined $_->$method_name ? $_->$method_name : 'undefined' }
               @{$objects};
  if (@values != 1) {
    croak "Multiple $property_name in a potential merge by library";
  }
  return;
}

sub  _validate_lane_numbers {
  my @lanes_to_exclude_from_merge = @_;

  if (@lanes_to_exclude_from_merge) {
    my @temp = grep { $_ > 0 } map { int } @lanes_to_exclude_from_merge;
    my $exclude_string = join q[, ], @lanes_to_exclude_from_merge;
    if ( (@temp < @lanes_to_exclude_from_merge) ||
        ($exclude_string ne join q[, ], @temp) ) {
      croak "Invalid lane numbers in list of lanes to exclude from the merge:\n" .
        $exclude_string;
    }
  }
  return;
}

=head2 create_tag_zero_object
 
Using run ID and position values of this object, creates and returns
st::api::lims object for tag zero. The new object has the same driver
settings as the original object.

  my $l = st::api::lims->new(id_run => 4, position => 3);
  my $t0_lims = $l->create_tag_zero_object();

  my $l = st::api::lims->new(id_run => 4, position => 3, tag_index => 6);
  my $t0_lims = $l->create_tag_zero_object();

=cut

sub create_tag_zero_object {
  my $self = shift;
  if (!defined $self->position) {
    croak 'Position should be defined';
  }
  my $init = $self->copy_init_args();
  $init->{'tag_index'}   = 0;
  return __PACKAGE__->new(%{$init});
}

=head2 create_lane_object

Using id_run and position values given as attributes to this method, creates
and returns an st::api::lims object for the lane corresponding to the given
attributes. The new object has the same driver settings as the original object.

  my $l = st::api::lims->new(id_run => 4, position => 3, tag_index => 6);
  my $lane_lims = $l->create_lane_object(4,4);

=cut

sub create_lane_object {
  my ($self, $id_run, $position) = @_;
  ($id_run and $position) or croak 'id_run and position are expected as arguments';
  my $init = $self->copy_init_args();
  delete $init->{'tag_index'};
  delete $init->{'rpt_list'};
  $init->{'id_run'}   = $id_run;
  $init->{'position'} = $position;
  return __PACKAGE__->new(%{$init});
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

sub _list_of_attributes {
  my ($self, $attr_name, $with_spiked_control) = @_;
  my @l = ();
  my $is_composition = $self->is_composition;
  if (!defined $self->position && !$is_composition) {
    return @l;
  }

  if (!defined $with_spiked_control) { $with_spiked_control = 1; }
  my $pool_or_composition = $self->is_pool || $is_composition;
  my $list_method_name = $attr_name . q[s];

  @l = sort {$a cmp $b}
       uniq
       grep {defined and length}
       map {
         ( $is_composition
           && (!defined $_->tag_index || $_->tag_index == 0)
           && $_->can($list_method_name) )
         ? $_->$list_method_name($with_spiked_control)
         : $_->$attr_name
       }
    $pool_or_composition ?
    $attr_name ne 'spiked_phix_tag_index' ? # avoid unintended recursion
      grep { $with_spiked_control || (!$_->is_phix_spike || $is_composition) } $self->children :
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

  my $type;
  if (!$self->is_pool) {
    $type = $self->default_library_type;
  }
  $type ||= undef;

  return $type;
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

=item npg_tracking::data::reference::find

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Objects created with rpt_list argument defined:
is_control method always returns false

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013,2014,2015,2016,2017,2018,2019,2020,2021,2023,2024
   Genome Research Ltd.

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

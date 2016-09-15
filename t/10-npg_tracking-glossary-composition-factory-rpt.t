use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use Moose::Meta::Class;

my $factory_package   = 'npg_tracking::glossary::composition::factory::rpt';
my $component_package = 'npg_tracking::glossary::composition::component::illumina';
use_ok ($factory_package);

throws_ok { Moose::Meta::Class->create_anon_class(
  roles => [$factory_package => {component_class => $component_package}],
                                                 )
          } qr/requires the method \'rpt_list\' to be implemented/,
  'no rpt_list method/attribute - error';

subtest 'object with rpt_list attribute' => sub {
  plan tests => 10;

  package test1::npg_tracking::composition::factory::rpt;
  use Moose;

  has 'rpt_list' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
  );

  with 'npg_tracking::glossary::composition::factory::rpt' =>
    {component_class => $component_package};

  has 'composition' => (
    is         => 'ro',
    isa        => 'npg_tracking::glossary::composition',
    lazy_build => 1,
  );
  sub _build_composition {
    my $self = shift;
    return $self->create_composition();
  }
  1;

  package main;

  my $factory_user = test1::npg_tracking::composition::factory::rpt->new();

  throws_ok { $factory_user->create_component() }
    qr/rpt string argument is missing/,
    'create_component() method needs input';
  my $component =  $factory_user->create_component('5:6:7');
  isa_ok ($component, $component_package);
  is ($component->id_run, 5, 'correct component run id');
  is ($component->position, 6, 'correct component position');
  is ($component->tag_index, 7, 'correct component tag index');
  ok (!$component->has_subset, 'subset has not been set');
  is ($component->subset, undef, 'component subset is undefined');

  throws_ok { $factory_user->create_composition() }
    qr/rpt list string is not given/,
    'rpt_list attribute value not set - error';

  $factory_user = test1::npg_tracking::composition::factory::rpt->new(
    rpt_list => '3:2;5:2;6:2:3;6:3:3'
  );
  my $composition = $factory_user->create_composition;
  isa_ok ($composition, 'npg_tracking::glossary::composition');
  is ($composition->freeze(),
    '{"components":[{"id_run":3,"position":2},{"id_run":5,"position":2},' .
    '{"id_run":6,"position":2,"tag_index":3},{"id_run":6,"position":3,"tag_index":3}]}',
    'composition json representation is correct');
};

subtest 'object with both rpt_list and subset attributes' => sub {
  plan tests => 12;

  package test2::npg_tracking::composition::factory::rpt;
  use Moose;
  with 'npg_tracking::glossary::subset';

  has 'rpt_list' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
  );

  with 'npg_tracking::glossary::composition::factory::rpt' =>
    {component_class => $component_package};

  has 'composition' => (
    is         => 'ro',
    isa        => 'npg_tracking::glossary::composition',
    lazy_build => 1,
  );
  sub _build_composition {
    my $self = shift;
    return $self->create_composition();
  }
  1;

  package main;

  my $factory_user = test2::npg_tracking::composition::factory::rpt->new();
  my $component =  $factory_user->create_component('5:6:7');
  is ($component->id_run, 5, 'correct component run id');
  is ($component->position, 6, 'correct component position');
  is ($component->tag_index, 7, 'correct component tag index');
  ok (!$component->has_subset, 'subset has not been set');
  is ($component->subset, undef, 'component subset is undefined');

  $factory_user = test2::npg_tracking::composition::factory::rpt->new(subset => 'phix');
  $component =  $factory_user->create_component('5:6:7');
  is ($component->id_run, 5, 'correct component run id');
  is ($component->position, 6, 'correct component position');
  is ($component->tag_index, 7, 'correct component tag index');
  ok ($component->has_subset, 'subset has been set');
  is ($component->subset, 'phix', 'phix subset');

  $factory_user = test2::npg_tracking::composition::factory::rpt->new(
    rpt_list => '3:2;5:2;6:2:3;6:3:3'
  );
  my $composition = $factory_user->create_composition;
  is ($composition->freeze(),
    '{"components":[{"id_run":3,"position":2},{"id_run":5,"position":2},' .
    '{"id_run":6,"position":2,"tag_index":3},{"id_run":6,"position":3,"tag_index":3}]}',
    'composition json representation is correct');

  $factory_user = test2::npg_tracking::composition::factory::rpt->new(
    subset   => 'phix',
    rpt_list => '3:2;5:2;6:2:3;6:3:3'
  );
  $composition = $factory_user->create_composition();
  is ($composition->freeze(),
    '{"components":[{"id_run":3,"position":2,"subset":"phix"},' .
    '{"id_run":5,"position":2,"subset":"phix"},' .
    '{"id_run":6,"position":2,"subset":"phix","tag_index":3},' .
    '{"id_run":6,"position":3,"subset":"phix","tag_index":3}]}',
    'composition json representation is correct');
};

subtest 'limited support for attributes by a component' => sub {
  plan tests => 2;

  package test3::npg_tracking::component;
  use Moose;
  with qw/ npg_tracking::glossary::composition::component
           npg_tracking::glossary::lane /;
  1;

  package main;

  package test3::npg_tracking::composition::factory::rpt;
  use Moose;
  with qw/ npg_tracking::glossary::subset /;

  has 'rpt_list' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
  );

  with 'npg_tracking::glossary::composition::factory::rpt' =>
    {component_class => 'test3::npg_tracking::component'};

  has 'composition' => (
    is         => 'ro',
    isa        => 'npg_tracking::glossary::composition',
    lazy_build => 1,
  );
  sub _build_composition {
    my $self = shift;
    return $self->create_composition();
  }
  1;

  package main; 

  my $factory_user = test3::npg_tracking::composition::factory::rpt->new(
    subset   => 'phix',
    rpt_list => '3:1;5:2;6:4:3;6:3:3'
  );
  my $composition;
  lives_ok { $composition = $factory_user->create_composition() }
    'attr mismatch does not cause an error';
  is ($composition->freeze(),
    '{"components":[{"position":1},{"position":2},{"position":3},{"position":4}]}',
    'composition json representation is correct');
};

1;

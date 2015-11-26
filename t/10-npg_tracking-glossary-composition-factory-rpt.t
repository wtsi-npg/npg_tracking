use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use Moose::Meta::Class;

my $factory_package   = 'npg_tracking::glossary::composition::factory::rpt';
my $component_package = 'npg_tracking::glossary::composition::component::illumina';
use_ok ($factory_package);

subtest 'object with no rpt_list attribute' => sub {
  plan tests => 7;

  my $factory_user = Moose::Meta::Class->create_anon_class(
    roles => [$factory_package => {component_class => $component_package}],
  )->new_object();
  throws_ok { $factory_user->create_composition() }
    qr/rpt_list method or attribute should be available/,
    'no rpt_list method/attribute - error';
  throws_ok { $factory_user->create_component() }
    qr/rpt string argument is missing/,
    'create_component() method needs input';
  my $component =  $factory_user->create_component('5:6:7');
  isa_ok ($component, $component_package);
  is ($component->id_run, 5, 'correct component run id');
  is ($component->position, 6, 'correct component position');
  is ($component->tag_index, 7, 'correct component tag index');
  is ($component->subset, undef, 'component subset is undefined');
};

subtest 'object with rpt_list attribute' => sub {
  plan tests => 3;

  package test1::npg_tracking::composition::factory::rpt;
  use Moose;
  with 'npg_tracking::glossary::composition::factory::rpt' =>
    {component_class => $component_package};

  has 'rpt_list' => (
    isa => 'Str',
    is => 'ro',
    required => 0,
  );
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
  throws_ok { $factory_user->create_composition() }
    qr/rpt list string is not given/,
    'rpt_list attribute value not set - error';

  $factory_user = test1::npg_tracking::composition::factory::rpt->new(
    rpt_list        => '3:2;5:2;6:2:3;6:3:3'
  );
  my $composition = $factory_user->create_composition;
  isa_ok ($composition, 'npg_tracking::glossary::composition');
  is ($composition->freeze(),
    '{"components":[{"id_run":3,"position":2},{"id_run":5,"position":2},' .
    '{"id_run":6,"position":2,"tag_index":3},{"id_run":6,"position":3,"tag_index":3}]}',
    'composition json representation is correct');
};

1;

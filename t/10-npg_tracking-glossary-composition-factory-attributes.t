use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

use_ok ('npg_tracking::glossary::composition::factory::attributes');

subtest 'object with one attr missing' => sub {
  plan tests => 3;

  package npg_tracking::composition::component::testA;
  use Moose;
  use MooseX::Storage;
  with Storage( 'traits' => ['OnlyWhenBuilt'],
                'format' => 'JSON' );
  has 'attr_1' => (isa => 'Int', is => 'ro', required => 1,);
  has 'attr_2' => (isa => 'Str', is => 'ro', required => 1,);
  1;

  package npg_tracking::composition::factory::testA;
  use Moose;
  with 'npg_tracking::glossary::composition::factory::attributes' =>
    {component_class => 'npg_tracking::composition::component::testA'};

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

  my $tA = npg_tracking::composition::factory::testA->new();
  throws_ok { $tA->composition } # attribute evaluation order
                                 # differes in Perl 5.16 and 5.22 
    qr/Attribute \(attr_(1|2)\) does not pass the type constraint/,
    'error when required object attribute is not defined';

  package npg_tracking::composition::component::testB;
  use Moose;
  use MooseX::Storage;
  with Storage( 'traits' => ['OnlyWhenBuilt'],
                'format' => 'JSON' );
  has 'attr_1' => (isa => 'Int', is => 'ro', required => 0,);
  has 'attr_2' => (isa => 'Str', is => 'ro', required => 1,);
  1;

  package npg_tracking::composition::factory::testB;
  use Moose;
  with 'npg_tracking::glossary::composition::factory::attributes' =>
    {component_class => 'npg_tracking::composition::component::testB'};

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

  my $tB = npg_tracking::composition::factory::testB->new();
  throws_ok { $tB->composition }
    qr/Attribute \(attr_2\) does not pass the type constraint/,
    'error when required object attribute is not defined';

  package npg_tracking::composition::component::testC;
  use Moose;
  use MooseX::Storage;
  with Storage( 'traits' => ['OnlyWhenBuilt'],
                'format' => 'JSON' );
  has 'attr_1' => (isa => 'Maybe[Int]', is => 'ro', required => 1,);
  has 'attr_2' => (isa => 'Str', is => 'ro', required => 1,);
  1;

  package npg_tracking::composition::factory::testC;
  use Moose;
  with 'npg_tracking::glossary::composition::factory::attributes' =>
    {component_class => 'npg_tracking::composition::component::testC'};

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

  my $tC = npg_tracking::composition::factory::testC->new();
  throws_ok { $tC->composition }
    qr/Attribute \(attr_2\) does not pass the type constraint/,
    'error when required object attribute is not defined';
};

subtest 'object with all required attributes' => sub {
   plan tests => 5;

  package npg_tracking::composition::component::test;
  use Moose;
  use MooseX::Storage;
  with Storage( 'traits' => ['OnlyWhenBuilt'],
                'format' => 'JSON' );
  has 'attr_1' => (isa => 'Int', is => 'ro', required => 1,);
  has 'attr_2' => (isa => 'Str', is => 'ro', required => 1,);
  1;

  package npg_tracking::composition::factory::test2;
  use Moose;
  with 'npg_tracking::glossary::composition::factory::attributes' =>
    {component_class => 'npg_tracking::composition::component::test'};

  has 'attr_1' => (isa => 'Int', is => 'ro', required => 1,);
  has 'attr_2' => (isa => 'Str', is => 'ro', required => 0,);
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

  my $t = npg_tracking::composition::factory::test2->new(
             attr_1 => 1,
             attr_2 => 'test');
  ok ($t->composition, 'composition is defined');
  isa_ok ($t->composition, 'npg_tracking::glossary::composition');
  isa_ok ($t->composition->get_component(0), 'npg_tracking::composition::component::test');
  is($t->composition->num_components, 1, 'one-component composition');
  is ($t->composition->freeze, '{"components":[{"attr_1":1,"attr_2":"test"}]}',
    'correct composition serialization'); 
};

1;

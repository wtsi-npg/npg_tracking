use strict;
use warnings;
use Test::More tests => 3;
use Test::Warn;

use_ok ('npg_tracking::glossary::composition::factory');

subtest 'object with no id_run and position attrs' => sub {
  plan tests => 2;

  package npg_tracking::composition::factory::test1;
  use Moose;
  use namespace::autoclean;
  with qw( npg_tracking::glossary::composition::factory );

  has 'composition' => (
    is         => 'ro',
    isa        => 'Maybe[npg_tracking::glossary::composition]',
    lazy_build => 1,
  );
  sub _build_composition {
    my $self = shift;
    return $self->create_sequence_composition();
  }
  1;

  package main;

  my $t = npg_tracking::composition::factory::test1->new();
  my $c;
  warning_like { $c = $t->composition }
    qr/cannot create npg_tracking::glossary::composition::component object/,
    'warning when required object attributes are not found';
  is ($c, undef, 'composition is undefined');
};

subtest 'object with id_run and position attrs' => sub {
   plan tests => 3;

  package npg_tracking::composition::factory::test2;
  use Moose;
  use namespace::autoclean;
  with qw( npg_tracking::glossary::run
           npg_tracking::glossary::lane
           npg_tracking::glossary::tag
           npg_tracking::glossary::composition::factory );

  has 'composition' => (
    is         => 'ro',
    isa        => 'npg_tracking::glossary::composition',
    lazy_build => 1,
  );
  sub _build_composition {
    my $self = shift;
    return $self->create_sequence_composition();
  }
  1;

  package main;

  my $t = npg_tracking::composition::factory::test2->new(
             id_run    => 123,
             position  => 4,
             tag_index => 2);
  ok ($t->composition, 'composition is defined');
  isa_ok ($t->composition, 'npg_tracking::glossary::composition');
  is ($t->composition->freeze,
    '{"components":[{"id_run":123,"position":4,"tag_index":2}]}',
    'correct composition serialization'); 
};

1;

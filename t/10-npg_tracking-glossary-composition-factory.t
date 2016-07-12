use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use DateTime;

use_ok ('npg_tracking::glossary::composition::factory');

subtest 'empty composition cannot be created' => sub {
  plan tests => 2;

  my $f = npg_tracking::glossary::composition::factory->new();
  isa_ok ($f, 'npg_tracking::glossary::composition::factory');
  throws_ok { $f->create_composition() } qr/Composition cannot be empty/,
    'empty composition object cannot be created';
};

subtest 'component type is important' => sub {
  plan tests => 3;

  my $f = npg_tracking::glossary::composition::factory->new();
  throws_ok { $f->add_component({'one' => 1,}) }
    qr/does not pass its type constraint/,
    'component should be an object';
  lives_ok { $f->add_component(DateTime->now()) }
    'can add an arbitrary object type to a composition';
  throws_ok { $f->add_component(DateTime->now()) }
    qr/Can\'t locate object method "compare_serialized"/,
    'components should implement "compare_serialized" method';
};

subtest 'create non-empty composition' => sub {
  plan tests => 14;

  my $f = npg_tracking::glossary::composition::factory->new();
  throws_ok { $f->add_component() } qr/Nothing to add/,
    'no attrs - error';

  my $cpname = q[npg_tracking::glossary::composition::component::illumina];
  use_ok ("$cpname");

  $f = npg_tracking::glossary::composition::factory->new();
  my $c = $cpname->new(id_run => 1, position => 2);
  throws_ok { $f->add_component($c, $c) }
    qr/Duplicate entry in arguments to add/,
    'add one component twice in one call';

  lives_ok { $f->add_component($c) } 'add one component';
  throws_ok { $f->add_component($c) } qr/already exists/,
    'error adding the same component second time';
  my $composotion = $f->create_composition();
  isa_ok ($composotion, 'npg_tracking::glossary::composition');
  is ($composotion->num_components, 1, 'one component');
  my $c1 = $cpname->new(id_run => 1, position => 2, subset => 'all');
  throws_ok { $f->add_component($c1) }
    qr/Factory closed/, 'cannot add further components';
  throws_ok { $f->create_composition() }
    qr/Factory closed/, 'cannot create further compositions';

  $f = npg_tracking::glossary::composition::factory->new();
  lives_ok { $f->add_component($c);
             $f->add_component($c1); } 'added two vomponents';
  $composotion = $f->create_composition();
  isa_ok ($composotion, 'npg_tracking::glossary::composition');
  is ($composotion->num_components, 2, 'two components');
  throws_ok { $f->add_component($c1) }
    qr/Factory closed/, 'cannot add further components';
  throws_ok { $f->create_composition() }
    qr/Factory closed/, 'cannot create further compositions';  
};



1;

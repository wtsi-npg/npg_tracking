use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

use_ok ('npg_tracking::glossary::composition::factory');

subtest 'empty composition cannot be created' => sub {
  plan tests => 2;

  my $f = npg_tracking::glossary::composition::factory->new();
  isa_ok ($f, 'npg_tracking::glossary::composition::factory');
  throws_ok { $f->create_composition() } qr/Composition cannot be empty/,
    'empty composition object cannot be created';
};

subtest 'create non-empty composition' => sub {
  plan tests => 14;

  my $cpname = q[npg_tracking::glossary::composition::component::illumina];
  use_ok ("$cpname");

  my $f = npg_tracking::glossary::composition::factory->new();
  throws_ok { $f->add_component() } qr/Nothing to add/,
    'no attrs - error';
  throws_ok { $f->add_component({'one' => 1,}) }
    qr/A new member value for components does not pass its type constraint/,
    'wrong type - error';

  my $c = $cpname->new(id_run => 1, position => 2);
  throws_ok { $f->add_component($c, $c) }
    qr/Duplicate entry in arguments to add/,
    'add one component twice in one call';
  lives_ok { $f->add_component($c) } 'add one component';
  throws_ok { $f->add_component($c) } qr/already exists/,
    'error adding the same component second time';
  my $c = $f->create_composition();
  isa_ok ($c, 'npg_tracking::glossary::composition');
  is ($c->num_components, 1, 'one component');
  my $c1 = $cpname->new(id_run => 1, position => 2, subset => 'all');
  throws_ok { $f->add_component($c1) }
    qr/'Factory closed/, 'cannot add further components';
  throws_ok { $f->create_composition() }
    qr/'Factory closed/, 'cannot create further compositions';

  $f = npg_tracking::glossary::composition::factory->new();
  lives_ok { $f->add_component($c);
             $f->add_component($c1); } 'added two vomponents';
  $c = $f->create_composition();
  isa_ok ($c, 'npg_tracking::glossary::composition');
  is ($c->num_components, 2, 'two components');
  throws_ok { $f->add_component($c1) }
    qr/'Factory closed/, 'cannot add further components';
  throws_ok { $f->create_composition() }
    qr/'Factory closed/, 'cannot create further compositions';  
};



1;

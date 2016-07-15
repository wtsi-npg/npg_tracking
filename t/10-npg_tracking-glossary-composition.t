use strict;
use warnings;
use Test::More tests => 8;
use Test::Exception;

my $pname = q[npg_tracking::glossary::composition];
my $cpname = q[npg_tracking::glossary::composition::component::illumina];
use_ok ("$pname");
use_ok ("$cpname");
  use_ok 'npg_tracking::glossary::composition::factory';

subtest 'empty composition' => sub {
  plan tests => 2;
 throws_ok {npg_tracking::glossary::composition->new()}
    qr/Attribute \(components\) is required/,
    'empty composition object cannot be created';
  throws_ok {npg_tracking::glossary::composition->new(components => [])}
    qr/Composition cannot be empty/,
    'empty composition object cannot be created';
};

subtest 'maintaining composition integrity' => sub {
  plan tests => 3;

  my $composition = $pname->new(
    components => [$cpname->new(id_run => 1, position => 2)]);
  lives_ok {$composition->freeze()} 'can serialize composition';
  throws_ok { push @{$composition->components}, $cpname->new(id_run => 1, position => 3)}
    qr/Can\'t locate object method "components"/,
    'cannot push directly to the components array';
  throws_ok { $composition->components->[0] = 3 }
    qr/Can\'t locate object method "components"/,
    'cannot reassign a component';
};

subtest 'getting, finding, counting, returning a list' => sub {
  plan tests => 20;

  my $c = $cpname->new(id_run => 1, position => 2);
  my $cmps = $pname->new(components => [$c]);

  throws_ok { $cmps->find() } qr/Object to compare to should be given/,
    'argument is needed';
  throws_ok { $cmps->find(2) }
    qr/Expect object of class npg_tracking::glossary::composition::component::illumina/,
    'argument should be a component of teh same class';
  throws_ok { $cmps->find([1, 2]) }
    qr/Expect object of class npg_tracking::glossary::composition::component::illumina/,
    'argument should be a component of the same class';
    
  my $found = $cmps->find($c);
  ok($found && (ref $found eq $cpname), 'found an object');
  my $c1 = $cpname->new(id_run => 1, position => 3);
  is($cmps->find($c1), undef, 'not found');
  isa_ok($cmps->get_component(0), $cpname, 'retrieved component');
  is($cmps->get_component(1), undef, 'retrieved undefined');
  isa_ok($cmps->get_component(-1), $cpname, 'retrieved component');

  is($cmps->num_components, 1, 'one component');
  my @l = $cmps->components_list();
  is(scalar @l, 1, 'one component');

  my $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c, $c1);
  $cmps = $f->create_composition();
  $found = $cmps->find($c);
  is($found->position, 2, 'correct position');
  ok($found && (ref $found eq $cpname), 'found an object');
  $found = $cmps->find($c1);
  is($found->position, 3, 'correct position');
  ok($found && (ref $found eq $cpname), 'found an object');

  is($cmps->num_components, 2, 'two components');
  isa_ok($cmps->get_component(0), $cpname, 'retrieved component');
  isa_ok($cmps->get_component(1), $cpname, 'retrieved component');
  my $last = $cmps->get_component(-1);
  isa_ok($last, $cpname, 'retrieved component');
  is($last->position, 3, 'correct position');
  @l = $cmps->components_list();
  is(scalar @l, 2, 'two components');
};

subtest 'serialization' => sub {
  plan tests => 6;

  my $f = npg_tracking::glossary::composition::factory->new();
  my $c1 = $cpname->new(subset => 'phix', id_run => 1, position => 2);
  my $c2 = $cpname->new(subset => 'human', id_run => 1, position => 2);
  my $d = '3e11d430bb943e01196a378ede86759d679285c59653999c972f1805effb9ab2';
  my $j = '{"components":[{"id_run":1,"position":2,"subset":"human"},{"id_run":1,"position":2,"subset":"phix"}]}';
  my $md5 = 'a9784a88f7611e1aaa4431ee190c8cf6';
  $f->add_component($c1, $c2);
  my $cmps = $f->create_composition();
  is ($cmps->digest(), $d, 'digest');
  is ($cmps->digest('md5'), $md5, 'md5 digest');
  is ($cmps->freeze(), $j, 'json');
  
  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c2, $c1);
  $cmps = $f->create_composition();
  is ($cmps->digest(), $d, 'digest is the same');
  is ($cmps->digest('md5'), $md5, 'md5 digest is the same');
  is ($cmps->freeze(), $j, 'json is the same'); 
};

subtest 'serialization to rpt' => sub {
  plan tests => 6;

  package test::npg_tracking::component;
  use Moose;
  with 'npg_tracking::glossary::composition::component';
  has 'attr1' => (
      isa       => 'Str',
      is        => 'ro',
      required  => 1,
  );
  1;

  package main;

  my $c1 = $cpname->new(id_run => 1, position => 2);
  is ($c1->freeze2rpt, '1:2', 'rpt component string');
  my $c2 = $cpname->new(id_run => 1, position => 3, tag_index => 6);
  is ($c2->freeze2rpt, '1:3:6', 'rpt component string');
  my $c3 = test::npg_tracking::component->new(attr1 => 'value1');
  throws_ok {$c3->freeze2rpt}
    qr/Either id_run or position key is undefined /,
    'failure to serialize component without core illumina attr';

  my $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c1, $c2);
  is ($f->create_composition()->freeze2rpt, '1:2;1:3:6', 'rpt composition string');

  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c2, $c1);
  is ($f->create_composition()->freeze2rpt, '1:2;1:3:6',
   'no dependency on the order components were added');

  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c3);
  throws_ok {$f->create_composition()->freeze2rpt}
    qr/Either id_run or position key is undefined/,
    'failure to serialize component without core illumina attr';
};

1;

use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

my $pname = q[npg_tracking::glossary::composition];
my $cpname = q[npg_tracking::glossary::composition::component::illumina];
use_ok ("$pname");
use_ok ("$cpname");

subtest 'empty composition' => sub {
  plan tests => 8;

  my $c = $cpname->new(id_run => 1, position => 2);
  my $cmps = $pname->new();
  isa_ok ($cmps, $pname);
  is ($cmps->has_no_components, 1, 'composition is empty');
  is ($cmps->num_components, 0, 'no components');
  lives_ok { $cmps->find($c) } 'calling find for an empty composition';
  lives_ok { $cmps->sort() } 'calling sort for an empty composition';
  throws_ok { $cmps->digest() }
    qr/Composition is empty, cannot compute digest/, 
    'digest for an empty composition - error';
  throws_ok { $cmps->component_values4attr() }
    qr/Attribute name is missing/, 
    'no attribute name - error';
  throws_ok { $cmps->component_values4attr('subset') }
    qr/Composition is empty, cannot compute values for subset/, 
    'subsets for an empty composition - error';
};

subtest 'adding components' => sub {
  plan tests => 14;

  my $c = $cpname->new(id_run => 1, position => 2);
  my $cmps = $pname->new();
  throws_ok { $cmps->add_component() } qr/Nothing to add/,
    'no attrs - error';
  throws_ok { $cmps->add_component({'one' => 1,}) }
    qr/A new member value for components does not pass its type constraint/,
    'wrong type - error';
  throws_ok { $cmps->add_component($c, $c) }
    qr/Duplicate entry in arguments to add/,
    'add one component twice in one call';
  lives_ok { $cmps->add_component($c) } 'add one component';
  is ($cmps->num_components, 1, 'one component is available');
  ok (!$cmps->has_no_components, 'some components');
  throws_ok { $cmps->add_component($c) } qr/already exists/,
    'error adding the same component second time'; 

  is (scalar $cmps->component_values4attr('subset'), 0, 'empty list of subsets');
  $cmps->add_component($cpname->new(id_run => 1, position => 2, subset => 'all'));
  is (join(q[ ], $cmps->component_values4attr('subset')), 'all', 'one subset value returned');
  $cmps->add_component($cpname->new(id_run => 1, position => 2, tag_index => 3, subset => 'human'));
  is (join(q[ ], $cmps->component_values4attr('subset')), 'all human', 'two subset values returned');
  $cmps->add_component($cpname->new(id_run => 1, position => 3, tag_index => 0, subset => 'human'));
  is (join(q[ ], $cmps->component_values4attr('subset')), 'all human', 'two subset values returned');
  is (join(q[ ], $cmps->component_values4attr('id_run')), '1', 'one run id value returned');
  is (join(q[ ], $cmps->component_values4attr('tag_index')), '3 0', 'two tag index values returned');
  is (scalar $cmps->component_values4attr('my_attr'), 0,
    'empty list of not implemented attribute values');
};

subtest 'finding' => sub {
  plan tests => 3;

  my $c = $cpname->new(id_run => 1, position => 2);
  my $cmps = $pname->new();
  is($cmps->find($c), undef, 'not found - array empty');
  $cmps->add_component($c);
  my $found = $cmps->find($c);
  ok($found && (ref $found eq $cpname), 'found an object');
  is($cmps->find($cpname->new(id_run => 1, position => 3)), undef, 'not found');
};

subtest 'serialization' => sub {
  plan tests => 7;

  my $cmps = $pname->new();
  throws_ok {$cmps->digest() }
    qr/Composition is empty, cannot compute digest/,
    'digest on an empty composition - error';

  my $c1 = $cpname->new(subset => 'phix', id_run => 1, position => 2);
  my $c2 = $cpname->new(subset => 'human', id_run => 1, position => 2);
  my $d = '3e11d430bb943e01196a378ede86759d679285c59653999c972f1805effb9ab2';
  my $j = '{"components":[{"id_run":1,"position":2,"subset":"human"},{"id_run":1,"position":2,"subset":"phix"}]}';
  my $md5 = 'a9784a88f7611e1aaa4431ee190c8cf6';
  $cmps->add_component($c1, $c2);
  is ($cmps->digest(), $d, 'digest');
  is ($cmps->digest('md5'), $md5, 'md5 digest');
  is ($cmps->freeze(), $j, 'json');
  $cmps = $pname->new();
  $cmps->add_component($c2, $c1);
  is ($cmps->digest(), $d, 'digest is the same');
  is ($cmps->digest('md5'), $md5, 'md5 digest is the same');
  is ($cmps->freeze(), $j, 'json is the same'); 
};

subtest 'serialization to rpt' => sub {
  plan tests => 7;

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

  my $cmps = $pname->new();
  is ($cmps->freeze2rpt, q[], 'empty rpt composition string');
  $cmps->add_component($c2);
  $cmps->add_component($c1);
  is ($cmps->freeze2rpt, '1:2;1:3:6', 'rpt composition string');

  $cmps = $pname->new();
  $cmps->add_component($c1);
  $cmps->add_component($c2);
  is ($cmps->freeze2rpt, '1:2;1:3:6',
   'no dependency on the order components were added');

  $cmps = $pname->new();
  $cmps->add_component($c3);
  throws_ok {$cmps->freeze2rpt}
    qr/Either id_run or position key is undefined/,
    'failure to serialize component without core illumina attr';
};

1;

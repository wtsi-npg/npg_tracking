use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;

use_ok ('npg_tracking::glossary::composition::component');

package npg_tracking::composition::component::test;
use Moose;
with 'npg_tracking::glossary::composition::component';
has 'attr_1' => (isa => 'Int', is => 'ro', required => 1,);
has 'attr_2' => (isa => 'Str', is => 'ro', required => 1,);
has 'attr_3' => (isa => 'Maybe[Int]', is => 'ro', required => 0,);
1;

package main;

my $pname = q[npg_tracking::composition::component::test];

subtest 'object with all attrs defined' => sub {
  plan tests => 6;

  my $c = $pname->new(attr_2 => 'human', attr_1 => 1, attr_3 => 3);
  isa_ok ($c, $pname);
  my $j = '{"attr_1":1,"attr_2":"human","attr_3":3}';
  is ($c->freeze, $j, 'serialization to an ordered json string');
  my $c1 = $pname->thaw($j);
  isa_ok ($c1, $pname);
  is ($c1->attr_1, 1);
  is ($c1->attr_3, 3);
  is ($c1->attr_2, 'human');
};

subtest 'object with optional attrs undefined' => sub {
  plan tests => 10;

  for my $c ((
    $pname->new(attr_2 => 'human', attr_1 => 1),
    $pname->new(attr_2 => 'human', attr_1 => 1, attr_3 => undef) )) {
    my $j = '{"attr_1":1,"attr_2":"human"}';
    is ($c->freeze, $j, 'serialization to an ordered json string');
    my $c1 = $pname->thaw($j);
    isa_ok ($c1, $pname);
    is ($c1->attr_1, 1);
    is ($c1->attr_2, 'human');
    is ($c1->attr_3, undef);
  }
};

subtest 'JSON serialization' => sub {
  plan tests => 5;

  my $c = $pname->new(attr_2 => 'human', attr_1 => 1, attr_3 => 3);
  my $j = '{"attr_1":1,"attr_2":"human","attr_3":3}';
  is ($c->freeze, $j, 'serialization to an ordered json string');

  my $c1 = $pname->thaw($j);
  lives_ok { $pname->thaw($j, component_class => $pname) }
    'can supply component class';
  lives_ok { $pname->thaw($j, component_class => 'dfggfg') }
    'can supply an arbitrary component class';

  $j = '{"__CLASS__":"npg_tracking::composition::component::test","attr_1":1,"attr_2":"human","attr_3":3}';
  is ($c->freeze(with_class_names => 1), $j,
    'serialization to an ordered json string with a class name');
 
  $j = '{"__CLASS__":"npg_tracking::composition::component::test-83.3","attr_1":1,"attr_2":"human","attr_3":3}';
  lives_ok { $pname->thaw($j) }
    'can be deserialized from a string containing the class name';
};

subtest 'compare components' => sub {
  plan tests => 5;

  my $c  = $pname->new(attr_2 => 'human', attr_1 => 1, attr_3 => 3);
  my $c1 = $pname->new(attr_2 => 'human', attr_1 => 2, attr_3 => 3);
  throws_ok { $c->compare_serialized() }
    qr/Object to compare to should be given/,
    'no other object - error';
  throws_ok { $c->compare_serialized([qw/tag run subset/]) }
    qr/Expect object of class $pname to compare to/,
    'wrong object type - error';
  is ($c->compare_serialized($c),   0, 'component equals itself');
  is ($c->compare_serialized($c1), -1, 'this component is "less" than the other');
  is ($c1->compare_serialized($c),  1, 'this component is "more" than the other');
};

subtest 'compute digest' => sub {
  plan tests => 9;

  my $d   = 'b2d58eb4175647b1dda29fe3a1a6603c80103ad710164905c04b4bca384434e9';
  my $md5 = 'c60f2dec90ccb01ee1443e9f4cbd000e';
  my $c  = $pname->new(attr_2 => 'human', attr_1 => 1);
  is($c->digest, $d, 'sha256 digest');
  is($c->digest('md5'), $md5, 'md5');
  is($c->digest('some'), $d, 'sha256 digest');
  $c  = $pname->new(attr_2 => 'human', attr_1 => 1, attr_3 => undef);
  is($c->digest, $d, 'the same sha256 digest');
  is($c->digest('md5'), $md5, 'the same md5');
  $c  = $pname->new(attr_2 => 'human', attr_1 => 1, attr_3 => 5);
  $d   = '851381070101f38b58b7955cf78f983b7f4fcf086e0d33424769a9eca1a4910c';
  $md5 = '279b9424281485054fd970e227e938ea';
  is($c->digest, $d, 'different sha256 digest');
  is($c->digest('md5'), $md5, 'different md5');
  $c  = $pname->new(attr_1 => 1, attr_3 => 5, attr_2 => 'human');
  is($c->digest, $d, 'the same sha256 digest');
  is($c->digest('md5'), $md5, 'the same md5');
};

1;

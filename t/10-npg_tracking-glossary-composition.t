use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use List::Util qw/shuffle/;
use List::MoreUtils qw/uniq/;

my $pname = q[npg_tracking::glossary::composition];
my $cpname = q[npg_tracking::glossary::composition::component::illumina];
use_ok ("$pname");
use_ok ("$cpname");
use_ok 'npg_tracking::glossary::composition::factory';

package test::npg_tracking::component;
use Moose;
with 'npg_tracking::glossary::composition::component';
has 'attr1' => (
      isa       => 'Str',
      is        => 'ro',
      required  => 1,
);
package main;

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


subtest 'find for a large number of components' => sub {

  my @components = ();
  my @no_components = ();
  for my $i ((0 .. 10)) {
    push    @components, $cpname->new(id_run => 1, position => 2, tag_index => $i);
    push @no_components, $cpname->new(id_run => 3, position => 2, tag_index => $i);
       push @components, $cpname->new(id_run => 1, position => 3, tag_index => $i);
    push @no_components, $cpname->new(id_run => 1, position => 4, tag_index => $i);
    push @components, $cpname->new(id_run => 1, position => 3, tag_index => $i, subset => 'phix');
    push @components, $cpname->new(id_run => 1, position => 3, tag_index => $i, subset => 'human');
  }
  push @components, $cpname->new(id_run => 1, position => 3);
  push @components, $cpname->new(id_run => 1, position => 3, subset => 'phix');
  push @components, $cpname->new(id_run => 1, position => 3, subset => 'human');
  push @no_components, $cpname->new(id_run => 1, position => 5);
  push @no_components, $cpname->new(id_run => 2, position => 3, subset => 'phix');
  push @no_components, $cpname->new(id_run => 1, position => 3, subset => 'cat');

  plan tests => (scalar @components ) * 2 + (scalar @no_components);

  my $f = npg_tracking::glossary::composition::factory->new();
  @components = shuffle @components;
  for my $c (@components) {
    $f->add_component($c);
  }
  my $composition = $f->create_composition();
  @components = shuffle @components;
  for my $c (@components) {
    my $found = $composition->find($c);
    ok ($found, 'component found');
    is($found->digest, $c->digest, 'correct component');
  }

  for my $c (@no_components) {
    ok (!$composition->find($c), 'component not found');
  }
};

subtest 'serialization' => sub {
  plan tests => 9;

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
  throws_ok {$cmps->freeze(some_option => 1)}
    qr/Options not recognised, allowed option - with_class_names/,
    'wrong option - error';
  is ($cmps->freeze(with_class_names => 0), $j, 'json');

  my $version = `git describe --dirty --always`;
  $version =~ s/\s+//;
  my $ej = qr/\{"__CLASS__":"npg_tracking::glossary::composition-(.+)?$version","components":\[\{"__CLASS__":"npg_tracking::glossary::composition::component::illumina-(.+)?$version","id_run":1,"position":2,"subset":"human"\},\{"__CLASS__":"npg_tracking::glossary::composition::component::illumina-(.+)?$version","id_run":1,"position":2,"subset":"phix"\}\]\}/;
  like ($cmps->freeze(with_class_names => 1), $ej, 'json with class names');
  
  $f = npg_tracking::glossary::composition::factory->new();
  $f->add_component($c2, $c1);
  $cmps = $f->create_composition();
  is ($cmps->digest(), $d, 'digest is the same');
  is ($cmps->digest('md5'), $md5, 'md5 digest is the same');
  is ($cmps->freeze(), $j, 'json is the same'); 
};

subtest 'deserialization from JSON' => sub {
  plan tests => 14;

  my $cclass = 'npg_tracking::glossary::composition::component::illumina';
  
  my $j = '{"components":[{"id_run":1,"position":2,"subset":"human"},{"id_run":1,"position":2,"subset":"phix"}]}';
  throws_ok { npg_tracking::glossary::composition->thaw($j) }
    qr/Component class unknown, try defining via component_class option/,
    'error if component class is not known';
  my $c;
  lives_ok { $c = npg_tracking::glossary::composition->thaw($j, component_class => $cclass) }
    'OK if component class supplied';
  isa_ok ($c, 'npg_tracking::glossary::composition');
  is ($c->num_components, 2, 'correct number of components');
  my @classes = uniq map { ref $_ } $c->components_list;
  ok ((scalar @classes == 1) && ($classes[0] eq $cclass), 'correct component class');

  $j = '{"__CLASS__":"npg_tracking::glossary::composition-100.0","components":[{"__CLASS__":"npg_tracking::glossary::composition::component::illumina-100.0","id_run":1,"position":2,"subset":"human"},{"__CLASS__":"npg_tracking::glossary::composition::component::illumina-100.0","id_run":1,"position":2,"subset":"phix"}]}';
  lives_ok { $c = npg_tracking::glossary::composition->thaw($j) }
    'OK if component class is in the JSON string';
  isa_ok ($c, 'npg_tracking::glossary::composition');

  $j = '{"__CLASS__":"npg_tracking::glossary::composition","components":[{"__CLASS__":"npg_tracking::glossary::composition::component::illumina","id_run":1,"position":2,"subset":"human"},{"__CLASS__":"npg_tracking::glossary::composition::component::illumina","id_run":1,"position":2,"subset":"phix"}]}';
  lives_ok { npg_tracking::glossary::composition->thaw($j) }
    'OK if component class is in the JSON string';

  my $tclass = 'test::npg_tracking::component';
  lives_ok { $c = npg_tracking::glossary::composition->thaw($j, component_class => $tclass) }
    'OK if component class is in the JSON string';
  @classes = uniq map { ref $_ } $c->components_list;
  ok ((scalar @classes == 1) && ($classes[0] eq $cclass), 'component class as in JSON string');

  lives_ok { $c = npg_tracking::glossary::composition->thaw($j,
    component_class => $tclass, enforce => 1) }
    'no error passign through an extra option';
  
  lives_ok { $c = npg_tracking::glossary::composition->thaw($j,
    component_class => $tclass, enforce_component_class => 0) }
    'OK if component class is in the JSON string and other component class is supplied';
  @classes = uniq map { ref $_ } $c->components_list;
  ok ((scalar @classes == 1) && ($classes[0] eq $cclass), 'component class as in JSON string');
  throws_ok { $c = npg_tracking::glossary::composition->thaw($j,
    component_class => $tclass, enforce_component_class => 1) }
    qr/Unexpected component class $cclass/,
    'error if component class is in the JSON string and other component class is enforced';
};

subtest 'serialization to rpt' => sub {
  plan tests => 6;

  my $c1 = $cpname->new(id_run => 1, position => 2);
  is ($c1->freeze2rpt, '1:2', 'rpt component string');
  my $c2 = $cpname->new(id_run => 1, position => 3, tag_index => 6);
  is ($c2->freeze2rpt, '1:3:6', 'rpt component string');
  my $c3 = test::npg_tracking::component->new(attr1 => 'value1');
  throws_ok {$c3->freeze2rpt}
    qr/Can't locate object method "id_run"/,
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
    qr/Can't locate object method "id_run"/,
    'failure to serialize component without core illumina attr';
};

1;

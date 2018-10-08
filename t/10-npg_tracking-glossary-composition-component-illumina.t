use strict;
use warnings;
use Test::More tests => 9;
use Test::Exception;

my $pname = q[npg_tracking::glossary::composition::component::illumina];
use_ok ("$pname");

subtest 'object with all attrs defined' => sub {
  plan tests => 7;

  my $c = $pname->new(subset => 'human', id_run => 1, position => 2, tag_index => 3);
  isa_ok ($c, $pname);
  my $j = '{"id_run":1,"position":2,"subset":"human","tag_index":3}';
  is ($c->freeze, $j, 'serialization to an ordered json string');
  my $c1 = $pname->thaw($j);
  isa_ok ($c1, $pname);
  is ($c1->id_run, 1);
  is ($c1->position, 2);
  is ($c1->tag_index, 3);
  is ($c1->subset, 'human');
};

subtest 'object with optional attrs undefined' => sub {
  plan tests => 26;

  for my $c ((
    $pname->new(id_run => 1, position => 2, tag_index => 3),
    $pname->new(id_run => 1, position => 2, tag_index => 3, subset => undef) ))
  {
    my $j = '{"id_run":1,"position":2,"tag_index":3}';
    is ($c->freeze, $j, 'serialization to an ordered json string');
    my $c1 = $pname->thaw($j);
    isa_ok ($c1, $pname);
    is ($c1->id_run, 1);
    is ($c1->position, 2);
    is ($c1->tag_index, 3);
    is ($c1->subset, undef);
    ok (!$c1->has_subset);
  }

  for my $c ((
    $pname->new(id_run => 1, position => 2),
    $pname->new(id_run => 1, position => 2, tag_index => undef, subset => undef) ))
  {
    $c = $pname->new(id_run => 1, position => 2);
    my $j = '{"id_run":1,"position":2}';
    is ($c->freeze, $j, 'serialization to an ordered json string');
    my $c1 = $pname->thaw($j);
    isa_ok ($c1, $pname);
    is ($c1->id_run, 1);
    is ($c1->position, 2);
    is ($c1->tag_index, undef);
    is ($c1->subset, undef);
  }
};

subtest 'errors when required attrs are undefined' => sub {
  plan tests => 6;

  throws_ok { $pname->new() } qr/Attribute \(id_run\) is required/,
    'no args constructor - error';
  throws_ok { $pname->new(id_run => 1) } qr/Attribute \(position\) is required/,
    'position undefined - error';
  throws_ok { $pname->new(position => 1) } qr/Attribute \(id_run\) is required/,
    'run id undefined - error';
  
  throws_ok { $pname->thaw() } qr/JSON string is required/,
    'no args to thaw - error';
  throws_ok { $pname->thaw(q[some]) } qr/malformed JSON string/,
    'plain string to thaw - error';
  throws_ok { $pname->thaw(q[{"id_run":1}]) }
    qr/Attribute \(position\) is required/,
    'position undefined - error';
};

subtest 'unknown attrs' => sub {
  plan tests => 6;

  throws_ok { $pname->new(id_run => 1, position => 2, id_position => 1) }
    qr/Found unknown attribute/,
    'invalid attr - error';
  my $c;
  lives_ok { $c = $pname->thaw(q[{"id_run":1,"position":2,"id_position":1}]) }
    'invalid attr - no error';
  isa_ok ($c, $pname);
  is ($c->id_run, 1);
  is ($c->position, 2);
  throws_ok { $c->id_position } qr/Can\'t locate object method \"id_position\"/,
    'error accessing undefined attribute';
};

subtest 'JSON serialization' => sub {
  plan tests => 5;

  my $c = $pname->new(id_run => 1, position => 2, tag_index => 3, subset => 'human');
  my $j = '{"id_run":1,"position":2,"subset":"human","tag_index":3}';
  is ($c->freeze, $j, 'serialization to an ordered json string');

  my $c1 = $pname->thaw($j);
  lives_ok { $pname->thaw($j, component_class => $pname) }
    'can supply component class';
  lives_ok { $pname->thaw($j, component_class => 'dfggfg') }
    'can supply an arbitrary component class';

  my $version = `git describe --dirty --always`;
  $version =~ s/\s+//;
  $j = qq({"__CLASS__":"npg_tracking::glossary::composition::component::illumina-$version","id_run":1,"position":2,"subset":"human","tag_index":3});
  is ($c->freeze(with_class_names => 1), $j,
    'serialization to an ordered json string with a class name');

  $j = '{"__CLASS__":"npg_tracking::glossary::composition::component::illumina-100.0","id_run":1,"position":2,"subset":"human","tag_index":3}';  
  lives_ok { $pname->thaw($j) }
    'can be deserialized from a string containing the class name';
};

subtest 'compare components' => sub {
  plan tests => 5;

  my $c  = $pname->new(id_run => 1, position => 2, tag_index => 1);
  my $c1 = $pname->new(id_run => 2, position => 2, tag_index => 1);
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
  plan tests => 8;

  my $d   = 'cb3bd5d6db5a0e67086cd7d88c53d7d6048af6cdc67efc61d706237b4bbefbb5';
  my $md5 = 'd99e452f9e7d8b68b50faed8f9cd1f3d';
  my $c  = $pname->new(id_run => 1, position => 2, tag_index => 1);
  is($c->digest, $d, 'sha256 digest');
  is($c->digest('md5'), $md5, 'md5');
  $c  = $pname->new(id_run => 1, position => 2, tag_index => 1, subset => undef);
  is($c->digest, $d, 'the same sha256 digest');
  is($c->digest('md5'), $md5, 'the same md5');
  $c  = $pname->new(id_run => 1, position => 2, subset => undef);
  $d   = '65485aca1f77dd273073b52784b1bda1c12163e41483a9e3abb05190c694e7f2';
  $md5 = '8124a07e43465bc48591768e67a00697';
  is($c->digest, $d, 'different sha256 digest');
  is($c->digest('md5'), $md5, 'different md5');
  $c  = $pname->new(position => 2, id_run => 1);
  is($c->digest, $d, 'the same sha256 digest');
  is($c->digest('md5'), $md5, 'the same md5');
};

subtest 'file names' => sub {
  plan tests => 6;

  my $c  = $pname->new(id_run => 1, position => 2);
  is($c->filename, '1_2', 'without tag index');
  $c  = $pname->new(id_run => 1, position => 2, tag_index => 1);
  is($c->filename, '1_2#1', 'with tag index');
  is($c->filename('.bam'), '1_2#1.bam', 'with tag index, extention given');
  is($c->filename('_table'), '1_2#1_table', 'extention without dot given');
  $c  = $pname->new(id_run => 1, position => 2, tag_index => 1, subset => 'phix');
  is($c->filename, '1_2#1_phix', 'with subset');
  $c  = $pname->new(id_run => 1, position => 2, subset => 'human');
  is($c->filename, '1_2_human', 'with subset, without tag index');
};

1;

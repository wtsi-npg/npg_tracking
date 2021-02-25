use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

my $package = 'npg_tracking::glossary::rpt';
use_ok($package);

subtest 'rpt string inflate' => sub {
  plan tests => 15;
  
  throws_ok {$package->inflate_rpt()}
    qr/rpt string argument is missing/,
    'no argument - error';
  throws_ok {$package->inflate_rpt('456;8')}
    qr/rpt string should not contain \';\'/,
    'rpt list delimeter present - error';
  throws_ok {$package->inflate_rpt('456')}
    qr/Both id_run and position should be defined non-zero values/,
    'no position - error';
  throws_ok {$package->inflate_rpt(':456')}
    qr/Argument \"\" isn't numeric/,
    'no run id - error';
  throws_ok {$package->inflate_rpt('2::456')} 
    qr/Argument \"\" isn't numeric/,
    'no position - error';
  throws_ok {$package->inflate_rpt('2:0')}
    qr/Both id_run and position should be defined non-zero values/,
    'position sero - error';
  throws_ok {$package->inflate_rpt('0:2:4')}
    qr/Both id_run and position should be defined non-zero values/,
    'run zero - error';  
  is_deeply($package->inflate_rpt('2:11'),
    {id_run=>2, position=>11}, 'correct output');
  is_deeply($package->inflate_rpt('2:11:'),
    {id_run=>2, position=>11}, 'correct output');
  is_deeply($package->inflate_rpt('2:11:0'),
    {id_run=>2, position=>11, tag_index=>0},
    'correct output, tag index zero is allowed');
  is_deeply($package->inflate_rpt('2:11:4'),
    {id_run=>2, position=>11, tag_index=>4},
    'correct output');
  throws_ok {$package->inflate_rpt('do:11:4')}
    qr/Argument \"do\" isn't numeric/,
    'id_run should be an integer';
  throws_ok {$package->inflate_rpt('3:do:4')}
    qr/Argument \"do\" isn't numeric/,
    'position should be an integer';
   throws_ok {$package->inflate_rpt('3:4:do')}
    qr/Argument \"do\" isn't numeric/,
    'tag_index should be an integer';
  is_deeply($package->inflate_rpt('2:11:3:extra'),
    {id_run=>2, position=>11, tag_index=>3},
    'only the first three substrings are taken into account');  
};

subtest 'deflate to rpt string' => sub {
  plan tests => 9;

  throws_ok {$package->deflate_rpt()}
    qr/Hash or object input expected/,
    'class method needs input';
  throws_ok {$package->deflate_rpt({position=>3})}
    qr/'id_run' key is undefined/,
    'no id_run - error';
  throws_ok {$package->deflate_rpt({id_run=>0,position=>3})}
    qr/'id_run' key is undefined/,
    'zero run id - error';
  throws_ok {$package->deflate_rpt({id_run=>5})}
    qr/'position' key is undefined/,
    'no position - error';
  throws_ok {$package->deflate_rpt({id_run=>5, position=>0})}
    qr/'position' key is undefined/,
    'zero position - error';
  is($package->deflate_rpt({id_run=>5, position=>6}),
    '5:6', 'correct output');
  is($package->deflate_rpt({id_run=>5, position=>6, subset=>'phix'}),
    '5:6', 'unknown key is disregarded');
  is($package->deflate_rpt({id_run=>5, position=>6, tag_index=>56}),
    '5:6:56', 'correct output');
  lives_ok { $package->deflate_rpt({id_run=>'bc', position=>'moo', tag_index=>'a'}) }
    'data type is not validated';
};

subtest 'deflate to rpt string for objects' => sub {
  plan tests => 3;

  package test::npg_tracking::rpt;
  use Moose;
  with $package;
  has [qw/id_run position tag_index subset/] => ( isa => 'Str', is => 'ro',);

  package main;
  
  my $o1 = test::npg_tracking::rpt->new(id_run    => 1,
                                        position  => 2,
                                        tag_index => 3,
                                        subset    => 'phix');
  my $o2 = test::npg_tracking::rpt->new(id_run    => 1,
                                        position  => 3,
                                        tag_index => 5);

  is($o1->deflate_rpt(), '1:2:3', 'representation of the object itself');
  is($o1->deflate_rpt($o2), '1:3:5', 'representation of the argument object');
  is($o1->deflate_rpt({id_run=>4,position=>22}), '4:22',
    'representation of the argument hash'); 
};

subtest 'rpt list string inflate' => sub {
  plan tests => 5;

  throws_ok {$package->inflate_rpts()}
    qr/rpt list string is not given/,
    'no input - error';
  is_deeply($package->inflate_rpts('1:2:3'),
    [{id_run=>1, position=>2, tag_index=>3}], 'a list of one hash');
  is_deeply($package->inflate_rpts('1:2:3;5:6'),
    [{id_run=>1, position=>2, tag_index=>3}, {id_run=>5, position=>6}],
    'a list of two hashes');
  is_deeply($package->inflate_rpts('1:2:3;5:6;'),
    [{id_run=>1, position=>2, tag_index=>3}, {id_run=>5, position=>6}],
    'list delimiter at the end is disregarded');
  throws_ok {$package->inflate_rpts(';1:2:3;5:6')}
    qr/rpt string argument is missing/,
    'list delimeter at the beginning of the string - error';
};

subtest 'deflate to rpt list string' => sub {
  plan tests => 5;

  throws_ok {$package->deflate_rpts()}
    qr/rpts array is missing/,
    'no input - error';
  throws_ok {$package->deflate_rpts('rpts')}
    qr/Array input expected/,
    'string input - error';
  throws_ok {$package->deflate_rpts({id_run=>2,position=>3})}
    qr/Array input expected/,
    'hash input - error';
  is($package->deflate_rpts([{id_run=>1, position=>2, tag_index=>3}]),
    '1:2:3', 'correct output for one rpt component');
  is($package->deflate_rpts(
    [{id_run=>1, position=>2, tag_index=>3}, {id_run=>5, position=>6}]),
    '1:2:3;5:6', 'correct output for two rpt components');
};

subtest 'tag_zero_rpt_list' => sub {
  plan tests => 3;

  is($package->tag_zero_rpt_list('1:2:3;1:3:3'), '1:2:0;1:3:0', 'correct output');
  is($package->tag_zero_rpt_list('1:2;1:3'), '1:2:0;1:3:0', 'correct output');
  is($package->tag_zero_rpt_list('1:2:4;1:3'), '1:2:0;1:3:0', 'correct output');
};

1;


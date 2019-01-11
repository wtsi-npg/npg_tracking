use strict;
use warnings;
use Test::More tests => 10;
use Test::Exception;
use Moose::Meta::Class;

use_ok (q[npg_tracking::glossary::moniker]);
use_ok (q[npg_tracking::glossary::composition]);
use ok (q[npg_tracking::glossary::composition::factory::rpt]);

my $class = Moose::Meta::Class->create('npg_test::moniker',
  ('superclasses' => ['npg_tracking::glossary::composition::factory::rpt_list'])
);
$class->add_attribute( '+rpt_list', {required => 0, predicate => 'has_rpt_list',});
$class->add_attribute('composition', {
                       isa        => q[npg_tracking::glossary::composition],
                       is         => q[ro],
                       required   => 0,
                       lazy_build => 1});
$class->add_method('_build_composition',
  sub {
    my $self = shift;
    if (!$self->has_rpt_list) {die 'Cannot build without rpt_list set';}
    return $self->create_composition();
  }
);
$class->make_immutable;

$class = Moose::Meta::Class->create_anon_class(
      superclasses=> ['npg_test::moniker'],
      roles       => [qw/npg_tracking::glossary::moniker MooseX::Getopt/] );
$class->make_immutable;
my $class_name = $class->name();

subtest 'test dynamically created test class' => sub {
  plan tests => 9;

  my $moniker;
  lives_ok {$moniker = $class_name->new()} 'created class, no args constructor';
  throws_ok {$moniker->file_name} qr/Cannot build without rpt_list set/,
    'error - failed to build composition';
  throws_ok {$moniker->dir_path} qr/Cannot build without rpt_list set/,
    'error - failed to build composition';
  
  lives_ok {$moniker = $class_name->new(rpt_list => '33:3:1')}
    'created class, rpt list defined in the constructor';
  lives_ok {$moniker->file_name} 'can generate file name';
  lives_ok {$moniker->dir_path} 'can generate dir name';

  my $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1}]}';
  lives_ok {$moniker = $class_name->new(composition =>
    npg_tracking::glossary::composition->thaw($json))}
    'created class, composition defined via the the constructor';
  lives_ok {$moniker->file_name} 'can generate file name';
  lives_ok {$moniker->dir_path} 'can generate dir name';  
};

subtest 'test compatibility with MooseX::Getopt' => sub {
  plan tests => 2;

  local @ARGV = qw/--rpt_list 33:3:1/;
  my $obj = $class_name->new_with_options();
  isa_ok ($obj, $class_name);
  is($obj->rpt_list, '33:3:1', 'rpt_list attribute value');
};

subtest 'no semantically meaningful name' => sub {
  plan tests => 12;
  
  my $m = $class_name->new(rpt_list => '33:4:1;34:4:1');
  my $d = '63ac7e392f2e8599ca11cf543253cb38';
  is ($m->file_name, $d, 'run ids are different, file name is based on a digest');
  is ($m->dir_path,  $d, 'run ids are different, dir. path is based on a digest');

  $m = $class_name->new(rpt_list => '33:4:1;33:5:2');
  $d = '43736c430931af8a6b983bdd2ee171f5';
  is ($m->file_name, $d, 'tag indices are different, file name is based on a digest');
  is ($m->dir_path,  $d, 'tag indices are different, dir. path is based on a digest');

  $m = $class_name->new(rpt_list => '33:4:0;33:5:2');
  $d = '3aab3821306519e5a2e0d7afe32f605b';
  is ($m->file_name, $d, 'tag indices are different, file name is based on a digest');
  is ($m->dir_path,  $d, 'tag indices are different, dir. path is based on a digest');

  $m = $class_name->new(rpt_list => '33:4;33:5:2');
  $d = '967ab6c26b4e9dd1c0215cb0107b8779';
  is ($m->file_name, $d, 'tag indices are different, file name is based on a digest');
  is ($m->dir_path,  $d, 'tag indices are different, dir. path is based on a digest');

  my $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"subset":"phix"}
  ]}';
  $d = '0fef736f8e41e28ebbe13b710e726ad7';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, $d, 'subsets are different, file name is based on a digest');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"subset":"phix"}
  ]}';
  $d = '984f91f06ff08eb6e4f5fc31995e4c4e';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, $d, 'subsets are different, file name is based on a digest');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":3},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":3,"subset":"phix"}
  ]}';
  $d = 'd2a14c5e0bb12f19de529783ffb5b471';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, $d, 'subsets are different, file name is based on a digest');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":3,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":3,"subset":"phix"}
  ]}';
  $d = 'a6e882824b144f3d6103e3a12625bec2';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, $d, 'subsets are different, file name is based on a digest');
};

subtest 'names for one-compoment compositions' => sub {
  plan tests => 12;

  my $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1}]}';
  my $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048_1', 'file name for a lane entity');
  is ($m->dir_path, 'lane1', 'dir. path for a lane entity');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"subset":"phix"}]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048_1_phix', 'file name for a lane, phix subset');
  is ($m->dir_path, 'lane1', 'dir. path for a lane, phix subset');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":0}]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048_2#0', 'file name for tag zero');
  is ($m->dir_path, 'lane2/plex0', 'dir. path for tag zero');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":0,"subset":"phix"}]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048_2#0_phix', 'file name for tag zero, phix subset');
  is ($m->dir_path, 'lane2/plex0', 'dir. path for tag zero, phix subset');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":4,"tag_index":8}]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048_4#8', 'file name for a plex');
  is ($m->dir_path, 'lane4/plex8', 'dir. path for a plex');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":3,"tag_index":33,"subset":"human"}]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048_3#33_human', 'file name for a plex, human subset');
  is ($m->dir_path, 'lane3/plex33', 'dir. path for a plex, human subset');
};

subtest 'names for multi-compoment compositions across the whole run' => sub {
  plan tests => 12;

  my $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2}]}';
  my $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048', 'file name for lanes entity');
  is ($m->dir_path, q[], 'dir. path forlanes entity');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"subset":"phix"},
   {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"subset":"phix"}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048_phix', 'file name for lanes, phix subset');
  is ($m->dir_path, q[], 'dir. path for lanes, phix subset');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":0},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":0}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048#0', 'file name for tag zero');
  is ($m->dir_path, 'plex0', 'dir. path for tag zero');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":0,"subset":"phix"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":0,"subset":"phix"}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048#0_phix', 'file name for tag zero, phix subset');
  is ($m->dir_path, 'plex0', 'dir. path for tag zero, phix subset');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":8},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":8},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":3,"tag_index":8},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":4,"tag_index":8}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048#8', 'file name for a plex');
  is ($m->dir_path, 'plex8', 'dir. path for a plex');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":8,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":8,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":3,"tag_index":8,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":4,"tag_index":8,"subset":"human"}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048#8_human', 'file name for a plex, human subset');
  is ($m->dir_path, 'plex8', 'dir. path for a plex, human subset');
};

subtest 'names for multi-compoment compositions across selected lanes' => sub {
  plan tests => 12;

  my $selected = 1;

  my $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2}]}';
  my $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name($selected), '26048_1-2', 'file name for lanes entity');
  is ($m->dir_path($selected), 'lane1-2', 'dir. path forlanes entity');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"subset":"phix"},
   {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"subset":"phix"}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name($selected), '26048_1-2_phix', 'file name for lanes, phix subset');
  is ($m->dir_path($selected), 'lane1-2', 'dir. path for lanes, phix subset');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":0},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":0}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name($selected), '26048_1-2#0', 'file name for tag zero');
  is ($m->dir_path($selected), 'lane1-2/plex0', 'dir. path for tag zero');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":0,"subset":"phix"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":0,"subset":"phix"}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name($selected), '26048_1-2#0_phix', 'file name for tag zero, phix subset');
  is ($m->dir_path($selected), 'lane1-2/plex0', 'dir. path for tag zero, phix subset');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":8},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":8},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":3,"tag_index":8},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":4,"tag_index":8}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name($selected), '26048_1-2-3-4#8', 'file name for a plex');
  is ($m->dir_path($selected), 'lane1-2-3-4/plex8', 'dir. path for a plex');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":8,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":8,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":3,"tag_index":8,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":4,"tag_index":8,"subset":"human"}
  ]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name($selected), '26048_1-2-3-4#8_human', 'file name for a plex, human subset');
  is ($m->dir_path($selected), 'lane1-2-3-4/plex8', 'dir. path for a plex, human subset');
};

subtest 'full file name' => sub {
  plan tests => 17;

  my $p = 'npg_tracking::glossary::moniker';

  throws_ok { $p->file_name_full() }
    qr/File name base should be given/, 'error if no arguments are given';
  throws_ok { $p->file_name_full(ext => 'bam') }
    qr/The argument list should contain a file name/,
    'error if one option is given, but no base file name';
  throws_ok { $p->file_name_full(ext => 'bam', suffix => 'F0xB00') }
    qr/The argument list should contain a file name/,
    'error if two options are given, but no base file name';

  my $name = '26219_1';
  is ($p->file_name_full($name), '26219_1', 'no-options file name');
  is ($p->file_name_full($name, ext => 'bam'), '26219_1.bam', 'file name with an extention');
  is ($p->file_name_full($name, suffix => 'F0xB00'), '26219_1_F0xB00', 'file name with a suffix');
  is ($p->file_name_full($name, ext => 'stats', suffix => 'F0xB00'), '26219_1_F0xB00.stats',
    'file name with both extension and suffix');
  is ($p->file_name_full($name, ext => 'stats.md5', suffix => 'F0xB00'), '26219_1_F0xB00.stats.md5',
    'file name with both extension and suffix');

  throws_ok { $p->file_name_full($name, other => 'o') }
    qr/The following options are not recognised: other\. Accepted options: suffix, ext\./,
    'unrecognised option - error';
  throws_ok { $p->file_name_full($name, other => 'o', suffix => 'F0xB00') }
    qr/The following options are not recognised: other\. Accepted options: suffix, ext\./,
    'unrecognised option - error';
  throws_ok { $p->file_name_full($name, a => 'a', suffix => 'F0xB00', b => 'b') }
    qr/The following options are not recognised: a, b\. Accepted options: suffix, ext\./,
    'unrecognised options - error';

  $name = '26219_1#3';
  is ($p->file_name_full($name, ext => 'bam'), '26219_1#3.bam', 'file name with an extention');
  is ($p->file_name_full($name, suffix => 'F0xB00'), '26219_1#3_F0xB00', 'file name with a suffix');
  is ($p->file_name_full($name, ext => 'stats', suffix => 'F0xB00'), '26219_1#3_F0xB00.stats',
    'file name with both extension and suffix');

  $name = '26219_1#3_phix';
  is ($p->file_name_full($name, ext => 'bam'), '26219_1#3_phix.bam', 'file name with an extention');
  is ($p->file_name_full($name, suffix => 'F0xB00'), '26219_1#3_phix_F0xB00', 'file name with a suffix');
  is ($p->file_name_full($name, ext => 'stats', suffix => 'F0xB00'), '26219_1#3_phix_F0xB00.stats',
    'file name with both extension and suffix');
};

1;




use strict;
use warnings;
use Test::More tests => 11;
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
  plan tests => 13;
  
  my $m = $class_name->new(rpt_list => '33:4:1;34:4:1');
  my $d = '30866d9fad890b76da390f63d18e74fc08323e8b356c763b3c3568ec228e6a15';
  is ($m->file_name, $d, 'run ids are different, file name is based on a digest');
  is ($m->dir_path,  $d, 'run ids are different, dir. path is based on a digest');

  $m = $class_name->new(rpt_list => '33:4:1;33:5:2');
  $d = '8aa4ed602a5ebbf782755422bf3328ab5c40ef6723e19806e9deef099ebdbec8';
  is ($m->file_name, $d, 'tag indices are different, file name is based on a digest');
  is ($m->dir_path,  $d, 'tag indices are different, dir. path is based on a digest');

  $m = $class_name->new(rpt_list => '33:4:0;33:5:2');
  $d = '52a945319058c7ab3a0f925276fcc4acafa2e68c7e3bcaecde955eb0eb2d0f74';
  is ($m->file_name, $d, 'tag indices are different, file name is based on a digest');
  is ($m->dir_path,  $d, 'tag indices are different, dir. path is based on a digest');

  $m = $class_name->new(rpt_list => '33:4;33:5:2');
  $d = '86c6c946c00a0f7734035b2776961eb3ae049682864831ff4f12b9f096a7261e';
  is ($m->file_name, $d, 'tag indices are different, file name is based on a digest');
  is ($m->dir_path,  $d, 'tag indices are different, dir. path is based on a digest');

  my $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"subset":"phix"}
  ]}';
  $d = 'f4739972d5097636df3bf2ce6dcd8c8284c1b4dc90ccd1432870f08b93755b48';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, $d, 'subsets are different, file name is based on a digest');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"subset":"phix"}
  ]}';
  $d = '9015e2ef5d9594b5a15aca7877d0a83fbe41033fa6fbaaa9deebd54ea4d72400';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, $d, 'subsets are different, file name is based on a digest');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":3},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":3,"subset":"phix"}
  ]}';
  $d = 'b9cb8de3aa3690565ca105a7791f6b29e9a00bb79c62a6263a5eb33aec48c6da';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, $d, 'subsets are different, file name is based on a digest');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"tag_index":3,"subset":"human"},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2,"tag_index":3,"subset":"phix"}
  ]}';
  $d = '5aacdb6c43330130ee6962a6cd1794ee0ba6878d9bce0e2d48000349eec44b71';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, $d, 'subsets are different, file name is based on a digest');
  is ($m->generic_name, $d, 'generic name');
};

subtest 'names for one-compoment compositions' => sub {
  plan tests => 14;

  my $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1}]}';
  my $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048_1', 'file name for a lane entity');
  is ($m->generic_name, '79ddd58fd7943302150dd2db2afde3c7afcc13f69d073a3e1cc85ec1400ccb78',
    'generic name');
  is ($m->dir_path, 'lane1', 'dir. path for a lane entity');

  $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1,"subset":"phix"}]}';
  $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048_1_phix', 'file name for a lane, phix subset');
  is ($m->generic_name, '1ed187e3130552aa386c6084f5dd765f218f9e41b314d78a2b8300de345c7bf9',
    'generic name');
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
  plan tests => 14;

  my $json = '{"__CLASS__":"npg_tracking::glossary::composition", "components":[
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":1},
  {"__CLASS__":"npg_tracking::glossary::composition::component::illumina",
   "id_run":26048,"position":2}]}';
  my $m = $class_name->new(composition => npg_tracking::glossary::composition->thaw($json));
  is ($m->file_name, '26048', 'file name for lanes entity');
  is ($m->generic_name, '693fe7206a05cfa45b617adcf36449fe6e711fbb465226fcbea76d9427001e97',
    'generic name');
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
  is ($m->generic_name, '4add3c84b63dd3158ae8a12060f6f29aadc5c37d83cbddd970092b4f2f60975d',
    'generic name');
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

subtest 'parse file name' => sub {
  plan tests => 21;

  my $p = 'npg_tracking::glossary::moniker';
  is_deeply($p->parse_file_name('1234_4#5'),
    {id_run => 1234, position => 4, tag_index => 5});
  is_deeply($p->parse_file_name('1234_4#0'),
    {id_run => 1234, position => 4, tag_index => 0});
  is_deeply($p->parse_file_name('1234_4'), {id_run => 1234, position => 4});
  is_deeply($p->parse_file_name('1234#4'), {id_run => 1234, tag_index => 4});
  is_deeply($p->parse_file_name('1234#0'), {id_run => 1234, tag_index => 0});

  is_deeply($p->parse_file_name('1234_4#5_phix'),
    {id_run => 1234, position => 4, tag_index => 5, suffix => 'phix'});
  is_deeply($p->parse_file_name('1234_4#0_phix'),
    {id_run => 1234, position => 4, tag_index => 0, suffix => 'phix'});
  is_deeply($p->parse_file_name('1234_4_phix'),
    {id_run => 1234, position => 4, suffix => 'phix'});
  is_deeply($p->parse_file_name('1234#4_phix'),
    {id_run => 1234, tag_index => 4, suffix => 'phix'});
  is_deeply($p->parse_file_name('1234#0_phix'),
    {id_run => 1234, tag_index => 0, suffix => 'phix'});

  is_deeply($p->parse_file_name('1234_4#5_phix.cram'),
    {id_run => 1234, position => 4, tag_index => 5, suffix => 'phix', extension => 'cram'});
  is_deeply($p->parse_file_name('1234_4#5_phix.cram.crai'),
    {id_run => 1234, position => 4, tag_index => 5, suffix => 'phix', extension => 'cram.crai'});
  is_deeply($p->parse_file_name('1234_4#0_phix.cram'),
    {id_run => 1234, position => 4, tag_index => 0, suffix => 'phix', extension => 'cram'});
  is_deeply($p->parse_file_name('1234_4_phix.cram'),
    {id_run => 1234, position => 4, suffix => 'phix', extension => 'cram'});
  is_deeply($p->parse_file_name('1234#4_phix.cram'),
    {id_run => 1234, tag_index => 4, suffix => 'phix', extension => 'cram'});
  is_deeply($p->parse_file_name('1234#0_phix.cram'),
    {id_run => 1234, tag_index => 0, suffix => 'phix', extension => 'cram'});

  is_deeply($p->parse_file_name('1234_4#5.cram'),
    {id_run => 1234, position => 4, tag_index => 5, extension => 'cram'});
  is_deeply($p->parse_file_name('1234_4#0.cram'),
    {id_run => 1234, position => 4, tag_index => 0, extension => 'cram'});
  is_deeply($p->parse_file_name('1234_4.cram'),
    {id_run => 1234, position => 4, extension => 'cram'});
  is_deeply($p->parse_file_name('1234#4.cram'),
    {id_run => 1234, tag_index => 4, extension => 'cram'});
  is_deeply($p->parse_file_name('1234#0.cram'),
    {id_run => 1234, tag_index => 0, extension => 'cram'});    
};

1;




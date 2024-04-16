use strict;
use warnings;
use Test::More tests => 31;
use Test::Exception;
use Test::Deep;
use File::Temp qw(tempdir);
use Moose::Meta::Class;
use File::Copy;
use File::Slurp qw(edit_file_lines);

use_ok(q{npg_tracking::illumina::run::long_info});

my $basedir = tempdir( CLEANUP => 1 );

subtest 'retrieving information from runParameters.xml' => sub {
  plan tests => 177;

  my $rf = join q[/], $basedir, 'runfolder';
  mkdir $rf;

  my $class = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rf}},
    roles   => [qw/npg_tracking::illumina::run::long_info/]);

  my @rp_files = qw/
    runParameters.hiseq4000.xml
    runParameters.hiseq.rr.single.xml
    runParameters.hiseq.rr.twoind.xml
    runParameters.hiseq.rr.xml
    runParameters.hiseq.xml
    runParameters.hiseqx.upgraded.xml
    runParameters.hiseqx.xml
    runParameters.miseq.xml
    RunParameters.nextseq.xml
    RunParameters.novaseq.xml
    RunParameters.novaseq.xp.xml
    RunParameters.novaseq.xp.v1.5.xml
    runParameters.hiseq.rr.truseq.xml
    RunParameters.novaseqx.xml
    RunParameters.novaseqx.prod.xml 
                  /;
  my $dir = 't/data/run_params';

  my @platforms = qw/HiSeq HiSeq4000 HiSeqX
                     MiSeq NextSeq NovaSeq NovaSeqX/;
  my @patterned_flowcell_platforms = map {lc $_}
                                     qw/HiSeq4000 HiSeqX NovaSeq NovaSeqX/;

  for my $f (@rp_files) {
    note $f;
    my ($name, $platform) = $f =~ /([r|R]unParameters)\.([^.]+)/;
    $name = join q[/], $rf, $name . '.xml';
    copy(join(q[/],$dir,$f), $name) or die 'Failed to copy file';

    my $li = $class->new_object();

    foreach my $p ( grep {$_ ne 'HiSeq'} @platforms) {
      my $method = join q[_], 'platform', $p;
      if ($platform eq lc $p) {
        ok ($li->$method(), "platform is $p");
      } else {
        ok (!$li->$method(), "platform is not $p");
      }
    }

    my ($pl) = $f =~ /[r|R]unParameters\.(.+\.xml)\Z/;
    if ($pl =~ /hiseq\.(?:xml|rr)/ ) {
      ok ($li->platform_HiSeq(), 'platform is HiSeq');
      is ($li->workflow_type, '', 'workflow type is not known');
    } else {
      ok (!$li->platform_HiSeq(), 'platform is not HiSeq');
    }

    if ($f =~ /\.rr\./) {
      ok ($li->is_rapid_run(), 'is rapid run');
      ok (!$li->all_lanes_mergeable(), 'lanes are not mergeable');
      if ($f =~ /\.truseq\./) {
        ok (!$li->is_rapid_run_v2(), 'rapid run version is not 2');
        ok ($li->is_rapid_run_v1(), 'rapid run version is 1');
      } else {
        ok ($li->is_rapid_run_v2(), 'rapid run version is 2');
        ok (!$li->is_rapid_run_v1(), 'rapid run version is not 1');
      }
       ok (!$li->is_rapid_run_abovev2(), 'rapid run version is not above 2');
    } else {
      ok (!$li->is_rapid_run(), 'is not rapid run');
      if ($f =~ /\.novaseq\./) {
        if ($f =~ /\.xp\./) {
          ok (!$li->all_lanes_mergeable(), 'lanes are not mergeable');
          is ($li->workflow_type, 'NovaSeqXp', 'Xp workflow type');
        } else {
          ok ($li->all_lanes_mergeable(), 'all lanes mergeable');
          is ($li->workflow_type, 'NovaSeqStandard', 'Standard workflow type');
        }
      }
    }

    my @pfc = grep { $platform eq $_ } @patterned_flowcell_platforms;
    if (scalar @pfc > 1) {die 'Too many matches'};
    if (@pfc) {
      ok ($li->uses_patterned_flowcell, 'patterned flowcell');
    } else {
      ok (!$li->uses_patterned_flowcell, 'not patterned flowcell');
    }
    if ($f =~ /novaseqx\.prod/) {
      ok ($li->onboard_analysis_planned(), 'onboard analysis is planned');
    } else {
      ok (!$li->onboard_analysis_planned(), 'onboard analysis is not planned');
    }

    unlink $name;
  }
};

subtest 'detecting onboard analysis' => sub {
  plan tests => 1;

  my $rf = join q[/], $basedir, 'runfolder_onboard';
  mkdir $rf;
  copy('t/data/run_params/RunParameters.novaseqx.onboard.xml',
    "$rf/RunParameters.xml");

  my $class = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rf}},
    roles   => [qw/npg_tracking::illumina::run::long_info/]
  );
  my $li = $class->new_object(); 
  ok ($li->onboard_analysis_planned(), 'onboard analysis is planned');
};

subtest 'getting i5opposite for run' => sub {
  plan tests => 19;

  $basedir = tempdir( CLEANUP => 1 );
  my $rf = join q[/], $basedir, 'run_info';
  mkdir $rf;

  my $class = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rf}},
    roles   => [qw/npg_tracking::illumina::run::long_info/]);

  my %data = (
    'runInfo.hiseq4000.xml'                => { 'rpf' => 'runParameters', 'i5opposite' => 1 },
    'runInfo.hiseq4000.single.twoind.xml'  => { 'rpf' => 'runParameters', 'i5opposite' => 0 },
    'runInfo.hiseq.rr.single.xml'          => { 'rpf' => 'runParameters', 'i5opposite' => 0 },
    'runInfo.hiseq.rr.truseq.xml'          => { 'rpf' => 'runParameters', 'i5opposite' => 0 },
    'runInfo.hiseq.rr.twoind.xml'          => { 'rpf' => 'runParameters', 'i5opposite' => 0 },
    'runInfo.hiseq.rr.xml'                 => { 'rpf' => 'runParameters', 'i5opposite' => 0 },
    'runInfo.hiseq.xml'                    => { 'rpf' => 'runParameters', 'i5opposite' => 0 },
    'runInfo.hiseqx.upgraded.xml'          => { 'rpf' => 'runParameters', 'i5opposite' => 1 },
    'runInfo.hiseqx.xml'                   => { 'rpf' => 'runParameters', 'i5opposite' => 1 },
    'runInfo.miseq.xml'                    => { 'rpf' => 'runParameters', 'i5opposite' => 0 },
    'runInfo.nextseq.xml'                  => { 'rpf' => 'RunParameters', 'i5opposite' => 1 },
    'runInfo.novaseq.xml'                  => { 'rpf' => 'RunParameters', 'i5opposite' => 0 },
    'runInfo.novaseq.xp.xml'               => { 'rpf' => 'RunParameters', 'i5opposite' => 0 },
    'runInfo.novaseq.xp.v1.5.xml'          => { 'rpf' => 'RunParameters', 'i5opposite' => 1 },
    'runInfo.novaseq.xp.v1.5.single.xml'   => { 'rpf' => 'RunParameters', 'i5opposite' => 1 },
    'runInfo.novaseqx.xml'                 => { 'rpf' => 'RunParameters', 'i5opposite' => 1 },
 );

  my $run_info_dir = 't/data/run_info';
  my $run_param_dir = 't/data/run_params';

  my $copy_files = sub {
    my $file_name = shift;

    my $param_prefix =  $data{$file_name}->{'rpf'};
    my $run_params_file_name = $file_name =~ s/runInfo/$param_prefix/r;
    my $run_params_file_path = qq[$rf/$param_prefix.xml];
    copy(join(q[/],$run_info_dir,$file_name), qq[$rf/RunInfo.xml])
      or die 'Failed to copy file';
    copy(join(q[/],$run_param_dir,$run_params_file_name), $run_params_file_path)
      or die 'Failed to copy file';
    return $run_params_file_path;
  };

  for my $file_name (sort keys %data) {
    note $file_name;
    my $expected_i5opposite = $data{$file_name}->{'i5opposite'};
    my $run_params_file_path = $copy_files->($file_name);

    my $li = $class->new_object();
    if ( $expected_i5opposite ) {
      ok($li->is_i5opposite, 'i5opposite');
    } else {
      ok(!$li->is_i5opposite, 'i5opposite');
    }
    unlink $run_params_file_path or die "Failed to delete $run_params_file_path";
  }

  $copy_files->('runInfo.novaseqx.xml');
  my $run_info_file = qq[$rf/RunInfo.xml];
  
  edit_file_lines sub {
    $_ =~ s/IsReverseComplement="Y"/IsReverseComplement="N"/
  }, $run_info_file;
  my $li = $class->new_object();
  ok(!$li->is_i5opposite, 'i5opposite');

  $copy_files->('runInfo.novaseqx.xml');
  edit_file_lines sub {
    $_ =~ s/Read Number="3"\ NumCycles/Read Number="5" NumCycles/
  }, $run_info_file;
  $li = $class->new_object();
  throws_ok { $li->is_i5opposite }
    qr/Read 5 is marked as IsReverseComplement/,
    'error when unexpected read (not 3) marked as reverse complement';

  $copy_files->('runInfo.novaseqx.xml');
  edit_file_lines sub {
    $_ =~ s/IsReverseComplement="(Y|N)"//
  }, $run_info_file;
  $li = $class->new_object();
  throws_ok { $li->is_i5opposite }
    qr/Expect NovaSeqX to have an explicit reverse complement flag/,
    'error when no explicit reverse complement flag';
};

subtest 'getting flowcell for run' => sub {
  plan tests => 11;

  $basedir = tempdir( CLEANUP => 1 );
  my $rf = join q[/], $basedir, 'run_info';
  mkdir $rf;

  my $class = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rf}},
    roles   => [qw/npg_tracking::illumina::run::long_info/]);

  my %data = (
    'runInfo.hiseq4000.xml'       => { 'rpf' => 'runParameters', 'fc' => 'HLG55BBXX' },
    'runInfo.hiseq.rr.single.xml' => { 'rpf' => 'runParameters', 'fc' => 'HGM3FBCX2' },
    'runInfo.hiseq.rr.truseq.xml' => { 'rpf' => 'runParameters', 'fc' => 'HFK5KADXY' },
    'runInfo.hiseq.rr.twoind.xml' => { 'rpf' => 'runParameters', 'fc' => 'HGF72BCX2' },
    'runInfo.hiseq.rr.xml'        => { 'rpf' => 'runParameters', 'fc' => 'H2JG5BCX2' },
    'runInfo.hiseq.xml'           => { 'rpf' => 'runParameters', 'fc' => 'H7TM5CCXY' },
    'runInfo.hiseqx.upgraded.xml' => { 'rpf' => 'runParameters', 'fc' => 'HFFC5CCXY' },
    'runInfo.hiseqx.xml'          => { 'rpf' => 'runParameters', 'fc' => 'HCW7MCCXY' },
    'runInfo.miseq.xml'           => { 'rpf' => 'runParameters', 'fc' => 'MS5534842-300V2' },
    'runInfo.novaseq.xml'         => { 'rpf' => 'RunParameters', 'fc' => 'H3WCVDSXX' },
    'runInfo.novaseqx.xml'        => { 'rpf' => 'RunParameters', 'fc' => '222VLMLT3' },
  );

  my $ri_data = \%data;
  my $run_info_dir = 't/data/run_info';
  my $run_param_dir = 't/data/run_params';

  for my $file_name (sort keys % $ri_data) {
    note $file_name;
    my $expected_flowcell = $ri_data->{$file_name}->{'fc'};
    my $param_prefix =  $ri_data->{$file_name}->{'rpf'};
    my $run_params_file_name = $file_name =~ s/runInfo/$param_prefix/r;
    my $run_params_file_path = qq[$rf/$param_prefix.xml];

    copy(join(q[/],$run_info_dir,$file_name), qq[$rf/RunInfo.xml]) or die 'Failed to copy file';
    copy(join(q[/],$run_param_dir,$run_params_file_name), $run_params_file_path) or die 'Failed to copy file';

    my $li = $class->new_object();

    is($li->run_flowcell, $expected_flowcell, q[Expected run flowcell matches loaded run flowcell]);
    `rm $run_params_file_path`
  }
};

subtest 'getting experiment name from runParameters' => sub {
  plan tests => 11;

  $basedir = tempdir( CLEANUP => 1 );
  my $rf = join q[/], $basedir, 'runfolder_id_run';
  mkdir $rf;

  my $class = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rf}},
    roles   => [qw/npg_tracking::illumina::run::long_info/]);

  my %data = (
    'runParameters.hiseq4000.xml'       => { 'rpf' => 'runParameters', 'expname' => '24359' },
    'runParameters.hiseq.rr.single.xml' => { 'rpf' => 'runParameters', 'expname' => '25835' },
    'runParameters.hiseq.rr.truseq.xml' => { 'rpf' => 'runParameters', 'expname' => '21604' },
    'runParameters.hiseq.rr.twoind.xml' => { 'rpf' => 'runParameters', 'expname' => '25689' },
    'runParameters.hiseq.rr.xml'        => { 'rpf' => 'runParameters', 'expname' => '24409' },
    'runParameters.hiseq.xml'           => { 'rpf' => 'runParameters', 'expname' => '24235' },
    'runParameters.hiseqx.upgraded.xml' => { 'rpf' => 'runParameters', 'expname' => '24420' },
    'runParameters.hiseqx.xml'          => { 'rpf' => 'runParameters', 'expname' => '24422' },
    'runParameters.miseq.xml'           => { 'rpf' => 'runParameters', 'expname' => '24347' },
    'RunParameters.novaseq.xml'         => { 'rpf' => 'RunParameters', 'expname' => 'Coriell_24PF_auto_PoolF_NEBreagents_TruseqAdap_500pM_NV7B' },
    'RunParameters.novaseqx.xml'        => { 'rpf' => 'RunParameters', 'expname' => 'NovaSeqX_WHGS_TruSeqPF_NA12878'},
  );

  my $expname_data = \%data;
  my $run_param_dir = 't/data/run_params';

  for my $file_name (sort keys % $expname_data) {
    note $file_name;
    my $expected_experiment_name = $expname_data->{$file_name}->{'expname'};
    my $param_prefix = $expname_data->{$file_name}->{'rpf'};
    my $run_params_file_path = qq[$rf/$param_prefix.xml];

    copy(join(q[/],$run_param_dir,$file_name), $run_params_file_path) or die 'Failed to copy file';

    my $li = $class->new_object();

    is($li->experiment_name, $expected_experiment_name, q[Expected experiment name matches loaded from run params]);
    `rm $run_params_file_path`
  }
};

{
  my $rf = 't/data/long_info/nfs/sf20/ILorHSany_sf20/incoming/100914_HS3_05281_A_205MBABXX';
  my $class = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rf}},
    roles   => [qw/npg_tracking::illumina::run::long_info/]);
  my $long_info;
  lives_ok  { $long_info = $class->new_object(id_run => 5281); }
    q{created role_test (HiSeq run 5281, RunInfo.xml) object ok};
  cmp_ok($long_info->tile_count, '==', 32, 'correct tile count');
  cmp_ok($long_info->lane_count, '==', 8, 'correct lane count');
  cmp_ok($long_info->cycle_count, '==', 200, 'correct cycle count');

  $rf = 't/data/long_info/nfs/sf20/ILorHSany_sf20/incoming/160408_HS31_19395_B_H5MMFADXY';
  $class = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rf}},
    roles   => [qw/npg_tracking::illumina::run::long_info/]);
  lives_ok  { $long_info = $class->new_object(id_run => 19395); } q{created role_test (HiSeq run 19395, RunInfo.xml) object ok};
  cmp_ok($long_info->lane_tilecount->{1}, '==', 64, 'correct lane 1 tile count');
  cmp_ok($long_info->lane_tilecount->{2}, '==', 63, 'correct lane 2 tile count');
}

{
  my $rf = 't/data/long_info/nfs/sf20/ILorHSany_sf20/incoming/180426_NV1_25723_A_H3W2VDSXX';
  my $long_info = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rf}},
    roles   => [qw/npg_tracking::illumina::run::long_info/]
  )->new_object(id_run => 25723);
  is($long_info->tilelayout_columns(), 12, q{correct number of tilelayout_columns});
  is($long_info->tilelayout_rows(), 78, q{correct number of tilelayout_rows});
  is($long_info->tile_count(), 936, q{correct number of tiles});
  cmp_ok($long_info->lane_tilecount->{1}, '==', 936, 'correct lane 1 tile count');
}

{
  my $rfpath = q(t/data/long_info/nfs/sf20/ILorHSany_sf20/incoming/120110_M00119_0068_AMS0002022-00300);
  my $long_info = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rfpath}},
    roles   => [qw/npg_tracking::illumina::run::long_info/])->new_object();
  cmp_ok( $long_info->expected_cycle_count, '==', 318, 'expected_cycle_count');
  lives_and { cmp_deeply( [$long_info->read_cycle_counts], [151,8,8,151], 'read_cycle_counts match');} 'read_cycle_counts live and match';
  lives_and { cmp_deeply( [$long_info->read1_cycle_range], [1,151], 'read1_cycle_range matches');} 'read1_cycle_range lives and matches';
  lives_and { cmp_deeply( [$long_info->indexing_cycle_range], [152,167], 'indexing_cycle_range matches');} 'indexing_cycle_range lives and matches';
  lives_and { cmp_ok( $long_info->index_length, '==', 16, 'index_length matches');} 'index_length lives and matches';
  lives_and { cmp_deeply( [$long_info->read2_cycle_range], [168,318], 'read2_cycle_range matches');} 'read2_cycle_range lives and matches';
  lives_and { ok( $long_info->is_indexed, 'is_indexed ok');} 'is_indexed lives and ok';
  lives_and { ok( $long_info->is_paired_read, 'is_paired_read ok');} 'is_paired_read lives and ok';
  lives_and { ok( $long_info->is_dual_index, 'is_dual_index ok');} 'is_paired_read lives and ok';
  lives_and { cmp_deeply( [$long_info->index_read1_cycle_range], [152,159], 'index_read1_cycle_range matches');} 'index_read1_cycle_range lives and matches';
  lives_and { cmp_deeply( [$long_info->index_read2_cycle_range], [160,167], 'index_read2_cycle_range matches');} 'index_read2_cycle_range lives and matches';
  is ($long_info->instrument_name, 'M00119', 'instrument name from RunInfo.xml');
}

#and a SP flowcell
{
  my $rfpath = q(t/data/long_info/nfs/sf20/ILorHSany_sf20/incoming/200303_A00562_0352_AHKFVLDRXX);
  my $long_info = Moose::Meta::Class->create_anon_class(
    methods => {"runfolder_path" => sub {$rfpath}},
    roles   => [qw/npg_tracking::illumina::run::long_info/])->new_object();
  cmp_ok ( $long_info->surface_count, '==', 1, 'surface_count');
  is ($long_info->instrument_name, 'A00562', 'instrument name from RunInfo.xml');
}

1;

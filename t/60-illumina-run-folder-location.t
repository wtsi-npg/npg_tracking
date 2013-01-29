use strict;
use warnings;
use Test::More tests => 24;
use Test::Exception;
use Test::MockObject::Extends;
use Moose::Meta::Class;

BEGIN {
  use_ok( q{npg_tracking::illumina::run::folder::location} );
}

$ENV{TEST_DIR} = q(t/data/long_info);
my $incoming = join q[/], $ENV{TEST_DIR}, q[nfs/sf20/ILorHSany_sf20/incoming];

{ # no short_reference method
  my $test;
  lives_ok { $test = Moose::Meta::Class->create_anon_class(
      roles => [qw(npg_tracking::illumina::run::folder::location)],
    )->new_object();
  } 'anon class with no short_reference method';
  throws_ok { $test->runfolder_path } qr/Not enough information/, ' arrrgh no short_reference method'
}

{ # short_reference method but undef
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object();
  } 'anon class with short_reference undef';
  throws_ok { $test->runfolder_path } qr/Not enough information/, ' arrrgh short_reference undef';
}

{ # short_reference method, with no suitable folder
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[short_reference] => q[does_not_exist]);
  } 'anon class with short_reference for non existant folder';
  throws_ok { $test->runfolder_path } qr/No paths to run folder found/, ' arrrgh no run folder found';
}

{ # short_reference method, with suitable folder
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[short_reference] => q[5636]);
  } 'anon class with short_reference for folder';
  lives_and { is $test->runfolder_path, qq($incoming/101217_HS11_05636_A_90061ACXX) } ' run folder found';
}

{ # short_reference method, with suitable folder
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[short_reference] => q[100914_HS3_05281_A_205MBABXX]);
  } 'anon class with short_reference for folder';
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found';
}

{ # schema method but undef, runfolder can be found
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[short_reference] => q[100914_HS3_05281_A_205MBABXX]);
  } 'anon class, undef schema, with short_reference for folder';
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found';
}

{ # schema method but undef, runfolder can not be found
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[short_reference] => q[does_not_exist]);
  } 'anon class, undef schema, with short_reference for non existant folder';
  throws_ok { $test->runfolder_path } qr/No paths to run folder found/, ' arrrgh no run folder found';
}

my $testschema = Test::MockObject::Extends->new( q(npg_tracking::Schema) );
#diag $testschema;
$testschema->mock(q(resultset), sub{return shift;});
#diag $testschema->resultset;
my $testrun = Test::MockObject::Extends->new( q(npg_tracking::Schema::Result::Run) );
$testschema->mock(q(find), sub{
  my($self,$id_run) = @_;
  return $id_run ? $testrun : undef;
});
$testrun->mock(q(is_tag_set), sub{ return 0; });

{ # schema, no id_run, but with short ref and a folder
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  } 'anon class, schema, no id_run, with short_reference for folder';
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found';
}


{# schema, id_run, no staging tag 
  $testrun->mock(q(is_tag_set), sub{ return 0; });
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[id_run] => ( q[is] => q[ro], q[default] => 0 ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[id_run] => 5281, q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  } 'anon class, schema, id_run, with short_reference for folder - but no staging tag';
  throws_ok { $test->runfolder_path } qr/NPG tracking reports run \d* no longer on staging/, ' no run folder found';
}


{# schema, id_run, staging tag, no glob, no folder_name
  $testrun->mock(q(is_tag_set), sub{ return 1; });
  $testrun->mock(q(folder_path_glob), sub{ return; });
  $testrun->mock(q(folder_name), sub{ return; });
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[short_reference] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[id_run] => ( q[is] => q[ro], q[default] => 0 ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[id_run] => 5281, q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  } 'anon class, schema, id_run, with short_reference for folder - staging tag but no folder name or glob from DB';
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found';
}


{# schema, no short ref, id_run, staging tag, glob, folder_name
  $testrun->mock(q(folder_path_glob), sub{ return q[t/data/long_info/{export,nfs}/sf20/ILorHSany_sf20/*]; });
  $testrun->mock(q(folder_name), sub{ return q[100914_HS3_05281_A_205MBABXX]; });
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run::folder::location)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[id_run] => ( q[is] => q[ro], q[default] => 0 ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[id_run] => 5281, q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  } 'anon class, schema, id_run, no short_reference, staging tag and folder name and glob';
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found';

  $testrun->mock(q(folder_path_glob), sub{ return q[t/data/long_info/{export,nfs}/sf20/ILorHSany_sf20/*/]; });
  $test = $testc->new_object( q[id_run] => 5281, q[short_reference] => q[100914_HS3_05281_A_205MBABXX], q[npg_tracking_schema] => $testschema );
  lives_and { is $test->runfolder_path, qq($incoming/100914_HS3_05281_A_205MBABXX) } ' run folder found and does not contain a double slash';
}

1;


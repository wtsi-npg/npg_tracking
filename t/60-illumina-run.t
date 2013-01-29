use strict;
use warnings;
use English qw{-no_match_vars};
use Test::More tests => 11;
use Test::Exception;
use Test::MockObject::Extends;
use Moose::Meta::Class;

BEGIN {
  use_ok( q{npg_tracking::illumina::run} );
}

{ # no schema method
  my $test; 
  lives_ok { $test = Moose::Meta::Class->create_anon_class(
      roles => [qw(npg_tracking::illumina::run)],
    )->new_object();
  } 'anon class with no schema method';
  throws_ok { $test->tracking_run } qr/Need NPG tracking schema/, ' arrrgh no schema method'
}

{ # schema undef
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  my $test; 
  lives_ok {
    $test = $testc->new_object();
  } 'anon class with undef schema';
  throws_ok { $test->tracking_run } qr/Need NPG tracking schema/, ' arrrgh undef schema';
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
#diag $testschema->resultset->find(0);
#diag $testschema->resultset->find(43);

{ # schema defined, no id_run method
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[npg_tracking_schema] => $testschema);
  } 'anon class with no id_run method';
  throws_ok { $test->tracking_run } qr/Need id_run/, ' arrrgh no id_run method';
}

{ # schema defined, id_run undef
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[id_run] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[npg_tracking_schema] => $testschema);
  } 'anon class with id_run undef';
  throws_ok { $test->tracking_run } qr/Need id_run/, ' arrrgh id_run undef';
}

{ # schema defined, id_run defined
  my $testc = Moose::Meta::Class->create_anon_class(
    roles => [qw(npg_tracking::illumina::run)],
  );
  $testc->add_attribute(q[npg_tracking_schema] => ( q[is] => q[ro], q[default] => undef ));
  $testc->add_attribute(q[id_run] => ( q[is] => q[ro], q[default] => undef ));
  my $test;
  lives_ok {
    $test = $testc->new_object( q[npg_tracking_schema] => $testschema, q[id_run] => 4);
  } 'anon class with id_run defined';
  lives_and { isa_ok $test->tracking_run, 'npg_tracking::Schema::Result::Run' } ' lives and gives npg_tracking::Schema::Result::Run';
}


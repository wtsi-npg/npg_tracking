use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;
use t::dbic_util;

use_ok 'npg_tracking::tag_manager';

my $schema = t::dbic_util->new()->test_schema();

subtest 'create object' => sub {
  plan tests => 8;

  throws_ok {
    npg_tracking::tag_manager->new(id_run=>1,rm=>1,schema=>$schema)
  }
    qr/Attribute \(tag\) is required/,
    'error when tag attribute is not set';
  throws_ok {
    npg_tracking::tag_manager->new(id_run=>1,tag=>[],rm=>1,schema=>$schema)
  } qr/At least one tag should be given/,
    'error when the tag attribute is set to an empty array';
  throws_ok { npg_tracking::tag_manager->new(id_run=>1,tag=>'one',schema=>$schema) }
    qr/username should be given for adding tags/,
    'error when username is not given when adding a tag';
  
  my $tm;
  lives_ok {
    $tm = npg_tracking::tag_manager->new(
      id_run => 1,
      tag    => 'one',
      rm     => 1,
      schema => $schema
    )
  } 'object to remove one tag is created OK';
  isa_ok ($tm, 'npg_tracking::tag_manager');
  lives_ok {
    $tm = npg_tracking::tag_manager->new(
      id_run   => 1,
      tag      => [qw/one two/],
      rm       => 1,
      username => 'pipeline',
      schema   => $schema
    )
  } 'object to remove two tags is created OK';

  lives_ok {
    npg_tracking::tag_manager->new(
      id_run   => 1,
      tag      => 'one',
      username => 'pipeline',
      schema   => $schema
   )
  } 'object to add one tag is created OK';
  lives_ok {
    npg_tracking::tag_manager->new(
      id_run   => 1,
      tag      => [qw/one two/],
      username => 'pipeline',
      schema => $schema
   )
  } 'object two add two tags is created OK';
};

subtest 'errors adding an removing tags' => sub {
  plan tests => 4;

  my $id_run = 23; # No run fixture.

  my $tm = npg_tracking::tag_manager->new(
    id_run   => $id_run,
    tag      => 'staging',
    rm       => 1,
    username => 'pipeline',
    schema   => $schema
  );
  throws_ok { $tm->perform_action() }
    qr/Run id $id_run does not exist/,
    "error removing a tag when the run is not tracked";

  $id_run = 50000;
  my $staging_tag = 'staging';
  my $run = $schema->resultset('Run')->find($id_run);;
  ok (!$run->is_tag_set($staging_tag), "$staging_tag tag is not set");

  $tm = npg_tracking::tag_manager->new(
    id_run   => $id_run,
    tag      => [$staging_tag, 'some other tag'],
    username => 'pipeline',
    schema   => $schema
  );
  throws_ok { $tm->perform_action() }
    qr/Cannot set unknown tag 'some other tag'/,
    'an error adding an unknown tag has been captured';
  ok (!$run->is_tag_set($staging_tag), "$staging_tag tag is not set");
};

subtest 'add and remove tags' => sub {
  plan tests => 17;

  my $id_run = 50000;

  my $run = $schema->resultset('Run')->find($id_run);
  my $staging_tag = 'staging';
  my $rta_tag = 'rta';
  my $slot_tag = 'fc_slotA';
  ok (!$run->is_tag_set($staging_tag), "$staging_tag tag is not set");
  ok (!$run->is_tag_set($rta_tag), "$rta_tag tag is not set");
  ok ($run->is_tag_set($slot_tag), "$slot_tag tag is set");

  my $tm_add = npg_tracking::tag_manager->new(
    id_run   => $id_run,
    tag      => $staging_tag,
    username => 'pipeline',
    schema   => $schema
  );
  lives_ok { $tm_add->perform_action() } "$staging_tag tag added ok";
  ok ($run->is_tag_set($staging_tag), "$staging_tag tag is set"); 
  lives_ok { $tm_add->perform_action() } "$staging_tag tag added again - ok";

  my $tm_remove = npg_tracking::tag_manager->new(
    id_run   => $id_run,
    tag      => $staging_tag,
    rm       => 1,
    schema   => $schema
  );
  lives_ok { $tm_remove->perform_action() } "$staging_tag tag removed ok";  
  ok (!$run->is_tag_set($staging_tag), "$staging_tag tag is not set");
  lives_ok { $tm_remove->perform_action() } "$staging_tag tag removed again - ok";
  ok ($run->is_tag_set($slot_tag), "$slot_tag tag is set");

  $tm_add = npg_tracking::tag_manager->new(
    id_run   => $id_run,
    tag      => [$staging_tag, $rta_tag],
    username => 'pipeline',
    schema   => $schema
  );
  lives_ok { $tm_add->perform_action() } "two tags added ok";
  ok ($run->is_tag_set($staging_tag), "$staging_tag tag is set");
  ok ($run->is_tag_set($rta_tag), "$rta_tag tag is set");
  
  $tm_remove = npg_tracking::tag_manager->new(
    id_run   => $id_run,
    tag      => [$rta_tag, $staging_tag],
    rm       => 1,
    username => 'pipeline',
    schema   => $schema
  );
  lives_ok { $tm_remove->perform_action() } "two tags removed ok";
  ok (!$run->is_tag_set($staging_tag), "$staging_tag tag is not set");
  ok (!$run->is_tag_set($rta_tag), "$rta_tag tag is not set");
  ok ($run->is_tag_set($slot_tag), "$slot_tag tag is set");
};


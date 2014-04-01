use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use t::util;
use t::dbic_util;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/email';

BEGIN {
  use_ok( q{npg::email::run} );
}

my $util = t::util->new();
$util->catch_email($util);
my $schema    = t::dbic_util->new->test_schema();

my $hash_projects_followers = {
   '500 Exome' => {
     'followers' => [
       'ajc@sanger.ac.uk',
       'dw2@sanger.ac.uk',
       'ekh@sanger.ac.uk',
       'fp1@sanger.ac.uk',
       'jillian@sanger.ac.uk'
     ],
     'lanes' => [
       {
         'library' => 'AA02SH1A 1 84706',
         'position' => '1'
       },
       {
         'library' => 'AA02JK3A 1 84707',
         'position' => '2'
       },
       {
         'library' => 'AA02ZOZA 1 84708',
         'position' => '3'
       },
       {
         'library' => 'AA02X3HA 1 84710',
         'position' => '5'
       },
       {
         'library' => 'AA03210A 1 84711',
         'position' => '6'
       },
       {
         'library' => 'AA02QKAA 1 84712',
         'position' => '7'
       },
       {
         'library' => 'AA02ZMHA 1 84715',
         'position' => '8'
       }
     ]
   }
        };

{
  my $object;
  my $id_run = 4231;
  lives_ok { $object = npg::email::run->new({schema_connection => $schema,}); } q{object created ok};
  is_deeply( $object->study_lane_followers($id_run), $hash_projects_followers, q{hash obtained is correct} );
}

1;

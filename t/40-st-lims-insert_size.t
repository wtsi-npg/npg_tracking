use strict;
use warnings;
use Test::More tests => 40;
use Test::Exception;

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/test40_lims_edited];

use_ok('st::api::lims');

{
  my $lims = st::api::lims->new(batch_id => 4775, position => 1);
  my $lid = $lims->library_id;

  my $is_available = 0;
  my $is = {};
  $lims->_entity_required_insert_size($lims, $is, \$is_available);
  is (keys %{$is}, 1, 'one entry in the insert size hash');
  is ($is->{$lid}->{q[from]}, 300, 'required FROM insert size');
  is ($is->{$lid}->{q[to]}, 400, 'required TO insert size');
  is ($is_available, 1, 'is reported as available');
  
  $is_available = 1;
  $lims->_entity_required_insert_size($lims, $is, \$is_available);
  is ($is_available, 1, 'is reported as available');
  
  $lims = st::api::lims->new(batch_id => 4775, position => 2);
  $is = {};
  $is_available = 0;
  $lims->_entity_required_insert_size($lims, $is, \$is_available);
  is (keys %{$is}, 0, 'the insert size hash is empty');
  is ($is_available, 0, 'is reported as not available');
  
  $is_available = 1;
  $lims->_entity_required_insert_size($lims, $is, \$is_available);
  is ($is_available, 1, 'is reported as available');
  
  $lims = st::api::lims->new(batch_id => 4775, position => 3);
  $is = {};
  $is_available = 0;
  $lims->_entity_required_insert_size($lims, $is, \$is_available);
  is (keys %{$is}, 0, 'the insert size hash is empty');
  is ($is_available, 0, 'is reported as not available');
}

{
  my $lims = st::api::lims->new(batch_id => 4775, position => 1);
  my $lid = $lims->library_id;
  my $insert_size;
  lives_ok {$insert_size = $lims->required_insert_size} 'insert size for the first lane lives';
  is (keys %{$insert_size}, 1, 'one entry in the insert size hash');
  is ($insert_size->{$lid}->{q[from]}, 300, 'required FROM insert size');
  is ($insert_size->{$lid}->{q[to]}, 400, 'required TO insert size');
  
  $lims = st::api::lims->new(batch_id => 4775, position => 3);
  lives_ok {$insert_size = $lims->required_insert_size} 'insert size for the third lane where empty is hash is returned lives';
  is (keys %{$insert_size}, 0, 'no entries in the insert size hash');
  
  $lims = st::api::lims->new(batch_id => 4775, position => 4);
  lives_ok {$insert_size = $lims->required_insert_size} 'insert size for the control lane lives';
  is (keys %{$insert_size}, 0, 'no entries in the insert size hash');
  
  $lims = st::api::lims->new(batch_id => 4775, position => 8);
  ok ($lims ->is_pool, 'lane is a pool');
  lives_ok {$insert_size = $lims->required_insert_size} 'insert size for the pool where empty is hash is returned lives';
  is (keys %{$insert_size}, 0, 'no entries in the insert size hash');
  
  $lims = st::api::lims->new(batch_id => 4775, position => 7);
  ok ($lims ->is_pool, 'lane is a pool');
  lives_ok {$insert_size = $lims->required_insert_size} 'insert size for the pool lives';
  is (keys %{$insert_size}, 2, 'two entries in the insert size hash');
  is ($insert_size->{2798524}->{q[from]}, 40, 'required FROM insert size');
  is ($insert_size->{2798524}->{q[to]}, 50, 'required TO insert size');
  ok (!exists $insert_size->{2798525}->{q[from]}, 'no required FROM insert size');
  is ($insert_size->{2798525}->{q[to]}, 500, 'required TO insert size');
  
  $lims = st::api::lims->new(batch_id => 4775, position => 7, tag_index => 2);
  lives_ok {$insert_size = $lims->required_insert_size} 'insert size for the plex lives';
  is (keys %{$insert_size}, 1, 'one entry in the insert size hash');
  is ($insert_size->{2798524}->{q[from]}, 40, 'required FROM insert size');
  is ($insert_size->{2798524}->{q[to]}, 50, 'required TO insert size');
}

{
  my $lims = st::api::lims->new(batch_id => 14706, position => 1, tag_index => 2);
  my $insert_size;
  lives_ok {$insert_size = $lims->required_insert_size} 'insert size for the plex without lib id lives';
  is ($insert_size->{2}->{q[from]}, 200, 'required FROM insert size');
  is ($insert_size->{2}->{q[to]}, 400, 'required TO insert size');

  $lims = st::api::lims->new(batch_id => 14706, position => 2);
  lives_ok {$insert_size = $lims->required_insert_size} 'insert size for the pool with plexes without lib ids lives';
  is (join(q[ ], sort keys %{$insert_size}), '1 2 3 4 5', 'tag index entries in the insert size hash');
  is ($insert_size->{5}->{q[from]}, 200, 'required FROM insert size');
  is ($insert_size->{4}->{q[to]}, 400, 'required TO insert size');
}

1;

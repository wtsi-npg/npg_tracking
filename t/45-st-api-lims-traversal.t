use strict;
use warnings;
use Test::More tests => 121; #remember to change the skip number below as well!
use Test::Deep;
use Test::Exception;
use Try::Tiny;

use npg_testing::intweb qw(npg_is_accessible);
use st::api::lims;

sub _positions {
  my @lims = @_;
  my @positions = ();
  foreach my $lims (@lims) {
    if (!defined $lims->tag_index) {
      push @positions, $lims->position;
    }
  }
  return sort @positions;
}

use_ok('st::api::lims');

foreach my $pa ((['using mocked data', q[t/data/test45], 'xml'],
                 ['using live',        q[],              'xml'],
                 ['using live',        q[],              'ml_warehouse']))
{
  my $do_test = 1;
  my $reason = q[];
  my $driver        = $pa->[2];
  my $test_data_dir = $pa->[1];
  diag($pa->[0], ", $driver driver");
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = $test_data_dir;
  my $lfield = $driver eq 'xml' ? 'batch_id' : 'id_flowcell_lims';

  if ($driver eq 'xml' && !$test_data_dir) {
    $do_test = npg_is_accessible();
    $reason = 'Live test, but sanger intweb is not accessible';
  } elsif ($driver eq 'ml_warehouse') {
    my $package = 'st::api::lims::ml_warehouse';
    my $schema_package = 'WTSI::DNAP::Warehouse::Schema';
    eval "require $package" or $do_test = 0;
    eval "require $schema_package" or $do_test = 0;
    if (!$do_test) {
      $reason = "$package is not deployed or cannot be loaded";
    } else {
      try {
        $schema_package->connect();
      } catch {
        $reason = "Failed to connect to ml_warehouse";
        diag "$reason $_";
        $do_test = 0;
      };
    } 
  }

  SKIP: {

    if (!$do_test) {
      skip $reason, 40;
    }

    my $lims = st::api::lims->new($lfield => 4775, driver_type => $driver);
    isa_ok($lims, 'st::api::lims', 'lims isa');
    my @alims = $lims->associated_lims;
    is(scalar @alims, 8, '8 associated lims objects');
    my @positions = _positions(@alims);
    is(scalar @positions, 8, '8 lanes in a batch');
    is(join(q[ ],@positions), '1 2 3 4 5 6 7 8', 'all positions'); 

    my $lims1 = st::api::lims->new($lfield => 4775, position => 1, driver_type => $driver);
    is($lims1->is_control, 0, 'first st lane has no control');
    is($lims1->is_pool, 0, 'first st lane has no pool');
    is(scalar $lims1->associated_lims, 0, 'no associated lims for a lane');
    cmp_ok($lims1->library_id, q(==), 57440, 'lib id from first st lane');
    my $expected_name = $driver eq 'xml' ? 'PD3918a 1' : '57440';
    cmp_ok($lims1->library_name, q(eq), $expected_name, 'lib name from first st lane');

    my $insert_size;
    lives_ok {$insert_size = $lims1->required_insert_size} 'insert size for the first lane';
    is (keys %{$insert_size}, 1, 'one entry in the insert size hash');
    is ($insert_size->{$lims1->library_id}->{q[from]}, 300, 'required FROM insert size');
    is ($insert_size->{$lims1->library_id}->{q[to]}, 400, 'required TO insert size');

    ok(!$lims1->sample_consent_withdrawn(), 'sample consent not withdrawn');
    ok(!$lims1->any_sample_consent_withdrawn(), 'not any sample consent withdrawn');
    
    my $lims4 = st::api::lims->new($lfield => 4775, position => 4, driver_type => $driver);
    is($lims4->is_control, 1, 'first st lane has control');
    is($lims4->is_pool, 0, 'first st lane has no pool');
    cmp_ok($lims4->library_id, q(==), 79577, 'control id from fourth st lane');
    if ($driver eq 'xml') {
      cmp_ok($lims4->library_name, q(eq), 'phiX CT1462-2 1', 'control name from fourth st lane');
    } else {
      cmp_ok($lims4->library_name, q(==), 79577, 'control library id from fourth st lane');
    }
    cmp_ok($lims4->sample_id, q(==), 9836, 'sample id from fourth st lane');
    ok(!$lims4->study_id, 'study id from fourth st lane undef');
    ok(!$lims4->project_id, 'project id from fourth st lane undef');
    my $request_id = $lims4->request_id;
    $request_id ||= 0;
    my $expected_request_id = $driver eq 'xml' ? 43779 : 0;
    cmp_ok($request_id, q(==), $expected_request_id, 'request id from fourth st lane');
    is_deeply($lims4->required_insert_size, {}, 'no insert size for control lane');

    my $lims6 = st::api::lims->new($lfield => 4775, position => 6, driver_type => $driver);
    is($lims6->study_id, 333, 'study id');
    cmp_ok($lims6->study_name, q(eq), q(CLL whole genome), 'study name');

    cmp_bag($lims6->email_addresses,[qw(dg10@sanger.ac.uk las@sanger.ac.uk pc8@sanger.ac.uk sm2@sanger.ac.uk)],'All email addresses');
    cmp_bag($lims6->email_addresses_of_managers,[qw(sm2@sanger.ac.uk)],'Managers email addresses');
    is_deeply($lims6->email_addresses_of_followers,[qw(dg10@sanger.ac.uk las@sanger.ac.uk pc8@sanger.ac.uk)],'Followers email addresses');
    is_deeply($lims6->email_addresses_of_owners,[qw(sm2@sanger.ac.uk)],'Owners email addresses');

    is($lims6->alignments_in_bam, 1,'do bam alignments');

    my $lims7 = st::api::lims->new($lfield => 16249, position => 1, driver_type => $driver);
    is($lims7->reference_genome, 'Homo_sapiens (1000Genomes)',
      'reference genome when common for whole pool');
    is($lims7->bait_name, 'Human all exon 50MB', 'bait name when common for whole pool');
    $lims7 = st::api::lims->new($lfield => 16249, position => 1, tag_index => 2, driver_type => $driver);
    is($lims7->bait_name, 'Human all exon 50MB', 'bait name for a plex');
    $lims7 = st::api::lims->new($lfield => 16249, position => 1, tag_index => 168, driver_type => $driver);
    is($lims7->bait_name, undef, 'bait name undefined for spiked phix plex');

    $lims7 = st::api::lims->new($lfield => 16249, position => 1, tag_index => 0, driver_type => $driver);
    is($lims7->reference_genome, 'Homo_sapiens (1000Genomes)',
      'tag zero reference genome when common for whole pool');
    my $lims8 = st::api::lims->new($lfield =>15728, position=>2, tag_index=>3, driver_type => $driver);    
    ok( $lims8->sample_consent_withdrawn(), 'sample 1299723 consent withdrawn' );
    ok( $lims8->any_sample_consent_withdrawn(), 'any sample (1299723) consent withdrawn' );

    my $lims9 = st::api::lims->new($lfield =>15728, position=>2, tag_index=>0, driver_type => $driver);
    ok( $lims9->any_sample_consent_withdrawn(), 'any sample consent withdrawn' );

    my $lims10 = st::api::lims->new($lfield =>43500, position=>1, tag_index=>1, driver_type => $driver);
    is($lims10->purpose,'standard','Purpose');

  }; # end of SKIP
}

1;

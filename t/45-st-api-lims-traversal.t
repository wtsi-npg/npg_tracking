#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: ajb $
# Created:       02 August 2011
# Last Modified: $Date: 2011-04-07 11:34:12 +0100 (Thu, 07 Apr 2011) $
# Id:            $Id: 45-npg-st-api-traversal.t 12954 2011-04-07 10:34:12Z ajb $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/branches/prerelease-60.0/t/45-npg-st-api-traversal.t $
#
use strict;
use warnings;
use Test::More tests => 106; #remember to change the skip number below as well!
use Test::Deep;
use Test::Exception;
use English qw(-no_match_vars);

use npg_testing::intweb qw(npg_is_accessible);
use st::api::lims;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 12954 $ =~ /(\d+)/smx; $r; };

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

my $do_test = 1;

use_ok('st::api::lims');

foreach my $pa (['test', 'using mocked data', q[t/data/test45]],
                ['live', 'using live', q[]], # Put in test TODO perhaps?
                ['dev',  'using dev', q[]],
		) {
    diag($pa->[1]);
    my $env = $pa->[0];
    if ($env eq q[test]) { $env = q[live]; }
    local $ENV{dev}=$env;
    local $ENV{NPG_WEBSERVICE_CACHE_DIR} = $pa->[2];

    if ($pa->[0] eq q[dev]) {
        $do_test = npg_is_accessible(q[http://npg.dev.sanger.ac.uk/perl/npg]);
    } elsif ($pa->[0] eq q[live]) {
        $do_test = npg_is_accessible();
    }

  SKIP: {

    if (!$do_test) {
     skip 'Live test, but sanger intweb is not accessible',  35;
    }
       {
    diag q[Tests for run 3905];
    my $lims = st::api::lims->new(id_run => 3905);
    cmp_ok($lims->batch_id(),  q(==), 4775, 'run batch_id');
    $lims = st::api::lims->new(batch_id => 4775);
    isa_ok($lims, 'st::api::lims', 'lims isa');
    my @alims = $lims->associated_lims;
    is(scalar @alims, 8, '8 associated lims objects');
    my @positions = _positions(@alims);
    is(scalar @positions, 8, '8 lanes in a batch');
    is(join(q[ ],@positions), '1 2 3 4 5 6 7 8', 'all positions'); 

    my $lims1 = st::api::lims->new(batch_id => 4775, position => 1);
    is($lims1->is_control, 0, 'first st lane has no control');
    is($lims1->is_pool, 0, 'first st lane has no pool');
    is(scalar $lims1->associated_lims, 0, 'no associated lims for a lane');

    cmp_ok($lims1->library_id, q(==), 57440, 'lib id from first st lane');
    cmp_ok($lims1->library_name, q(eq), 'PD3918a 1', 'lib name from first st lane');

    my $insert_size;
    lives_ok {$insert_size = $lims1->required_insert_size} 'insert size for the first lane';
    is (keys %{$insert_size}, 1, 'one entry in the insert size hash');
    is ($insert_size->{$lims1->library_id}->{q[from]}, 300, 'required FROM insert size');
    is ($insert_size->{$lims1->library_id}->{q[to]}, 400, 'required TO insert size');

    ok(!$lims1->sample_consent_withdrawn(), 'sample consent not withdrawn');
    
    my $lims4 = st::api::lims->new(batch_id => 4775, position => 4);
    is($lims4->is_control, 1, 'first st lane has control');
    is($lims4->is_pool, 0, 'first st lane has no pool');
    cmp_ok($lims4->library_id, q(==), 79577, 'control id from fourth st lane');
    cmp_ok($lims4->library_name, q(eq), 'phiX CT1462-2 1', 'control name from fourth st lane');
    cmp_ok($lims4->sample_id, q(==), 9836, 'sample id from fourth st lane');
    ok(!$lims4->study_id, 'study id from fourth st lane undef');
    ok(!$lims4->project_id, 'project id from fourth st lane undef');
    cmp_ok($lims4->request_id, q(==), 43779, 'request id from fourth st lane');
    is_deeply($lims4->required_insert_size, {}, 'no insert size for control lane');

    my $lims6 = st::api::lims->new(batch_id => 4775, position => 6);
    is($lims6->study_id, 333, 'study id');
    cmp_ok($lims6->study_name, q(eq), q(CLL whole genome), 'study name');

    cmp_bag($lims6->email_addresses,[qw(dg10@sanger.ac.uk las@sanger.ac.uk pc8@sanger.ac.uk sm2@sanger.ac.uk)],'All email addresses');
    cmp_bag($lims6->email_addresses_of_managers,[qw(sm2@sanger.ac.uk)],'Managers email addresses');
    is_deeply($lims6->email_addresses_of_followers,[qw(dg10@sanger.ac.uk las@sanger.ac.uk pc8@sanger.ac.uk)],'Followers email addresses');
    is_deeply($lims6->email_addresses_of_owners,[qw(sm2@sanger.ac.uk)],'Owners email addresses');

    is($lims6->alignments_in_bam, 1,'do bam alignments');


    my $lims7 = st::api::lims->new(batch_id => 16249, position => 1);
    is($lims7->bait_name, undef, 'bait name undefined for a pool');
    $lims7 = st::api::lims->new(batch_id => 16249, position => 1, tag_index => 2);
    is($lims7->bait_name, 'Human all exon 50MB', 'bait name for a plex');
    $lims7 = st::api::lims->new(batch_id => 16249, position => 1, tag_index => 168);
    is($lims7->bait_name, undef, 'bait name undefined for spiked phix plex');
    
    my $lims8 = st::api::lims->new(batch_id =>15728, position=>2, tag_index=>3);    
    ok( $lims8->sample_consent_withdrawn(), 'sample 1299723 consent withdrawn' );
    
   }

  }; # end of SKIP
}

1;

use strict;
use warnings;
use Test::More tests => 148; #remember to change the skip number below as well!
use Test::Deep;
use Test::Exception;
use npg_testing::intweb qw(npg_is_accessible);

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q[t/data/test45];

{
use_ok('npg::api::run');

my $do_test = 1;

foreach my $pa (['test', 'using mocked data'],
                ['live', 'using live'],
                ['dev',  'using dev'],
    ) {
    diag($pa->[1]);
    local $ENV{dev}=$pa->[0];

    if ($pa->[0] eq q[dev]) {
        $do_test = npg_is_accessible(q[http://npg.dev.sanger.ac.uk/perl/npg]);
    } elsif ($pa->[0] eq q[live]) {
        $do_test = npg_is_accessible();
    }

  SKIP: {

    if (!$do_test) {
     skip 'Live test, but sanger intweb is not accessible',  49;
    }

    my $run = npg::api::run->new({
             max_retries => 2,
             retry_delay => 1,
             id_run       => 3905,
            });
    isa_ok($run, 'npg::api::run', 'run isa');

    # Test the fields.
    cmp_ok($run->batch_id(),  q(==), 4775, 'run batch_id');
    cmp_ok($run->id_run(),    q(==), 3905, 'run id_run');
    cmp_ok($run->name(),      q(eq), 'IL19_3905', 'run name');

    #get the batch
    my $lims = $run->lims();
    isa_ok($lims, 'st::api::lims', 'lims isa');
    my @lanes = $lims->associated_child_lims;
    cmp_ok(scalar @lanes,  q(==), 8, 'lims lane count');

    {#get the lanes from the batch
    isa_ok($lanes[0], 'st::api::lims', 'first lane isa');
    cmp_ok($lanes[0]->position, q(==), 1, 'first st lane position');
    cmp_ok($lanes[5]->position, q(==), 6, 'sixth st lane position');
    is($lanes[0]->is_control, 0, 'first st lane has no control');
    is($lanes[0]->is_pool, 0, 'first st lane has no pool');
    is($lanes[3]->is_pool, 0, 'fourth st lane has no pool');
    cmp_ok($lanes[0]->library_id, q(==), 57440, 'entity id from first st lane');
    cmp_ok($lanes[0]->library_name, q(eq), 'PD3918a 1', 'entity name from first st lane');
    my $insert_size;
    lives_ok {$insert_size = $lanes[0]->required_insert_size} 'insert size for the first lane';
    is (keys %{$insert_size}, 1, 'one entry in the insert size hash');
    is ($insert_size->{$lanes[0]->library_id}->{q[from]}, 300, 'required FROM insert size');
    is ($insert_size->{$lanes[0]->library_id}->{q[to]}, 400, 'required TO insert size');

    my $control = $lanes[3];
    cmp_ok($control->library_id, q(==), 79577, 'control id from fourth st lane');
    cmp_ok($lanes[5]->project_id, q(==), 333, 'study id');
    cmp_ok($lanes[5]->project_name, q(eq), q(CLL whole genome), 'study name');
 #warn @{$project->email_addresses};
    cmp_bag($lanes[5]->email_addresses,[qw(dg10@sanger.ac.uk las@sanger.ac.uk pc8@sanger.ac.uk sm2@sanger.ac.uk)],'All email addresses');
    cmp_bag($lanes[5]->email_addresses_of_managers,[qw(sm2@sanger.ac.uk)],'Managers email addresses');
    is_deeply($lanes[5]->email_addresses_of_followers,[qw(dg10@sanger.ac.uk las@sanger.ac.uk pc8@sanger.ac.uk)],'Followers email addresses');
    is_deeply($lanes[5]->email_addresses_of_owners,[qw(sm2@sanger.ac.uk)],'Owners email addresses');
    TODO: { local $TODO = 'expect cancer study to have BAM alignments set to false'; # should probably bung in true one as well....
    ok(! $lanes[5]->alignments_in_bam, 'No alignments in BAM');
    }
    }

    #get npg run lanes from run
    my @run_lanes = @{$run->run_lanes};
    cmp_ok(@run_lanes, q(==), 8, 'number of run lanes');
    isa_ok($run_lanes[0], 'npg::api::run_lane', 'first run lane isa');
    cmp_ok($run_lanes[0]->position, q(==), 1, 'first run lane position');
    cmp_ok($run_lanes[5]->position, q(==), 6, 'sixth run lane position');
    is($run_lanes[0]->is_control, 0, 'first run lane is not control');
    is($run_lanes[3]->is_control, 1, 'fourth run lane is a control');
    {
      my $run_lane = npg::api::run_lane->new({
                                          'id_run'   => 3948,
                                          'position' => 6,
                                         });
      is($run_lane->id_run_lane, 31141, 'lookup from id_run and position');
      ok($run_lane->contains_nonconsented_human, 'contains nonconsented human');
      ok($run_lane->contains_unconsented_human, 'contains unconsented human (back compat)');
      ok(!$run_lane->is_library, 'not from a single library');
      ok(!$run_lane->is_control, 'not from a control');
      ok($run_lane->is_pool, 'from a pool');
      is( $run_lane->asset_id, '65172', 'return asset id for a pool' );
    }
    {
      my $run_lane = npg::api::run_lane->new({
                                          'id_run'   => 3948,
                                          'position' => 1,
                                         });
      is($run_lane->id_run_lane, 31136, 'lookup from id_run and position');
      ok(!$run_lane->contains_nonconsented_human, 'does not contain nonconsented human');
      ok(!$run_lane->contains_unconsented_human, 'does not contain unconsented human (back compat)');
      ok(!$run_lane->is_library, 'not from a single library');
      ok(!$run_lane->is_control, 'not from a control');
      ok($run_lane->is_pool, 'from a pool');
    }
    {
      my $run_lane = npg::api::run_lane->new({
                                          'id_run'   => 4354,
                                          'position' => 2,
                                         });
      cmp_ok($run_lane->manual_qc, q(eq), 'pass', 'QC pass on lane 2 run 4354');
    }
    {
      my $run_lane = npg::api::run_lane->new({
                                          'id_run'   => 4354,
                                          'position' => 3,
                                         });
      cmp_ok($run_lane->manual_qc, q(eq), 'fail', 'QC fail on lane 3 run 4354');
    }

    {
      my $run = npg::api::run->new({
        id_run => 5937,
      });
      my $lims = $run->lims();
      is( $lims->batch_id(), 9589, q{correct batch id} );
      my $lane1_lims = $lims->associated_child_lims_ia->{1};
      is(scalar $lane1_lims->sample_names, 2 , '2 samples in a pool');
    }

  } # end of SKIP
}

}


1;

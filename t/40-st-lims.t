#########
# Author:        Marina Gourtovaia
# Created:       July 2011
# copied from svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/40-st-lims.t, r16549

use strict;
use warnings;
use Test::More tests => 298;
use Test::Exception;

use_ok('st::api::lims');

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';

my @libs_6551_1 = ('PhiX06Apr11','SS109114 2798524','SS109305 2798523','SS117077 2798526','SS117886 2798525','SS127358 2798527','SS127858 2798529','SS128220 2798530','SS128716 2798531','SS129050 2798528','SS129764 2798532','SS130327 2798533','SS131636 2798534');
my @samples_6551_1 = qw/phiX_for_spiked_buffers SS109114 SS109305 SS117077 SS117886 SS127358 SS127858 SS128220 SS128716 SS129050 SS129764 SS130327 SS131636/;
my @studies_6551_1 = ('Illumina Controls','Discovery of sequence diversity in Shigella sp.');

{
  my $lims = st::api::lims->new(id_run => 6551);
  is($lims->lane_id(), undef, q{lane_id undef for id_run 6551, not a lane} );
  is($lims->batch_id, 12141, 'batch id is 12141');
  is($lims->is_control, 0, 'not control');
  is($lims->is_pool, 0, 'not pool');
  is($lims->library_id, undef, 'no lib id');
  is($lims->seq_qc_state, undef, 'no seq qc state');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is($lims->tags, undef, 'tags undefined');
  is($lims->spiked_phix_tag_index, undef, 'spiked phix tag index undefined');
  is(scalar $lims->descendants, 185, '185 descendant lims');
  is(scalar $lims->children, 8, '8 child lims');
  is($lims->to_string, 'st::api::lims object, driver - xml, batch_id 12141, id_run 6551', 'object as string');
  is($lims->inline_index_end, 10, 'inline index end for an object instance');
  is(st::api::lims->inline_index_end, 10, 'inline index end as a class method');

  throws_ok { $lims->_list_of_properties(q[id], q[bird]) } qr/Invalid object type bird in st::api::lims::_list_of_properties/, 'error with invalid entity name';
  throws_ok { $lims->_list_of_properties(q[colour], q[sample]) } qr/Invalid property colour in st::api::lims::_list_of_properties/, 'error with invalid entity name';
  is(scalar($lims->library_names), 0, 'batch-level library_names list empty');
  is(scalar($lims->sample_names), 0, 'batch-level sample_names list empty');
  is(scalar($lims->study_names), 0, 'batch-level study_names list empty');
}

{
  my $lims = st::api::lims->new(id_run => 6551, position => 1);
  is($lims->lane_id(), 3065552, q{lane_id ok for id_run 6551, position 1} );
  is($lims->batch_id, 12141, 'batch id is 12141 for lane 1');
  is($lims->is_control, 0, 'lane 1 is not control');
  is($lims->is_pool, 1, 'lane 1 is pool');
  is($lims->library_id, 2988920, 'lib id');
  is($lims->library_name, '297p11', 'pool lib name');
  is($lims->seq_qc_state, 1, 'seq qc passed');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is(scalar keys %{$lims->tags}, 13, '13 tags defined');
  is($lims->spiked_phix_tag_index, 168, 'spiked phix tag index 168');
  is($lims->tags->{$lims->spiked_phix_tag_index}, 'ACAACGCAAT', 'tag_sequence for phix');
  is(scalar $lims->children, 13, '13 children');
  is(scalar $lims->associated_lims, 13, '13 associated lims');
  my @plexes = $lims->children;
  my $p1 = $plexes[0];
  my $p6 = $plexes[5];
  is ($p1->tag_index, 1, 'plex tag index');
  is ($p6->tag_index, 6, 'plex tag index');
  is ($p1->default_tag_sequence, 'ATCACGTTAT', 'plex tag sequence');
  is ($p6->default_tag_sequence, 'GCCAATGTAT', 'plex tag sequence');
  is($lims->to_string, 'st::api::lims object, driver - xml, batch_id 12141, id_run 6551, position 1', 'object as string');
  is(join(q[,], $lims->library_names), join(q[,], sort @libs_6551_1), 'pool lane-level library_names list');
  is(join(q[,], $lims->sample_names), join(q[,], sort @samples_6551_1), 'pool lane-level sample_names list');
  is(join(q[,], $lims->study_names), join(q[,], sort @studies_6551_1), 'pool lane-level study_names list');
    
  my $with_spiked_phix = 1;
  is(join(q[,], $lims->library_names($with_spiked_phix)), join(q[,], sort @libs_6551_1), 'pool lane-level library_names list $with_spiked_phix = 1');
  is(join(q[,], $lims->sample_names($with_spiked_phix)), join(q[,], sort @samples_6551_1), 'pool lane-level sample_names list $with_spiked_phix = 1');
  is(join(q[,], $lims->study_names($with_spiked_phix)), join(q[,], sort @studies_6551_1), 'pool lane-level study_names list $with_spiked_phix = 1');

  is(join(q[,], $lims->library_ids($with_spiked_phix)),
     '2389196,2798523,2798524,2798525,2798526,2798527,2798528,2798529,2798530,2798531,2798532,2798533,2798534',
     'pool lane-level library_ids list $with_spiked_phix = 1');
  is(join(q[,], $lims->sample_ids($with_spiked_phix)), 
     '1093818,1093819,1093820,1093821,1093822,1093823,1093824,1093825,1093826,1093827,1093828,1093829,1255141',
     'pool lane-level sample_names list $with_spiked_phix = 1');
  is(join(q[,], $lims->study_ids($with_spiked_phix)), '198,297',
     'pool lane-level study_ids list $with_spiked_phix = 1');
  is(join(q[,], $lims->project_ids($with_spiked_phix)), '297',
     'pool lane-level project_ids list $with_spiked_phix = 1');

  $with_spiked_phix = 0;
  my @libs = @libs_6551_1; shift @libs;
  my @samples = @samples_6551_1; shift @samples;
  my @studies = @studies_6551_1; shift @studies;
  is(join(q[,], $lims->library_names($with_spiked_phix)), join(q[,], sort @libs), 'pool lane-level library_names list $with_spiked_phix = 0;');
  is(join(q[,], $lims->sample_names($with_spiked_phix)), join(q[,], sort @samples), 'pool lane-level sample_names list $with_spiked_phix = 0;');
  is(join(q[,], $lims->study_names($with_spiked_phix)), join(q[,], sort @studies), 'pool lane-level study_names list $with_spiked_phix = 0;');
  is(join(q[,], $lims->library_types()), 'Standard', 'pool lane-level library types list');

  is($lims->sample_consent_withdrawn, undef, 'concent withdrawn false');
}

{
  my $lims = st::api::lims->new(id_run => 6551, position => 1, tag_index => 0);
  is($lims->lane_id(), undef, q{lane_id undef for id_run 6551, position 1, tag_index defined} );
  is($lims->batch_id, 12141, 'batch id is 12141 for lane 1');
  is($lims->is_control, 0, 'lane 1 is not control');
  is($lims->is_pool, 1, 'lane 1 is pool');
  is($lims->library_id, 2988920, 'lib id');
  is($lims->library_name, '297p11', 'pool lib name');
  is($lims->contains_nonconsented_human, 0, 'does not contain nonconsented human');
  is($lims->contains_unconsented_human, 0, 'does not contain unconsented human (back compat)');
  is($lims->contains_nonconsented_xahuman, 0, 'does not contain nonconsented X and autosomal human');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is(scalar keys %{$lims->tags}, 13, '13 tags defined');
  is($lims->spiked_phix_tag_index, 168, 'spiked phix tag index');
  is(scalar $lims->descendants, 13, '13 descendant lims');
  is(scalar $lims->children, 13, '13 child lims');
  is($lims->to_string, 'st::api::lims object, driver - xml, batch_id 12141, id_run 6551, position 1, tag_index 0', 'object as string');
  is(join(q[,], $lims->library_names), join(q[,], sort @libs_6551_1), 'tag 0 library_names list');
  is(join(q[,], $lims->sample_names), join(q[,], sort @samples_6551_1), 'tag 0 sample_names list');
  is(join(q[,], $lims->study_names), join(q[,], sort @studies_6551_1), 'tag 0 study_names list');
    
  my $with_spiked_phix = 1;
  is(join(q[,], $lims->library_names($with_spiked_phix)), join(q[,], sort @libs_6551_1), 'tag 0 library_names list $with_spiked_phix = 1');
  is(join(q[,], $lims->sample_names($with_spiked_phix)), join(q[,], sort @samples_6551_1), 'tag 0 sample_names list $with_spiked_phix = 1');
  is(join(q[,], $lims->study_names($with_spiked_phix)), join(q[,], sort @studies_6551_1), 'tag 0 study_names list $with_spiked_phix = 1');

  $with_spiked_phix = 0;
  my @libs = @libs_6551_1; shift @libs;
  my @samples = @samples_6551_1; shift @samples;
  my @studies = @studies_6551_1; shift @studies;
  is(join(q[,], $lims->library_names($with_spiked_phix)), join(q[,], sort @libs), 'tag 0 library_names list $with_spiked_phix = 0;');
  is(join(q[,], $lims->sample_names($with_spiked_phix)), join(q[,], sort @samples), 'tag 0 sample_names list $with_spiked_phix = 0;');
  is(join(q[,], $lims->study_names($with_spiked_phix)), join(q[,], sort @studies), 'tag 0 study_names list $with_spiked_phix = 0;');
}

{
  my $lims = st::api::lims->new(id_run => 6551, position => 1, tag_index => 168);
  is($lims->is_control, 1, 'tag 1/168 is control');
  is($lims->is_pool, 0, 'tag 1/168 is not a pool');
  is($lims->contains_nonconsented_human, 0, 'does not contain nonconcented human');
  is($lims->contains_nonconsented_xahuman, 0, 'does not contain nonconsented X and autosomal human');
  my $lib_id = 2389196;
  is($lims->library_id, $lib_id, 'hyb buffer lib id');
  my $lib_name = 'PhiX06Apr11';
  is($lims->library_name, $lib_name, 'hyb buffer lib name');
  my $sample_id = 1255141;
  is($lims->sample_id, $sample_id, 'hyb buffer sample id');
  my $study_id = 198;
  is($lims->study_id, $study_id, 'hyb buffer study id');
  is($lims->reference_genome, undef, 'reference genome not set');
  is($lims->tag_sequence, 'ACAACGCAAT', 'tag_sequence for phix');
  is($lims->tags, undef, 'tags undefined');
  is($lims->seq_qc_state, undef, 'no seq qc state');
  is($lims->spiked_phix_tag_index, 168, 'spiked phix tag index returned');
  is(scalar $lims->associated_lims, 0, 'no associated lims');
  is(scalar $lims->descendants, 0, 'no descendant lims');
  is(scalar $lims->associated_child_lims, 0, 'no associated child lims');
  is(scalar $lims->children, 0, 'no child lims');
  is(join(q[ ], $lims->library_names), $libs_6551_1[0], 'tag 168 library_names list');
  is(join(q[ ], $lims->sample_names), $samples_6551_1[0], 'tag 168 sample_names list');
  is(join(q[ ], $lims->study_names), $studies_6551_1[0], 'tag 168 study_names list');

  my $with_spiked_phix = 0;
  is(join(q[ ], $lims->library_names($with_spiked_phix)), $libs_6551_1[0], 'tag 168 library_names list');
  is(join(q[ ], $lims->sample_names($with_spiked_phix)), $samples_6551_1[0], 'tag 168 sample_names list');
  is(join(q[ ], $lims->study_names($with_spiked_phix)), $studies_6551_1[0], 'tag 168 study_names list');
}

{
  my $lims = st::api::lims->new(id_run => 6551, position => 1, tag_index => 1);
  is($lims->is_control, 0, 'tag 1/1 is not control');
  is($lims->is_pool, 0, 'tag 1/1 is not a pool');
  is($lims->contains_nonconsented_human, 0, 'does not contain nonconcented human');
  is($lims->contains_nonconsented_xahuman, 0, 'does not contain nonconsented X and autosomal human');
  is($lims->spiked_phix_tag_index, 168, 'spiked phix tag index returned');
  is(join(q[ ], $lims->library_names), 'SS109305 2798523', 'tag 1 library_names list');
  is(join(q[ ], $lims->sample_names), 'SS109305', 'tag 1 sample_names list');
  is(join(q[ ], $lims->study_names), $studies_6551_1[1], 'tag 1 study_names list');

  my $with_spiked_phix = 0;
  is(join(q[ ], $lims->library_names($with_spiked_phix)), 'SS109305 2798523', 'tag 1 library_names list $with_spiked_phix = 0');
  is(join(q[ ], $lims->sample_names($with_spiked_phix)), 'SS109305', 'tag 1 sample_names list $with_spiked_phix = 0');
  is(join(q[ ], $lims->study_names($with_spiked_phix)), $studies_6551_1[1], 'tag 1 study_names list $with_spiked_phix = 0');
}

{
  my $lims = st::api::lims->new(id_run => 6607, position => 1);  # non-pool lane
  isa_ok($lims, 'st::api::lims');
  is($lims->batch_id, 12378, 'batch id for lane 1');
  is($lims->is_control, 0, 'lane 1 is not control');
  is($lims->is_pool, 0, 'lane 1 is not pool');
  is($lims->library_id, 3033734, 'lib id');
  is($lims->sample_id, 1121926, 'sample id');
  is($lims->study_id, 1811, 'study id');
  is($lims->project_id, 810, 'project id');
  is($lims->contains_nonconsented_human, 0, 'does not contain nonconcented human');
  is($lims->contains_nonconsented_xahuman, 0, 'does not contain nonconsented X and autosomal human');
  is($lims->request_id, 3156170, 'request id');
  is($lims->library_name, 'BS_3hrsomuleSm_202790 3033734', 'lib name');
  is($lims->sample_name, 'BS_3hrsomuleSm_202790', 'sample name');
  is($lims->study_name, 'Schistosoma mansoni methylome', 'study name');
  is($lims->project_name, 'Schistosoma mansoni methylome', 'project name');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is($lims->tags, undef, 'tags undefined');
  is($lims->spiked_phix_tag_index, undef, 'spiked phix tag index undefined');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is($lims->seq_qc_state, undef, 'seq qc not set');
  is(scalar $lims->associated_lims, 0, 'no associated lims');

  my @methods;
  lives_ok {@methods = $lims->method_list} 'list of attributes generated';
  foreach my $method (@methods) {
    lives_ok {$lims->$method} qq[invoking method or attribute $method does not throw an error];
  }

  is(join(q[ ], $lims->library_names), 'BS_3hrsomuleSm_202790 3033734', 'non-pool lane library_names list');
  is(join(q[ ], $lims->sample_names), 'BS_3hrsomuleSm_202790', 'non-pool lane sample_names list');
  is(join(q[ ], $lims->study_names), 'Schistosoma mansoni methylome', 'non-pool lane study_names list');
}

{
  my $lims = st::api::lims->new(id_run => 6607, position => 2); # non-pool lane
  is($lims->seq_qc_state, undef, 'seq qc not set for pending');
  is($lims->lane_priority, 0, 'priority 0');
  $lims = st::api::lims->new(id_run => 6607, position => 3);
  is($lims->seq_qc_state, 1, 'seq qc 1 for pass');
  is($lims->lane_priority, 1, 'priority 1');
  $lims = st::api::lims->new(id_run => 6607, position => 4);
  is($lims->seq_qc_state, 0, 'seq qc 0 for fail');
  $lims = st::api::lims->new(id_run => 6607, position => 5);
  throws_ok {$lims->seq_qc_state} qr/Unexpected value 'some' for seq qc state/, 'error for unexpected qc state';
  $lims = st::api::lims->new(id_run => 6607, position => 5, tag_index => 1);
  is($lims->lane_priority, undef, 'priority undefined on plex level');
  $lims = st::api::lims->new(id_run => 6607);
  is($lims->lane_priority, undef, 'priority undefined on batch level');
}

{
  my $lims = st::api::lims->new(id_run => 6607, position => 5); # pool lane, not spiked
  is($lims->batch_id, 12378, 'batch id for lane 5');
  is($lims->tag_index, undef, 'tag index undefined');
  is($lims->is_control, 0, 'lane 5 is not control');
  is($lims->is_pool, 1, 'lane 5 is pool');
  is($lims->library_id, 3111688, 'lib id');
  is($lims->sample_id, undef, 'sample id undefined');
  is($lims->study_id, 429, 'study id');
  is($lims->project_id, 429, 'project id');
  is($lims->request_id, 3259935, 'request id');
  is($lims->library_name, '3C_HiC_Pool3', 'lib name');
  is($lims->sample_name, undef, 'sample name undefined');
  is($lims->study_name, '3C and HiC of Plasmodium falciparum IT', 'study name');
  my $description = q[Illumina sequencing of chromatin conformation capture and its derivatives is being carried out to study nuclear architecture in antigenically selected lines of Plasmodium falciparum. This data is part of a pre-publication release. For information on the proper use of pre-publication data shared by the Wellcome Trust Sanger Institute (including details of any publication moratoria), please see http://www.sanger.ac.uk/datasharing/];
  is($lims->study_description, $description, 'study description');
  is($lims->project_name, '3C and HiC of Plasmodium falciparum IT', 'project name');
  my $expected_tags = {1=>'ATCACGTT', 2=>'CGATGTTT', 3=>'TTAGGCAT', 4=>'TGACCACT', 5=>'ACAGTGGT', 6=>'GCCAATGT', 7=>'CAGATCTG',
                       8 => 'ACTTGATG', 9=>'GATCAGCG',};
  is_deeply($lims->tags, $expected_tags, 'tags mapping');
  is($lims->spiked_phix_tag_index, undef, 'spiked phix tag index undefined');
  is($lims->tag_sequence, undef, 'tag_sequence undefined');
  is($lims->to_string, 'st::api::lims object, driver - xml, batch_id 12378, id_run 6607, position 5', 'object as string');

  my $libs = 'HIC_M_B15C2 3111683,HiC_H_Dd2 3111680,HiC_H_LT3D7 3111687,HiC_H_OFF_DCJ 3111682,HiC_H_ON_DCJ 3111679,HiC_H_PQP1 3111681,HiC_M_3D7 3111685,HiC_M_ER3D7 3111686,HiC_M_Rev1 3111684';
  my $samples = 'HIC_M_B15C2,HiC_H_Dd2,HiC_H_LT3D7,HiC_H_OFF_DCJ,HiC_H_ON_DCJ,HiC_H_PQP1,HiC_M_3D7,HiC_M_ER3D7,HiC_M_Rev1';
  my $study = '3C and HiC of Plasmodium falciparum IT';
  is(join(q[,], $lims->library_names), $libs, 'pooled not-spiked lane library_names list');
  is(join(q[,], $lims->sample_names), $samples, 'pooled not-spiked lane sample_names list');
  is(join(q[,], $lims->study_names), $study, 'pooled not-spiked lane study_names list');

  my $with_spiked_phix = 0;
  is(join(q[,], $lims->library_names($with_spiked_phix)), $libs, 'pooled not-spiked lane library_names list $with_spiked_phix = 0');
  is(join(q[,], $lims->sample_names($with_spiked_phix)), $samples, 'pooled not-spiked lane sample_names list $with_spiked_phix = 0');
  is(join(q[,], $lims->study_names($with_spiked_phix)), $study, 'pooled not-spiked lane study_names list $with_spiked_phix = 0');
}

{
  my $lims = st::api::lims->new(id_run => 6607, position => 5, tag_index => 1);
  my $lims_nofb = st::api::lims->new(id_run => 6607, position => 5, tag_index => 1);
  is($lims->batch_id, 12378, 'batch id for lane 5 tag 1');
  is($lims->tag_index, 1, 'tag index 1');
  is($lims->is_control, 0, 'plex 5/1 is not control');
  is($lims->is_pool, 0, 'plex 5/1 is not pool');
  is($lims->library_id, 3111679, 'lib id');
  is($lims->sample_id, 1132331, 'sample id');
  is($lims->study_id, 429, 'study id'); # fallback
  my $project_id = 429;
  is($lims_nofb->study_id, $project_id, 'study id'); # no fallback
  is($lims->project_id, $project_id, 'project id');
  is($lims->request_id, undef, 'request id');
  is($lims->library_name, 'HiC_H_ON_DCJ 3111679', 'lib name');
  is($lims->sample_name, 'HiC_H_ON_DCJ', 'sample name undefined');
  is($lims->study_name, '3C and HiC of Plasmodium falciparum IT', 'study name');
  my $project_name = q[3C and HiC of Plasmodium falciparum IT];
  is($lims->project_name, $project_name, 'project name');
  is($lims->tag_sequence, 'ATCACGTT', 'tag_sequence');
  is($lims->tags, undef, 'tags undefined');
  is($lims->spiked_phix_tag_index, undef, 'spiked phix tag index undefined');
  ok(!$lims->alignments_in_bam, 'no bam alignment');
  is($lims->seq_qc_state, undef, 'no seq qc state');
  is(scalar $lims->associated_lims, 0, 'no associated lims');
}

{
  my $lims = st::api::lims->new(batch_id => 13410, position => 1);
  ok(!$lims->is_control, 'lane is not a control (despite having a control tag within its hyb buffer tag)');
}

{
  my $lims = st::api::lims->new(id_run => 6607);
  is($lims->library_type, undef, 'library type undefined on a batch level');
  $lims = st::api::lims->new(id_run => 6607, position => 2); # non-pool lane
  is($lims->library_type, 'Illumina cDNA protocol', 'library type');
  $lims = st::api::lims->new(id_run => 6607, position => 5);
  is($lims->library_type, undef, 'library type undefined for a pool');
  $lims = st::api::lims->new(id_run => 6607, position => 5, tag_index => 0);
  is($lims->library_type, undef, 'library type undefined for tag 0');
  $lims = st::api::lims->new(id_run => 6607, position => 5, tag_index => 1);
  is($lims->library_type, 'Custom', 'library type');
  $lims = st::api::lims->new(id_run => 6607, position => 6, tag_index => 8);
  is($lims->library_type, 'Standard', 'library type');
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/npg_api';
  my $lims = st::api::lims->new(batch_id   => 1536,position => 5);
  ok(!$lims->is_pool, 'lane is not a pool');
  is($lims->contains_nonconsented_human, 1, 'contains nonconsented human');
  is($lims->contains_unconsented_human, 1, 'contains unconsented human (back compat)');

  $lims = st::api::lims->new(batch_id => 13861, position => 2);
  ok($lims->is_pool, 'lane is a pool');
  ok($lims->contains_nonconsented_human, 'pool contains unconsented human');

  $lims = st::api::lims->new(batch_id => 13861, position => 2, tag_index => 0);
  ok($lims->contains_nonconsented_human, 'tag 0 contains unconsented human');
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/npg_api';
  my $lims = st::api::lims->new(batch_id   => 16442);
  is($lims->bait_name, undef, 'bait name undefined on a batch level');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1);
  is($lims->bait_name, undef, 'bait name undefined on a pool level');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 2);
  is($lims->bait_name,'Human all exon 50MB', 'bait name for a plex');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 3);
  is($lims->bait_name,'Fox bait', 'bait name for another plex');
  $lims = st::api::lims->new(batch_id   => 16442, position => 8, tag_index=> 5);
  is($lims->bait_name,'Mouse some exon', 'bait name for yet another plex');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 4);
  is($lims->bait_name, undef, 'bait name undefined if no bait element');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 5);
  is($lims->bait_name, undef, 'bait name undefined if no bait name tag is empty');
  $lims = st::api::lims->new(batch_id   => 16442, position => 1, tag_index=> 168);
  is($lims->bait_name, undef, 'bait name undefined for hyp buffer');

  $lims = st::api::lims->new(batch_id   => 3022, position => 1);
  is($lims->bait_name,'Mouse all exon', 'bait name for a non-pool lane');
  $lims = st::api::lims->new(batch_id   => 3022, position => 2);
  is($lims->bait_name, undef, 'bait name undefined for a non-pool lane if there is no bait element');
  $lims = st::api::lims->new(batch_id   => 3022, position => 4);
  is($lims->bait_name, undef, 'bait name undefined for a control lane despite the presence of the bait element');
}

{
  my $lims;
TODO: {
  local $TODO = 'should nonconsented propagate up to run/batch (as plex dooes to lane) with "or"s?';
  $lims = st::api::lims->new(id_run => 8260);
  is($lims->contains_nonconsented_xahuman, 1, 'run does contain nonconsented X and autosomal human');
}
  $lims = st::api::lims->new(id_run => 8260, position => 2);
  is($lims->contains_nonconsented_xahuman, 0, 'lane 2 does not contain nonconsented X and autosomal human');
  $lims = st::api::lims->new(id_run => 8260, position => 8);
  is($lims->contains_nonconsented_xahuman, 1, 'lane 8 does contain nonconsented X and autosomal human');
  $lims = st::api::lims->new(id_run => 8260, position => 2, tag_index => 33);
  is($lims->contains_nonconsented_xahuman, 0, 'plex 33 lane 2 does not contain nonconsented X and autosomal human');
  $lims = st::api::lims->new(id_run => 8260, position => 8, tag_index => 57);
  is($lims->contains_nonconsented_xahuman, 1, 'plex 57 lane 8 does contain nonconsented X and autosomal human');
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/tag_from_sample_description';
  #diag q[Tests for deducing tags from batch 19158 (associated with run 3905 by hand)]; 
  my $lims8 = st::api::lims->new(batch_id => 19158, position => 8);
  my @alims8 = $lims8->associated_lims;
  is(scalar @alims8, 7, 'Found 7 plexes in position 8');

  #diag q[Checking tag created by _build_tag is equal to the description value, not the tag value in expected_sequence, if a tag is available in the description];

  my @tags = $lims8->tags();
  is(scalar @tags, 1, 'Found 1 tags array');

  cmp_ok($tags[0]->{5}, q(ne), q(ACAGTGGT), 'Do not use expected_sequence sequence for tag');
  cmp_ok($tags[0]->{5}, q(eq), q(GTAGAC), 'Use sample_description sequence for tag');

  #diag q[Checking tag created by _build_tag is equal to the expected_sequence where no sample description is available];

  my $lims1 = st::api::lims->new(batch_id => 19158, position => 1);
  my @alims1 = $lims1->associated_lims;
  is(scalar @alims1, 6, 'Found 6 plexes in position 1');

  my @tags1 = $lims1->tags();
  is(scalar @tags1, 1, 'Found 1 tags array');

  cmp_ok($tags1[0]->{144}, q(eq), q(CCTGAGCA), 'Use expected_sequence sequence for tag');

  #diag q[Checking library_type is changed to 3 prime poly-A pulldown where tag is taken from sample description];

  my $lims85 = st::api::lims->new(batch_id => 19158, position => 8, tag_index => 5);
  is($lims85->library_type, '3 prime poly-A pulldown', 'library type');
  is($lims85->tag_sequence, 'GTAGAC', 'plex tag sequence from sample description');
  ok($lims85->sample_description =~ /end enriched mRNA/sm, 'sample description available');

  #diag q[Checking library_type is not changed to 3 prime poly-A pulldown where no sample description is available];

  my $lims1144 = st::api::lims->new(batch_id => 19158, position => 1, tag_index => 144);
  isnt($lims1144->library_type, '3 prime poly-A pulldown', 'library type');
  is($lims1144->tag_sequence, 'CCTGAGCA', 'plex tag sequence directly from batch xml');
}

{
  local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';
  my $lims = st::api::lims->new(batch_id=>17763, position=>1,tag_index=>1);
  is( $lims->study_title(), 'hifi test', q{study title} );
  is( $lims->study_name(), 'Kapa HiFi test', 'study name');
  is( $lims->study_accession_number(), undef, q{no study accession obtained} );
  is( $lims->study_publishable_name(), q{hifi test}, q{study title returned as publishable name} );

  $lims = st::api::lims->new(batch_id=>17763, position=>1,tag_index=>2);
  ok(! $lims->alignments_in_bam, 'no alignments in BAM when false in corresponding XML in study');
  is( $lims->study_title(), 'Genetic variation in Kuusamo', q{study title obtained} );
  is( $lims->study_accession_number(), 'EGAS00001000020', q{study accession obtained} );
  is( $lims->study_publishable_name(), 'EGAS00001000020', q{accession returned as study publishable name} );
  is( $lims->sample_publishable_name(), q{ERS003242}, q{sample publishable name returns accession} );
}

{
  my $sample_description =  'AB GO (grandmother) of the MGH meiotic cross. The same DNA was split into three aliquots (of which this';
  is(st::api::lims::_tag_sequence_from_sample_description($sample_description), undef, q{tag undefined for a description containing characters in round brackets} );
  $sample_description = "3' end enriched mRNA from morphologically abnormal embryos from dag1 knockout incross 3. A 6 base indexing sequence (GTAGAC) is bases 5 to 10 of read 1 followed by polyT.  More information describing the mutant phenotype can be found at the Wellcome Trust Sanger Institute Zebrafish Mutation Project website http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/zmp/search.pl?q=zmp_phD";
  is(st::api::lims::_tag_sequence_from_sample_description($sample_description), q{GTAGAC}, q{correct tag from a complex description} );
  $sample_description = "^M";
  is(st::api::lims::_tag_sequence_from_sample_description($sample_description), undef, q{tag undefined for a description with carriage return} );
}

{
  my $path = 't/data/samplesheet/MS2026264-300V2.csv';
  my $ss = st::api::lims->new(id_run => 10262,  path => $path, driver_type => 'samplesheet');
  is ($ss->is_pool, 0, 'is_pool false on run level');
  is ($ss->is_control, 0, 'is_control false on run level');
  is ($ss->library_id, undef, 'library_id undef on run level');
  is ($ss->library_name, undef, 'library_name undef on run level');
}

1;

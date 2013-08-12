#########
# Author:        gq1
# Maintainer:    $Author: dj3 $
# Created:       2008-01-18
# Last Modified: $Date: 2010-03-08 12:17:17 +0000 (Mon, 08 Mar 2010) $
# Id:            $Id: 40-st-project.t 8603 2010-03-08 12:17:17Z dj3 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/branches/prerelease-42.0/t/40-st-project.t $
#
use strict;
use warnings;
use Test::More tests => 26;
use Test::Exception;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 8603 $ =~ /(\d+)/mx; $r; };

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';

use_ok('st::api::study');

{
  my $study = st::api::study->new();
  isa_ok($study, 'st::api::study');
}

{
  my $study = st::api::study->new({id => 11});
  is($study->name(), q{Trypanosoma brucei}, 'correct study name');
  ok(!$study->contains_unconsented_human(), 'study 11 no unconsented human');
  is($study->reference_genome, 'dodo', 'reference genome ');
}

{
  my $study = st::api::study->new({id  => 162,});
  ok($study->contains_unconsented_human() , 'Marked with unconsented human'); #backward compat
  ok($study->contains_nonconsented_human() , 'Marked with nonconsented human');
  is_deeply($study->email_addresses,[qw(chc@sanger.ac.uk deh@sanger.ac.uk hss@sanger.ac.uk jm15@sanger.ac.uk nds@sanger.ac.uk sh16@sanger.ac.uk tfelt@sanger.ac.uk)],'All email addresses');
  is_deeply($study->email_addresses_of_managers,[qw(chc@sanger.ac.uk jm15@sanger.ac.uk nds@sanger.ac.uk)],'Managers email addresses');
  is_deeply($study->email_addresses_of_followers,[qw(chc@sanger.ac.uk deh@sanger.ac.uk hss@sanger.ac.uk sh16@sanger.ac.uk)],'Followers email addresses');
  is_deeply($study->email_addresses_of_owners,[qw(tfelt@sanger.ac.uk)],'Owners email addresses');
  is($study->reference_genome, undef, 'reference genome undefined for study 162');

  my $study2 = st::api::study->new({id  => 292,});
  ok(!$study2->contains_unconsented_human() , 'Not marked with unconsented human'); #backward compat
  ok(!$study2->contains_nonconsented_human() , 'Not marked with nonconsented human');
  lives_and {ok(!$study2->contains_nonconsented_xahuman()) }  'Not marked with nonconsented X and autosome human';

  my $study3 = st::api::study->new({id  => 2278,});
  lives_and {ok($study3->contains_nonconsented_xahuman()) }  'Marked with nonconsented X and autosome human';
}

{
  my $study = st::api::study->new({id => 11,});
  ok($study->alignments_in_bam, 'alignments in BAM when no corresponding XML in study');
  $study = st::api::study->new({id => 700,});
  ok($study->alignments_in_bam, 'alignments in BAM when true in corresponding XML in study');
  is( $study->title(), 'hifi test', q{title} );
  is( $study->name(), 'Kapa HiFi test', 'study name');
  is( $study->accession_number(), undef, q{no accession obtained} );
  $study = st::api::study->new({id => 701,});
  ok(! $study->alignments_in_bam, 'no alignments in BAM when false in corresponding XML in study');
  is( $study->title(), 'Genetic variation in Kuusamo', q{title obtained} );
  is( $study->accession_number(), 'EGAS00001000020', q{accession obtained} );
  ok(! $study->separate_y_chromosome_data, 'separate_y_chromosome_data false for study');
}

{
  my $study = st::api::study->new({id => 2693});
  ok($study->separate_y_chromosome_data, 'separate_y_chromosome_data true for study');
}

1;

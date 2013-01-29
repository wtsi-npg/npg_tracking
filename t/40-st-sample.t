#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2013-01-07 11:04:50 +0000 (Mon, 07 Jan 2013) $
# Id:            $Id: 40-st-sample.t 16389 2013-01-07 11:04:50Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/40-st-sample.t $
#
use strict;
use warnings;
use Test::More tests => 27;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 16389 $ =~ /(\d+)/mx; $r; };

local $ENV{NPG_WEBSERVICE_CACHE_DIR} = 't/data/st_api_lims_new';

use_ok('st::api::sample');

my $sample = st::api::sample->new({id  => 1750,});
isa_ok($sample, 'st::api::sample', 'isa ok');

is($sample->id(),         1750,                'id ok');
is($sample->name(),       'p242-NspI-PCR 2A2', 'name fetched ok');
is($sample->organism(), 'Danio rerio', 'organism field fetched ok');

my $sample_description =  'AB GO (grandmother) of the MGH meiotic cross. The same DNA was split into three aliquots (of which this is reaction A), processed in parallel, they were:  NspI cut, ligated with modified recuttable adaptor (ATTATGAGCACGACAGACGCCTGATCTRCATG and YAGATCAGGCGTCTGTCGTGCTCATAA), and PCR amplified.';
is($sample->description(), $sample_description, 'Description field fetched ok');
is($sample->tag_sequence_from_description(), undef, q{tag undefined for a description containing characters in round brackets} );
$sample_description = "3' end enriched mRNA from morphologically abnormal embryos from dag1 knockout incross 3. A 6 base indexing sequence (GTAGAC) is bases 5 to 10 of read 1 followed by polyT.  More information describing the mutant phenotype can be found at the Wellcome Trust Sanger Institute Zebrafish Mutation Project website http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/zmp/search.pl?q=zmp_phD";
is(st::api::sample->new()->tag_sequence_from_description($sample_description), q{GTAGAC}, q{correct tag from a complex description} );

my $desc_with_carriage_return = "^M";
is( st::api::sample->new()->tag_sequence_from_description($desc_with_carriage_return), undef, q{tag undefined for a description with carriage return} );

$sample = st::api::sample->new({id  => 7283,});
cmp_ok($sample->id(), q(==), 7283, 'id ok');
cmp_ok($sample->name(), q(eq), 'PD3918a', 'name fetched ok');
cmp_ok($sample->organism(), q(eq), 'Human', 'organism fetched ok');
is($sample->taxon_id(), 9606, 'taxon ID');
is($sample->common_name(), 'Homo sapiens', 'common name');
is($sample->public_name(), undef, 'public name undefined');
is($sample->strain(), undef, 'strain undefined');
is($sample->reference_genome(), undef, 'sample reference genome undefined');

$sample = st::api::sample->new({id  => 10881,});
is($sample->organism(), 'Salmonella enterica Java', 'organism fetched ok');
is($sample->taxon_id(), '224729', 'TAXON ID fetched ok');
is($sample->common_name(), 'Salmonella enterica subsp. enterica serovar Java', 'Common Name fetched ok');
is($sample->public_name(), 'H083280501', 'public name fetched ok');
is($sample->strain(), 'S java', 'strain fetched ok');

is( st::api::sample->new({id => 11036,})->publishable_name(), q{ERS003242}, q{publishable name returns accession} );
is( st::api::sample->new({id => 1121926,})->reference_genome(), 'Schistosoma_mansoni (20100601)', 'ref genome');

ok( !st::api::sample->new({id => 11036,})->consent_withdrawn(), q{consent not withdrawn for sample 11036} );
ok( !st::api::sample->new({id => 1121926,})->consent_withdrawn(), q{consent withdrawn not given for sample 1121926} );
ok( st::api::sample->new({id => 1299723,})->consent_withdrawn(), q{consent withdrawn for sample 1299723} );

1;

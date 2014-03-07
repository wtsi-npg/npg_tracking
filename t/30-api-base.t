#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-03-01 10:36:10 +0000 (Thu, 01 Mar 2012) $
# Id:            $Id: 30-api-base.t 15277 2012-03-01 10:36:10Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/30-api-base.t $
#
use strict;
use warnings;
use Test::More tests => 6;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15277 $ =~ /(\d+)/mx; $r; };

use_ok('npg::api::base');

my $base1 = npg::api::base->new();
isa_ok($base1->util(), 'npg::api::util', 'constructs');

my $base2 = npg::api::base->new({
         util        => $base1->util(),
        });
is($base1->util(), $base2->util(), 'yields the util given on construction');

$base2->{'read_dom'} = 'foo';
$base2->flush();
is($base2->{'read_dom'}, undef, 'dom cache flushes');
is($base2->fields(), (), 'no fields in base class');
is($base2->large_fields(), (), 'no large fields in base class');

1;

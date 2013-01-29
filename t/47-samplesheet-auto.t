#########
# Author:        dj3
# Maintainer:    $Author: mg8 $
# Created:       2012-04-02
# Last Modified: $Date: 2012-04-02 15:17:16 +0100 (Mon, 02 Apr 2012) $
# Id:            $Id: 47-samplesheet-auto.t 15422 2012-04-02 14:17:16Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/47-samplesheet-auto.t $

use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;

use t::dbic_util;
local $ENV{dev} = q(wibble); # ensure we're not going live anywhere

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15422 $ =~ /(\d+)/msx; $r; };

use_ok('npg::samplesheet::auto');

my $schema = t::dbic_util->new->test_schema();
local $ENV{NPG_WEBSERVICE_CACHE_DIR} = q(t/data/samplesheet);

{
  my $sm;
  lives_ok { $sm = npg::samplesheet::auto->new(npg_tracking_schema=>$schema); } 'miseq monitor object';
  isa_ok($sm, 'npg::samplesheet::auto');
}


1;
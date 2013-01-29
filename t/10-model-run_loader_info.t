#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-02-01
# Last Modified: $Date: 2012-03-27 13:38:46 +0100 (Tue, 27 Mar 2012) $
# Id:            $Id: 10-model-run_loader_info.t 15395 2012-03-27 12:38:46Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-run_loader_info.t $
#
use strict;
use warnings;
use t::util;
use Test::More tests => 3;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15395 $ =~ /(\d+)/mx; $r; };

use_ok('npg::model::run');
my $util = t::util->new({fixtures => 0,});

{
  my $run_model = npg::model::run->new({
                                      id_run => 10,
                                      util => $util,
                                    });
  isa_ok($run_model, 'npg::model::run');
  $run_model->{loader_info}->{''} = {loader=>'ajb', date=>'2010-06-11'};
  is($run_model->loader_info()->{loader}, 'ajb', 'Does not fetch anything if loader already cached');
}

1;

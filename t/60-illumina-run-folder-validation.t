#########
# Author:        gq1
# Maintainer:    $Author: mg8 $
# Created:       2010-05-05
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# Id:            $Id: 60-illumina-run-folder-validation.t 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/60-illumina-run-folder-validation.t $
#

use strict;
use warnings;
use Test::More tests => 4;
use Test::Exception;

local $ENV{'NPG_WEBSERVICE_CACHE_DIR'} = q[t/data/long_info];

BEGIN {
  use_ok(q{npg_tracking::illumina::run::folder::validation});
}

my $validation;
{
  $validation = npg_tracking::illumina::run::folder::validation->new(
                                                        run_folder => '100505_IL45_4655',
                                                       );
   ok(!$validation->check, 'Run folder 100505_IL45_4655 NOT match 100429_IL38_4655 from npg');
}

{
  $validation = npg_tracking::illumina::run::folder::validation->new(id_run    => 4655,
                                                        run_folder => '100429_IL38_4655',
                                                       );
  ok($validation->check, 'Run folder 100505_IL45_4655 match 100429_IL38_4655 from npg');
}

{
  $validation = npg_tracking::illumina::run::folder::validation->new(
                                                        run_folder => '100429_IL38_4655',
                                                        no_npg_check =>1,
                                                       );
  ok($validation->check, 'Run folder 100505_IL45_4655 not checked from npg');
}

1;

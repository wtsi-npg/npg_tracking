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

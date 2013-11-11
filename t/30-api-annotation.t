#########
# Author:        rmp
# Created:       2007-10
# copied from : svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/30-api-annotation.t, r15277
#
use strict;
use warnings;
use Test::More tests => 9;
use IO::Scalar;
use t::useragent;
use npg::api::util;

use_ok('npg::api::annotation');

my $base_url = $npg::api::util::LIVE_BASE_URI;

my $ann1 = npg::api::annotation->new();
isa_ok($ann1, 'npg::api::annotation');

is($ann1->large_fields(), ('attachment'));

my $data = 'some data';
is($ann1->attachment(), undef);

$ann1->attachment($data);
is($ann1->attachment(), $data);

my $ann2 = npg::api::annotation->new({
				      'attachment' => IO::Scalar->new(\$data),
				     });
is($ann2->attachment(), $data);

my $ann3 = npg::api::annotation->new();
$ann3->attachment(IO::Scalar->new(\$data));
is($ann3->attachment(), $data);

{
  my $uri  = $base_url . '/annotation/1;read_attachment';
  my $ua   = t::useragent->new({'is_success' => 1, 'mock' => {$uri => $data,},});
  my $util = npg::api::util->new({'useragent' => $ua});

  my $ann4 = npg::api::annotation->new({
					'util'            => $util,
					'id_annotation'   => 1,
					'attachment_name' => 'test attachment',
                                        'max_retries'     => 1,
				       });
  is($ann4->attachment(), $data, 'attachment retrieved');
}

{
  my $mock = {$base_url . 'annotation/1;read_attachment' => $data,};
  my $ua   = t::useragent->new({'is_success' => 1, 'mock' => $mock});
  my $util = npg::api::util->new({'useragent' => $ua});
  my $ann4;
  $ann4 = npg::api::annotation->new({
				     'util'            => $util,
				     'attachment_name' => 'test attachment',
				    });
  is($ann4->attachment(), undef);
}

1;

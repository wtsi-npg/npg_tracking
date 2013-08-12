#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model.t $
#
use strict;
use warnings;
use Test::More tests => 10;
use Sys::Hostname;
use Socket;
use t::util;

my $util = t::util->new({ fixtures => 1 });
use_ok('npg::model');
{
  my $model = npg::model->new({util => $util});
  is($model->model_type(), 'model', 'entity type returns last part of reference to object');
}

{
  use npg::model::run;
  my $run = npg::model::run->new({ util => $util });
  my $run_tags = $run->all_tags_assigned_to_type();
  is($run->all_tags_assigned_to_type(), $run_tags, 'cached ok');
  isa_ok($run_tags, 'ARRAY', 'all_tags_assigned_to_type returns array');
  isa_ok($run_tags->[0], 'npg::model::tag', 'array objects are npg::model::tag objects');
}

{
  my $model = npg::model->new({
    util => $util,
  });
  my $hostname = hostname;
  my($addr)=inet_ntoa((gethostbyname(hostname))[4]);
  is($util->dbh->do("update instrument set instrument_comp='$hostname' where id_instrument=3"), 1, 'one row in test db updated');

  is( $model->location_is_instrument(), undef, q{undef returned with no headers set} );
  $ENV{HTTP_X_FORWARDED_FOR} = qq{$addr, 127.0.0.2};
  $ENV{REMOTE_ADDR} = q{127.0.0.5};
  is( $model->location_is_instrument(), 3, q{instrument found from HTTP_X_FORWARDED_FOR} ); 
  is( $model->location_is_instrument(), 3, q{instrument found from cache} );
  $model->{location_is_instrument} = undef;
  $ENV{HTTP_X_FORWARDED_FOR} = q{127.0.0.2, 444::666};
  $ENV{REMOTE_ADDR} = qq{$addr};
  is( $model->location_is_instrument(), 3, q{instrument found from REMOTE_ADDR} );
}

1;

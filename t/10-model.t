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
use Test::More tests => 12;
use t::util;

use Readonly; Readonly::Scalar our $VERSION => do { my @r = (q$LastChangedRevision: 14928 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

my $util = t::util->new({ fixtures => 1 });
{
  use_ok('npg::model');

  my $derived = t::derived->new();
  is($derived->uid(), '20071016T134300Z0', 'first uid from zdate is ok');
  is($derived->uid(), '20071016T134300Z1', 'second uid from zdate is ok');

  my $model = npg::model->new({util => $util});
  is($model->model_type(), 'model', 'entity type returns last part of reference to object');
  like($model->dbh_datetime(), qr/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, 'date returned from database');
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
    util => t::util->new(),
  });

  my $insts = [];
  my @instruments = (
    {
      id_instrument => 1,
      name => q{HS1},
      iscurrent => 1,
      ipaddr => q{127.0.0.1},
      instrument_comp => q{hs1},
      util => $util,
      instruments => $insts,
      current_instruments => $insts,
    },
    {
      id_instrument => 2,
      name => q{HS2},
      iscurrent => 1,
      ipaddr => q{127.0.0.2},
      instrument_comp => q{hs2},
      util => $util,
      instruments => $insts,
      current_instruments => $insts,
    },
    {
      id_instrument => 3,
      name => q{HS3},
      iscurrent => 1,
      ipaddr => q{127.0.0.3},
      instrument_comp => q{hs3},
      util => $util,
      instruments => $insts,
      current_instruments => $insts,
    },
    {
      id_instrument => 4,
      name => q{HS4},
      iscurrent => 1,
      ipaddr => q{127.0.0.4},
      instrument_comp => q{hs4},
      util => $util,
      instruments => $insts,
      current_instruments => $insts,
    },
  );

  foreach my $inst ( @instruments ) {
    push @{ $insts }, npg::model::instrument->new($inst);
  }

  my $inst_model = $insts->[0];

  is( $model->location_is_instrument( $inst_model ), undef, q{undef returned with no headers set} );

  $ENV{HTTP_X_SEQUENCER} = q{126.0.0.1 127.0.0.1};
  is( $model->location_is_instrument( $inst_model ), 1, q{id_instrument 1 returned with HTTP_X_SEQUENCER set} );
  is( $model->{location_is_instrument}, 1, q{cache set} );
  $model->{location_is_instrument} = undef;

  $ENV{HTTP_X_SEQUENCER} = q{126.0.0.1};
  $ENV{HTTP_X_FORWARDED_FOR} = q{125.0.0.2, 127.0.0.2};
  $ENV{REMOTE_ADDR} = q{127.0.0.5};

  $model->{_comp_name_by_host} = {
    q{127.0.0.2} => q{hs2},
  };
  is( $model->location_is_instrument( $inst_model ), 2, q{instrument found when hostname used} );
}

package t::derived;
use strict;
use warnings;
use base qw(npg::model);

sub zdate {
  return '2007-10-16T13:43:00Z';
}

1;

#########
# Author:        gq1
# Maintainer:    $Author: mg8 $
# Created:       2010-06-09
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-run_read.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-run_read.t $
#
use strict;
use warnings;
use Test::More tests => 5;
use t::util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };
our $READ   = 'npg::model::run_read';

use_ok($READ);

my $util = t::util->new({
			 fixtures  => 1,
			});

{
  my $rr = $READ->new({
		       util => $util,
		      });
  isa_ok($rr, $READ, 'isa ok');
}

{
  my $rr = $READ->new({
		       util         => $util,
		       id_run       => 1,
		       order        => 1,
		       intervention => 0,
		      });
  ok($rr->create(), 'create');
  isa_ok($rr->run(), 'npg::model::run', 'run object');
  is($rr->run->id_run, 1, 'correct id_run');
}

1;
__END__

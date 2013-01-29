#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       12 January 2009
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# Id:            $Id: 10-npg_tracking-util-messages.t 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-npg_tracking-util-messages.t $
#


use strict;
use warnings;
use Test::More tests => 6;
use Test::Exception;
use Carp;

use_ok('npg_tracking::util::messages');

{
  my $list = npg_tracking::util::messages->new();
  isa_ok($list, 'npg_tracking::util::messages', 'is test');
}

{
  my $l = npg_tracking::util::messages->new();
  my $message1 = q[first_message];
  lives_ok { $l->push($message1) } 'push to an empty list';
  my $message2 = q[second_message];
  lives_ok { $l->push($message2) } 'push to a non-empty list';
  is($l->count, 2, 'message count is 2');
  is(join(q[;], $l->messages()), (join q[;], $message1, $message2), 'all mesages retrieved');
}

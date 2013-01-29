#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-11-26 09:53:48 +0000 (Mon, 26 Nov 2012) $
# Id:            $Id: 10-util.t 16269 2012-11-26 09:53:48Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-util.t $
#
use strict;
use warnings;
use Test::More tests => 4;
use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 16269 $ =~ /(\d+)/mx; $r; };

BEGIN { $ENV{'DOCUMENT_ROOT'} = './htdocs'; }

local $ENV{dev}='test';

use_ok('npg::util');
my $util = npg::util->new();
isa_ok($util, q(npg::util));
my $cfg = $util->config();
isa_ok($cfg, q(Config::IniFiles));

is($util->decription_key, 'abcd', 'test decription key');

1;

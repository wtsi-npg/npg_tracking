#########
# Author:        rmp
# Maintainer:    $Author: gq1 $
# Created:       2007-10
# Last Modified: $Date: 2010-05-04 15:28:42 +0100 (Tue, 04 May 2010) $
# Id:            $Id: 00-pod.t 9207 2010-05-04 14:28:42Z gq1 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/00-pod.t $
#
use strict;
use warnings;
use Test::More;

use Readonly; Readonly::Scalar our $VERSION => do { my @r = (q$LastChangedRevision: 9207 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

eval "use Test::Pod 1.00"; ## no critic
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok();

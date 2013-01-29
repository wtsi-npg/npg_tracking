#########
# Author:        mg8
# Maintainer:    $Author: js10 $
# Created:       15 March 2012
# Last Modified: $Date: 2012-03-20 12:02:08 +0000 (Tue, 20 Mar 2012) $
# Id:            $Id: 10-authentication-sanger_ldap.t 15357 2012-03-20 12:02:08Z js10 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-authentication-sanger_ldap.t $
#

use strict;
use warnings;

use Test::More tests => 3;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 15357 $ =~ /(\d+)/mx; $r; };

my @imports = qw/person_info/;
use_ok('npg::authentication::sanger_ldap', @imports);
can_ok('npg::authentication::sanger_ldap', @imports);

is_deeply(person_info(), {name => q[], team => q[],}, 'no user name given - empty values returned');

1;
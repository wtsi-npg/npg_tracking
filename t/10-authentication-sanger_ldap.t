#########
# Author:        mg8
# Created:       15 March 2012
#

use strict;
use warnings;
use Test::More tests => 3;

my @imports = qw/person_info/;
use_ok('npg::authentication::sanger_ldap', @imports);
can_ok('npg::authentication::sanger_ldap', @imports);

is_deeply(person_info(), {name => q[], team => q[],}, 'no user name given - empty values returned');

1;
#########
# Author:        rmp
# Last Modified: $Date: 2011-02-16 14:20:10 +0000 (Wed, 16 Feb 2011) $ $Author: mg8 $
# Id:            $Id: 00-critic.t 12618 2011-02-16 14:20:10Z mg8 $
# Source:        $Source: /cvsroot/Bio-DasLite/Bio-DasLite/t/00-critic.t,v $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/00-critic.t $
#
package critic;
use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);

use Readonly; Readonly::Scalar our $VERSION => do { my @r = (q$LastChangedRevision: 12618 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

if (!$ENV{TEST_AUTHOR}) {
  my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
  plan( skip_all => $msg );
}

eval {
  require Test::Perl::Critic;
};

if($EVAL_ERROR) {
  plan skip_all => 'Test::Perl::Critic not installed';

} else {
  Test::Perl::Critic->import(
			     -severity => 1,
			     -exclude => ['tidy',
                                          'ValuesAndExpressions::ProhibitImplicitNewlines',
                                          'Documentation::PodSpelling',
                                          'RegularExpressions::ProhibitEscapedMetacharacters',
                                          'RegularExpressions::ProhibitEnumeratedClasses'
                                         ],
                 -profile => 't/perlcriticrc',
			    );
  all_critic_ok(qw(lib/npg lib/st)); #skip lib/npg_tracking until we can play with DBIC::SL nicely. What about scripts and bin?
}

1;

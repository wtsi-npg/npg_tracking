#########
# Author:        rmp
# Last Modified: $Date: 2011-02-16 14:20:10 +0000 (Wed, 16 Feb 2011) $ $Author: mg8 $
# Id:            $Id: 00-critic.t 12618 2011-02-16 14:20:10Z mg8 $
# Source:        $Source: /cvsroot/Bio-DasLite/Bio-DasLite/t/00-critic.t,v $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/00-critic.t $
#
use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);

if (!$ENV{TEST_AUTHOR}) {
  my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
  plan( skip_all => $msg );
}

eval { require Test::Perl::Critic;
       require Perl::Critic::Utils;
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
                              'RegularExpressions::ProhibitEnumeratedClasses',
                              'Documentation::RequirePodAtEnd',
                              'Modules::RequireVersionVar',
                              'Miscellanea::RequireRcsKeywords',
                              'ValuesAndExpressions::RequireConstantVersion'
                             ],
                 -verbose => "%m at %f line %l, policy %p\n",
                 -profile => 't/perlcriticrc',
          );
 
 my @files = grep {$_ !~ /npg_tracking\/Schema/ && $_ !~ /Monitor/}
             Perl::Critic::Utils::all_perl_files(-e 'blib' ? 'blib/lib' : 'lib');
 foreach my $file (sort @files) {
   critic_ok($file);
 }
 done_testing( scalar @files );
}

1;

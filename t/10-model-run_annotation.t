#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2008-04-28
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 10-model-run_annotation.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-run_annotation.t $
#

use strict;
use warnings;
use Test::More tests => 6;
use t::util;
use CGI;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::model::run_annotation');

my $util = t::util->new({
 fixtures => 1,
});

{
  my $ra = npg::model::run_annotation->new({
    util => $util,
  });
  isa_ok($ra, 'npg::model::run_annotation');
}

{
  my $ra = npg::model::run_annotation->new({
   util   => $util,
   id_run => 16,
  });
  my $annotation = $ra->annotation();

  isa_ok($annotation, 'npg::model::annotation');

  $annotation->comment('a comment');
  $annotation->id_user($util->requestor->id_user());

  ok($ra->create());

  my $ra2 = npg::model::run_annotation->new({
   util              => $util,
   id_run_annotation => $ra->id_run_annotation(),
  });
  isnt($ra2->annotation->date(), '0000-00-00 00:00:00');
}

{
  my $cgi = CGI->new();

  $cgi->param( 'multiple_runs', 1 );
  $cgi->param( 'include_instruments', 1 );
  $cgi->param( 'run_ids', 1,2,3,9949,9950 );

  $util->cgi( $cgi );
  my $ra = npg::model::run_annotation->new({
    util   => $util,
  });

  my $annotation = $ra->annotation();
  $annotation->comment('a comment');
  $annotation->id_user($util->requestor->id_user());

  ok($ra->create());


}
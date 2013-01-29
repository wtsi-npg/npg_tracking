#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2008-02-19
# Last Modified: $Date: 2012-01-17 13:57:20 +0000 (Tue, 17 Jan 2012) $
# Id:            $Id: 20-view-run-refactored_methods.t 14928 2012-01-17 13:57:20Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-run-refactored_methods.t $
#
use strict;
use warnings;
use Test::More tests => 8;
use t::util;
use HTML::PullParser;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$LastChangedRevision: 14928 $ =~ /(\d+)/mx; $r; };

use_ok('npg::view::run');

my $mock    = {
    q(SELECT id_user FROM user WHERE username = ?:,public) => [[1]],
    q(SELECT id_usergroup FROM usergroup WHERE groupname = ?:,public) => [[]],
    q(SELECT ug.id_usergroup, ug.groupname, ug.is_public, ug.description, uug.id_user_usergroup FROM usergroup ug, user2usergroup uug WHERE uug.id_user = ? AND ug.id_usergroup = uug.id_usergroup:1) => [{}],
  };

my $cgi = CGI->new();
my $util    = t::util->new({
			    mock => $mock,
			    cgi  => $cgi,
			   });
{
  my $view = npg::view::run->new({
				  util  => $util,
				  model => npg::model::run->new({
								 util   => $util,
								 id_run => q(),
								}),
				 });
  isa_ok($view, 'npg::view::run', 'isa npg::view::run');
  is($view->convert_is_good(0), 'Bad', '$view->convert_is_good(0) is Bad');
  is($view->convert_is_good(1), 'Good', '$view->convert_is_good(1) is Good');
  is($view->convert_is_good(2), 'Unknown', '$view->convert_is_good(2) is Unknown');
  is($view->convert_is_good(3), 'Bad', '$view->convert_is_good(3) is Bad');

  is($view->selected_days(), 14, '$view->selected_days() gives default 14 days if not set as cgi param');
  $cgi = $view->util->cgi();
  $cgi->param('days', 7);
  is($view->selected_days(), 7, '$view->selected_days() gives selected days if set as cgi param');
}

1;

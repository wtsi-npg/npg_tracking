#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2011-11-21 13:14:56 +0000 (Mon, 21 Nov 2011) $
# Id:            $Id: 30-api-util.t 14647 2011-11-21 13:14:56Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/30-api-util.t $
#
use strict;
use warnings;
use Test::More tests => 14;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 14647 $ =~ /(\d+)/mx; $r; };

use_ok('npg::api::util');

{
  my $util = npg::api::util->new({
				  base_uri  => '/foo',
				  useragent => 'foo',
				  parser    => 'foo',
				 });
  is($util->base_uri(),  '/foo', 'base url set explicitly');
  is($util->useragent(), 'foo');
  is($util->parser(),    'foo');
}

{
  my $util = npg::api::util->new();
  isa_ok($util->useragent(), 'LWP::UserAgent');
  isa_ok($util->parser(),    'XML::LibXML');
}

{
   my $util = npg::api::util->new();
   is ($util->base_uri(), 'http://npg.sanger.ac.uk/perl/npg' , 'live url if the dev env variable not set');
}

{
   local $ENV{dev} = q[dev];
   my $util = npg::api::util->new();
   is ($util->base_uri(), 'http://npg.dev.sanger.ac.uk/perl/npg' , 'dev url if the dev env variable is set to dev');
}

{
   local $ENV{dev} = q[test];
   my $util = npg::api::util->new();
   is ($util->base_uri(), 'http://npg.sanger.ac.uk/perl/npg' , 'live url if the dev env. variable is set to test');
}

{
  my $request = npg::api::util->new()->request();
  isa_ok($request,   'npg::api::request');
  is ($request->save2cache, 0 , 'false save2cache flag');
  is (npg::api::util->new({save2cache => 1, })->request()->save2cache, 1 , 'true save2cache flag');
  local $ENV{SAVE2NPG_WEBSERVICE_CACHE} = 0;
  is (npg::api::util->new()->request()->save2cache, 0 , 'false save2cache flag');
  local $ENV{SAVE2NPG_WEBSERVICE_CACHE} = 1;
  is (npg::api::util->new()->request()->save2cache, 1 , 'true save2cache flag');
}

1;

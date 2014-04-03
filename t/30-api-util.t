use strict;
use warnings;
use Test::More tests => 10;

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
  isa_ok($util->request(),   'npg::api::request');
}

{
   my $util = npg::api::util->new();
   is ($util->base_uri(), 'http://sfweb.internal.sanger.ac.uk:9000/perl/npg' , 'live url if the dev env variable not set');
}

{
   local $ENV{dev} = q[dev];
   my $util = npg::api::util->new();
   is ($util->base_uri(), 'http://npg.dev.sanger.ac.uk/perl/npg' , 'dev url if the dev env variable is set to dev');
}

{
   local $ENV{dev} = q[test];
   my $util = npg::api::util->new();
   is ($util->base_uri(), 'http://sfweb.internal.sanger.ac.uk:9000/perl/npg' , 'live url if the dev env. variable is set to test');
}

1;

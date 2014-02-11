#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-11-26 09:53:48 +0000 (Mon, 26 Nov 2012) $
# Id:            $Id: 20-view-instrument.t 16269 2012-11-26 09:53:48Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/20-view-instrument.t $
#
use strict;
use warnings;
use Test::More tests => 20;
use Test::Exception::LessClever;
use t::util;
use t::request;
use GD qw(:DEFAULT :cmp);
use File::Spec;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16269 $ =~ /(\d+)/mx; $r; };

use_ok('npg::view::instrument');

my $util = t::util->new({
                fixtures => 1,
                fixtures_path => q[t/data/fixtures],
      });

my $image_dir = File::Spec->catfile('t', 'data', 'rendered', 'images');

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/instrument.html'),
    'list instruments default');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument;list_graphical',
           username       => 'public',
           util           => $util,
          });

  ok($util->test_rendered($str, 't/data/rendered/instrument.html'),
    'list instruments graphical');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument.xml',
           username       => 'public',
           util           => $util,
                });
  ok($util->test_rendered($str, 't/data/rendered/instrument.xml'),
    'list instruments xml');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/',
           username       => 'public',
           util           => $util,
           cgi_params     => {
            id_instrument_format => 21,
                 },
          });

  ok($util->test_rendered($str, 't/data/rendered/instrument.html'),
    'list instruments for format 21');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/11',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/instrument/11.html'), 'read instrument');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/13.xml',
           username       => 'public',
           util           => $util,
           cgi_params     => {
            id_run_status_dict => 71,
                 },
          });
  ok($util->test_rendered($str, 't/data/rendered/instrument/13.xml'), 'read_xml renders ok');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/instrument/group;update_statuses',
           username       => 'public',
           util           => $util,
          });

  like($str, qr/not\ authorised/,
    'public not authorised for group status update');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'POST',
           PATH_INFO      => '/instrument/group;update_statuses',
           username       => 'joe_engineer',
           util           => $util,
          });

  unlike($str, qr/not\ authorised/, 'engineer authorised for group status update');
  like($str, qr/no\ comment\ given/mix, 'no-comment warning');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument;list_uptime_png',
           username       => 'public',
           util           => $util,
          });

  like($str, qr{image/png.*PNG}smx, 'instrument graphical uptime is a png');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument;list_utilisation_png',
           username       => 'public',
           util           => $util,
          });

  like($str, qr{image/png.*PNG}smx, 'instrument graphical utilisation');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/utilisation.png',
           username       => 'public',
           util           => $util,
          });

  like($str, qr{image/png.*PNG}smx, 'instrument graphical utilisation (new-style)');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument;list_utilisation_png',
           username       => 'public',
           util           => $util,
           cgi_params     => {
            type => 'hour',
                 },
          });

  like($str, qr{image/png.*PNG}smx, 'instrument graphical utilisation by hour');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/12.png',
           username       => 'public',
           util           => $util,
          });

  like($str, qr{image/png.*PNG}smx, 'instrument graphical read');
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/key.png',
           username       => 'public',
           util           => $util,
          });

  like($str, qr{image/png.*PNG}smx, 'instrument key graphical read');
  my $expected = GD::Image->new( File::Spec->catfile($image_dir, 'key.png'));
  my @lines = split "\n", $str;
  shift @lines; shift @lines; shift @lines;
  my $rendered = GD::Image->new(join "\n", @lines);
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'legend image'); 
}


{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/64.png',
           username       => 'public',
           util           => $util,
          });

  like($str, qr{image/png.*PNG}smx, 'HiSeq instrument graphical read');
  my $expected = GD::Image->new( File::Spec->catfile($image_dir, 'HS3.png'));
  my @lines = split "\n", $str;
  shift @lines; shift @lines; shift @lines;
  my $rendered = GD::Image->new(join "\n", @lines);
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'idle HiSeq image'); 
}

{
  my $str = t::request->new({
    PATH_INFO      => '/instrument/7',
    REQUEST_METHOD => 'GET',
    username       => 'joe_admin',
    util           => $util,
  });

  ok($util->test_rendered($str, 't/data/rendered/instrument_status;add-cis2.html'), 'render of add ok for current instrument status of down');
}

1;
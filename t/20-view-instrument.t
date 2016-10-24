use strict;
use warnings;
use Test::More tests => 20;
use Test::Exception;
use t::util;
use t::request;
use GD qw(:DEFAULT :cmp);
use File::Spec;

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
  my $png = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/IL29.png',
           username       => 'public',
           util           => $util,
          });

  t::util::is_colour($png, $npg::view::instrument::COLOUR_YELLOW, 'no runs = status yellow');
}

$util->requestor('joe_loader');
my $inst = npg::model::instrument->new({
          util => $util,
          name => 'IL8',
               });
{
  #########
  # set up a cancelled run
  #
  my $run = npg::model::run->new({
          util                 => $util,
          id_instrument        => $inst->id_instrument(),
          batch_id             => 2690,
          expected_cycle_count => 0,
          actual_cycle_count   => 0,
          priority             => 0,
          id_user              => $util->requestor->id_user(),
          is_paired            => 1,
          team                 => 'A',
         });
  $run->create();

  my $rsd = npg::model::run_status_dict->new({
                util        => $util,
                description => 'run cancelled',
               });

  my $status_update = t::request->new({
               REQUEST_METHOD => 'POST',
               PATH_INFO      => '/run_status/',
               username       => 'joe_loader',
               util           => $util,
               cgi_params     => {
               id_run             => $run->id_run(),
               id_run_status_dict => $rsd->id_run_status_dict(),
               },
              });

  my $png = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/IL8.png',
           username       => 'public',
           util           => $util,
          });

  t::util::is_colour($png, $npg::view::instrument::COLOUR_YELLOW, 'run cancelled + unwashed = status yellow');
}

{
  #########
  # wash the instrument
  #
  my $isd = npg::model::instrument_status_dict->new({
                 util        => $util,
                 description => 'wash in progress',
                });
  my $status_update = t::request->new({
               REQUEST_METHOD => 'POST',
               PATH_INFO      => '/instrument_status/',
               username       => 'joe_admin',
               util           => $util,
               cgi_params     => {
                id_instrument             => $inst->id_instrument(),
                id_instrument_status_dict => $isd->id_instrument_status_dict(),
               },
              });

  my $png = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/IL8.png',
           username       => 'public',
           util           => $util,
          });

  t::util::is_colour($png, $npg::view::instrument::COLOUR_YELLOW, 'run cancelled + startedwash = status yellow');


  $isd = npg::model::instrument_status_dict->new({
                 util        => $util,
                 description => 'wash performed',
                });
  $status_update = t::request->new({
               REQUEST_METHOD => 'POST',
               PATH_INFO      => '/instrument_status/',
               username       => 'joe_admin',
               util           => $util,
               cgi_params     => {
                id_instrument             => $inst->id_instrument(),
                id_instrument_status_dict => $isd->id_instrument_status_dict(),
               },
              });

  $png = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/IL8.png',
           username       => 'public',
           util           => $util,
          });

  t::util::is_colour( $png, $npg::view::instrument::COLOUR_BLUE,
                           'run cancelled + washed = status blue' );
}

{
  $inst = npg::model::instrument->new({
            util => $util,
            name => 'IL29',
           });
  my $run = npg::model::run->new({
          util                 => $util,
          id_instrument        => $inst->id_instrument(),
          batch_id             => 2690,
          expected_cycle_count => 0,
          actual_cycle_count   => 0,
          priority             => 0,
          id_user              => $util->requestor->id_user(),
                                  team                 => 'B',
         });
  $run->create();

  my $png = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/IL29.png',
           username       => 'public',
           util           => $util,
          });

  t::util::is_colour($png, $npg::view::instrument::COLOUR_GREEN, 'run pending = status green');
}

1;

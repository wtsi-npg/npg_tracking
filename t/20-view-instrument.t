use strict;
use warnings;
use Test::More tests => 22;
use Test::Exception;
use GD qw(:DEFAULT :cmp);
use File::Spec;
use DateTime();

use t::util;
use t::request;

use_ok('npg::view::instrument');

my $util = t::util->new({
                fixtures => 1,
                fixtures_path => q[t/data/fixtures],
      });
my $image_dir = File::Spec->catfile('t', 'data', 'rendered', 'images');

is (join(q[ ], npg::view::instrument->lab_names()), 'Ogilvie Sulston',
  'sorted lab names list');

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/instrument.html'),
    'list instruments default');

  $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument;list_graphical',
           username       => 'public',
           util           => $util,
          });
  ok($util->test_rendered($str, 't/data/rendered/instrument.html'),
    'list instruments graphical');

  $str = t::request->new({
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
  my $now = DateTime->now() . q[];
  my $sql = "update instrument_status set date='$now'";
  if (!$util->dbh->do($sql)) {
    die 'Failed to update date';
  }
  $util->dbh->commit();

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
  $str =~s/\A(?:^\S[^\n]*\n)+\n(\x89PNG)/$1/smx; #trim http header off
  my $rendered = GD::Image->new($str);
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
  $str =~s/\A(?:^\S[^\n]*\n)+\n(\x89PNG)/$1/smx; #trim http header off
  my $rendered = GD::Image->new($str);
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'idle HiSeq image in Sulston'); 
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/36.png',
           username       => 'public',
           util           => $util,
          });

  like($str, qr{image/png.*PNG}smx, 'HiSeq instrument graphical read');
  my $expected = GD::Image->new( File::Spec->catfile($image_dir, 'HS2.png'));
  $str =~s/\A(?:^\S[^\n]*\n)+\n(\x89PNG)/$1/smx; #trim http header off
  my $rendered = GD::Image->new($str);
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'idle HiSeq image in no lab'); 
}

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/90.png',
           username       => 'public',
           util           => $util,
          });
  
  like($str, qr{image/png.*PNG}smx, 'MiSeq instrument graphical read');
  my $expected = GD::Image->new( File::Spec->catfile($image_dir, 'MS1.png'));
  $str =~s/\A(?:^\S[^\n]*\n)+\n(\x89PNG)/$1/smx; #trim http header off
  my $rendered = GD::Image->new($str);
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE),
    'idle MiSeq R&D image in Ogilvie'); 
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

{
  my $str = t::request->new({
           REQUEST_METHOD => 'GET',
           PATH_INFO      => '/instrument/AV1.png',
           username       => 'public',
           util           => $util,
          });

  like($str, qr{image/png.*PNG}smx, 'Aviti instrument graphical read');
  my $expected = GD::Image->new( File::Spec->catfile($image_dir, 'AVITI24.png'));
  $str =~s/\A(?:^\S[^\n]*\n)+\n(\x89PNG)/$1/smx; #trim http header off 
  my $rendered = GD::Image->new($str);
  ok (!($rendered->compare($expected) & GD_CMP_IMAGE), 'idle AVITI image');
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
          batch_id             => 12690,
          expected_cycle_count => 0,
          actual_cycle_count   => 0,
          priority             => 0,
          id_user              => $util->requestor->id_user(),
          team                 => 'A',
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

use strict;
use warnings;
use Test::More tests => 14;
use Template;

use npg::model::user;
use npg::model::usergroup;
use npg::model::user2usergroup;
use t::util;

my $duplicate_run_reg = qr/<a.*href=\"\/cgi-perl\/npg\/run\/;add\?id_run=4\">Duplicate\ Run<\/a>/;

my $cfg  = {
      'INCLUDE_PATH' => 'data/templates',
      'EVAL_PERL'    => 1,
     };
my $tt   = Template->new($cfg);
my $util = t::util->new({fixtures=>1});
{
  my $got    = q();
  $util->requestor('public');
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
              'model'       => { location_is_instrument => 0, },
       }, \$got);
  ok(!$tt->error(), 'no-input template processed without errors');
  ok($util->test_rendered($got, 't/data/rendered/actions_public.html'), 'actions_public render ok');
  unlike($got, qr/Rfid\ tag/, 'not on instrument, rdf box is not available');
}

{
  my $got    = q();
  $util->requestor('public');
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
              'model'       => { location_is_instrument => 1, },
       }, \$got);
  like($got, qr/Rfid\ tag/, 'on instrument, rdf box is available');
}

{
  my $got    = q();
  $util->requestor('joe_loader');
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
       }, \$got);
  ok($util->test_rendered($got, 't/data/rendered/actions_loader.html'), 'actions_loader render ok');
}
{
  my $got    = q();
  $util->requestor('joe_engineer');
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
       }, \$got);
  ok($util->test_rendered($got, 't/data/rendered/actions_engineer.html'), 'actions_engineer render ok');
}

{
  my $got    = q();
  $util->requestor('joe_engineer');
  ok($util->requestor()->is_member_of('engineers'), 'requestor is an engineer');
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
              'entity'      => 'run',
              'model'       => { primary_key => 'id_run', id_run => 4, current_run_status => {description => 'run complete'},},
              'view'        => { method_name => 'read', },
       }, \$got);
  unlike($got, $duplicate_run_reg, 'engineer@runpage: "Duplicate Run" button not displayed for a non-cancelled run');

  $got    = q();
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
              'entity'      => 'run',
              'model'       => { primary_key => 'id_run', id_run => 4, current_run_status => {description => 'run cancelled'},},
              'view'        => { method_name => 'read', },
       }, \$got);
  like($got, $duplicate_run_reg, 'engineer@runpage: "Duplicate Run" button is displayed for a cancelled run');

  $util->requestor('joe_loader');
  $got    = q();
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
              'entity'      => 'run',
              'model'       => { primary_key => 'id_run', id_run => 4, current_run_status => {description =>'run in progress'},},
              'view'        => { method_name => 'read', },
       }, \$got);
  unlike($got, $duplicate_run_reg, 'loader@runpage: "Duplicate Run" button not displayed for a non-cancelled run');

  $got    = q();
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
              'entity'      => 'run',
              'model'       => { primary_key => 'id_run', id_run => 4, current_run_status => {description =>'run cancelled'},},
              'view'        => { method_name => 'read', },
       }, \$got);
  like($got, $duplicate_run_reg, 'loader@runpage: "Duplicate Run" button is displayed for a cancelled run');
}

{
  my $got    = q();
  $util->requestor('joe_admin');
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
       }, \$got);
  ok($util->test_rendered($got, 't/data/rendered/actions_admin.html'), 'actions_admin render ok');
}

{
  my $got    = q();
  $util->requestor('joe_analyst');
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
       }, \$got);
  ok($util->test_rendered($got, 't/data/rendered/actions_analyst.html'), 'actions_analyst render ok');
}

{
  my $got    = q();
  $util->requestor('joe_annotator');
  $tt->process('actions.tt2',
       {
        'requestor'   => $util->requestor(),
        'SCRIPT_NAME' => '/cgi-perl/npg',
       }, \$got);
  ok($util->test_rendered($got, 't/data/rendered/actions_annotator.html'), 'actions_annotator render ok');
}

1;

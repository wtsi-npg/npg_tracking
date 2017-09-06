use strict;
use warnings;
use Test::More tests => 7;
use Test::Exception;

use_ok ('npg_tracking::glossary::composition::factory::rpt_list');

{
  throws_ok { npg_tracking::glossary::composition::factory::rpt_list->new()}
    qr/Attribute \(rpt_list\) is required /,
    'value for rpt_list argument is required';
  throws_ok { npg_tracking::glossary::composition::factory::rpt_list->new(rpt_list => undef)}
    qr/Validation failed for 'Str' with value undef/,
    'rpt_list argument cannot be undefined';

  my $factory;
  lives_ok { $factory = npg_tracking::glossary::composition::factory::rpt_list->new(rpt_list => '')}
    'rpt_list defined - object created';
  throws_ok { $factory->create_component() }
    qr/rpt string argument is missing/,
    'create_component() method needs input'; 

  $factory = npg_tracking::glossary::composition::factory::rpt_list->new(
    rpt_list => '3:2;5:2;6:2:3;6:3:3'
  );
  my $composition = $factory->create_composition;
  isa_ok ($composition, 'npg_tracking::glossary::composition');
  is ($composition->freeze(),
    '{"components":[{"id_run":3,"position":2},{"id_run":5,"position":2},' .
    '{"id_run":6,"position":2,"tag_index":3},{"id_run":6,"position":3,"tag_index":3}]}',
    'composition json representation is correct');
}

1;

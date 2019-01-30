use strict;
use warnings;
use Test::More tests => 22;
use Test::Exception;
use t::dbic_util;

use_ok('npg_tracking::Schema::Result::Tag');

my $rs = t::dbic_util->new->test_schema()->resultset('Tag');

my $row = $rs->find({tag => 'fc_slotA'});
ok ($row, 'row retrieved');
isa_ok ($row, 'npg_tracking::Schema::Result::Tag');
is ($row->tag, 'fc_slotA', 'correct tag');

$row = $rs->find({tag => 'rta'});
ok ($row, 'row retrieved');
is ($row->incompatible_tag, undef, 'incompatible tag is not defined for rta');

my %tags = (
  'paired_read'        => 'single_read',
  'bad'                => 'good',
  'fc_slotA'           => 'fc_slotB',
  'workflow_NovaSeqXp' => 'workflow_NovaSeqStandard',
);

while (my ($tag, $itag) = each %tags)  {
  my $r = $rs->find({tag => $tag});
  ok ($r, "found record for $tag");
  is ($r->incompatible_tag, $itag, "correct incompatible tag for $tag");
  $r = $rs->find({tag => $itag});
  ok ($r, "found record for $itag");
  is ($r->incompatible_tag, $tag, "correct incompatible tag for $itag");
}

$rs->find({tag => 'fc_slotA'})->update({tag => 'fc_slotC'});

1;

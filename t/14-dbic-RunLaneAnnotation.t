use strict;
use warnings;
use Test::More tests => 3;
use Test::Exception;
use DateTime;
use t::dbic_util;

use_ok('npg_tracking::Schema::Result::RunLaneAnnotation');

my $schema = t::dbic_util->new->test_schema();

{
  my $date = DateTime->now();
  my $date_as_string = sprintf '%s', $date;
  $date_as_string =~ s/T/ /;
  my $comment = 'My lane annotation is OK';

  my $a_row = $schema->resultset('Annotation')->create({
    id_user => 8,
    date    => $date,
    comment => $comment
  });

  my $ra_row1 = $schema->resultset('RunLaneAnnotation')->create({
    id_run_lane    => 1,
    id_annotation  => $a_row->id_annotation(),
  });

  is ($ra_row1->summary(), 'Run 1 lane 7 annotated by joe_events',
    'correct summary');

  is ($ra_row1->information(),
    "Run 1 lane 7 annotated by joe_events on ${date_as_string} - $comment",
    'correct information');
}

1;

use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use DateTime;
use t::dbic_util;

use_ok('npg_tracking::Schema::Result::RunAnnotation');

my $schema = t::dbic_util->new->test_schema();

{
  my $date = DateTime->now();
  my $date_as_string = sprintf '%s', $date;
  $date_as_string =~ s/T/ /;
  my $comment = 'my run annotation is OK';

  my $a_row = $schema->resultset('Annotation')->create({
    id_user => 8,
    date    => $date,
    comment => $comment
  });

  is($a_row->date_as_string(), $date_as_string,
    'correct stringified date for the annotation');
  is($a_row->username(), 'joe_events', 'correct username for the annotation');

  my $ra_row1 = $schema->resultset('RunAnnotation')->create({
    id_run         => 1,
    id_annotation  => $a_row->id_annotation(),
    run_current_ok => 1,
    current_cycle  => 33,
  });

  is ($ra_row1->summary(), 'Run 1 annotated by joe_events',
    'correct summary');

  is ($ra_row1->information(),
    "Run 1 annotated by joe_events on ${date_as_string} - $comment",
    'correct information');
}

1;

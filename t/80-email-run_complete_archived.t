use strict;
use warnings;
use English qw{-no_match_vars};
use Test::More tests => 16;
use Test::Exception;
use t::dbic_util;
use t::util;
use DateTime;
use Perl6::Slurp;

$ENV{DEV} = q{test};

BEGIN {
  use_ok(q{npg::email::run::complete_archived});
}

my $schema = t::dbic_util->new->test_schema();
my $util = t::util->new();
$util->catch_email($util);

my $hash_projects_followers = {
    human => {
      followers => [qw{human@sanger.ac.uk monkey}],
      lanes => [
        {
          position => 1,
          library => q{1k},
        },
        {
          position => 2,
          library => q{1k},
        },
        {
          position => 3,
          library => q{1k},
        },
      ],
    },
    platypus => {
      followers => [qw{platypus}],
      lanes => [
        {
          position => 5,
          library => q{Duck},
        },
        {
          position => 6,
          library => q{Billed},
        },
      ],
    },
    tasmanian => {
      followers => [qw{taz}],
      lanes => [
        {
          position => 7,
          library => q{devil},
        },
        {
          position => 8,
          library => q{tiger},
        },
      ],
    },
};

# to ensure that we can test the email outputs, override the study_lane_followers
# method to just deal with returning the correct hash for said emails
*npg::email::run::complete_archived::study_lane_followers = sub { return $hash_projects_followers; };
{
  my $object;
  lives_ok { $object = npg::email::run::complete_archived->new({
                      schema_connection => $schema,
  }); } q{object created ok};


  my $study_lane_followers;
  lives_ok {
    $study_lane_followers = $object->study_lane_followers();
  } q{study_lane_followers ok};

  is($study_lane_followers, $hash_projects_followers, q{study_lane_followers is returning the test hash});

  isa_ok($object, q{npg::email::run::complete_archived}, q{$object});

  my $connection = $object->schema_connection();
  isa_ok($connection, q{npg_tracking::Schema}, q{$connection});
  my $run_result = $object->get_run(95);
  isa_ok($run_result, q{npg_tracking::Schema::Result::Run}, q{correct run object returned from get_run(95)});
  is($run_result->batch_id(), 62, q{correct batch_id for run});

  isa_ok($object->email_body_store(), q{ARRAY}, q{email_body_store is an arrayref});

  lives_ok { $object->run(); } q{no croak running $object->run()};

  my $email1_body = << 'EMAIL1';
has a status of run complete in NPG tracking.
(The sequencing instrument has finished imaging. It will complete basecalling soon.
Alignments and QC metrics will then proceed automatically followed by a manual
QC process and archival to iRODS).

Study

human

has the following lanes on this run:

Lane - 1 : Library - 1k
Lane - 2 : Library - 1k
Lane - 3 : Library - 1k

You will be notified when this run reaches run archived (this will vary from one
day for a small high priority run to a fortnight for a large normal priority run).
In the mean time, you can check the status of the run through NPG:
http://npg.sanger.ac.uk/perl/npg/run/
EMAIL1
  chomp $email1_body;
  my $email_hash = $util->parse_email($util->{emails}->[0]);
  like($email_hash->{subject}, qr{Run[ ]\d+[ ]-[ ]run[ ]complete[ ]-[ ]human}, q{email1 subject correct});
  is($email_hash->{to}, q{human@sanger.ac.uk, monkey@sanger.ac.uk}. qq{\n}, q{email1 to correct});
  is($email_hash->{from}, q{srpipe@sanger.ac.uk}. qq{\n}, q{email1 from correct});
  like($email_hash->{annotation}, qr{\Q$email1_body\E}, q{email1 body correct});

  $email_hash = $util->parse_email($util->{emails}->[1]);
  my $email2_body = << 'EMAIL2';
has a status of run complete in NPG tracking.
(The sequencing instrument has finished imaging. It will complete basecalling soon.
Alignments and QC metrics will then proceed automatically followed by a manual
QC process and archival to iRODS).

Study

platypus

has the following lanes on this run:

Lane - 5 : Library - Duck
Lane - 6 : Library - Billed

You will be notified when this run reaches run archived (this will vary from one
day for a small high priority run to a fortnight for a large normal priority run).
In the mean time, you can check the status of the run through NPG:
http://npg.sanger.ac.uk/perl/npg/run/
EMAIL2
  chomp $email2_body;
  is($email_hash->{to}, q{platypus@sanger.ac.uk}. qq{\n}, q{email2 to correct});
  like($email_hash->{annotation}, qr{\Q$email2_body\E}, q{email2 body correct});
}

1;

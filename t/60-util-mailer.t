use strict;
use warnings;
use Test::More tests => 25;
use Test::Exception;
use t::util;
use DateTime;

use_ok('npg::util::mailer');

my $util = t::util->new({});
$util->catch_email($util);
{
  my $mailer = npg::util::mailer->new({
    to      => q{receive@tester.org},
    from    => q{send@tester.org},
    subject => q{A test subject},
    body    => qq{This is some test stuff\n\nLots of test stuff},
  });
  isa_ok($mailer, q{npg::util::mailer}, q{$mailer});
  lives_ok { $mailer->mail(); } q{no croak mailing};
  my $mail = $util->parse_email($util->{emails}->[0], 1);
  is($mail->{to}, qq{receive\@tester.org\n}, q{to is correct});
  is($mail->{from}, qq{send\@tester.org\n}, q{from is correct});
  is($mail->{subject}, qq{A test subject\n}, q{subject is correct});
  is($mail->{body}, qq{This is some test stuff\n\nLots of test stuff}, q{body is correct});
  is($mail->{precendence}, qq{list\n}, q{precendence is correct});
  is($mail->{cc}, undef, q{cc is correct});
  is($mail->{bcc}, undef, q{bcc is correct});
  is($mail->{content_type}, qq{text/plain\n}, q{content_type is correct});
}
{
  my $mailer;
  throws_ok { $mailer = npg::util::mailer->new({
      from    => q{send@tester.org},
      subject => q{A test subject},
      body    => qq{This is some test stuff\n\nLots of test stuff},
    });
  } qr{Missing[ ]initializer[ ]label[ ]for[ ]npg::util::mailer:[ ]'to'\.}, q{croak as missing 'to' in args};
}
{
  my $mailer;
  throws_ok { $mailer = npg::util::mailer->new({
      to      => q{receive@tester.org},
      subject => q{A test subject},
      body    => qq{This is some test stuff\n\nLots of test stuff},
    });
  } qr{Missing[ ]initializer[ ]label[ ]for[ ]npg::util::mailer:[ ]'from'\.}, q{croak as missing 'from' in args};
}
{
  my $mailer;
  throws_ok { $mailer = npg::util::mailer->new({
      from    => q{send@tester.org},
      to      => q{receive@tester.org},
      body    => qq{This is some test stuff\n\nLots of test stuff},
    })} qr{Missing[ ]initializer[ ]label[ ]for[ ]npg::util::mailer:[ ]'subject'\.}, q{croak as missing 'subject' in args};
}
{
  my $mailer;
  throws_ok { $mailer = npg::util::mailer->new({
      from    => q{send@tester.org},
      to      => q{receive@tester.org},
      subject => q{A test subject},
    })} qr{Missing[ ]initializer[ ]label[ ]for[ ]npg::util::mailer:[ ]'body'\.}, q{croak as missing 'body' in args};
}
{
  my $mailer = npg::util::mailer->new({
    to      =>  q{receive@tester.org second_recepient@tester.org},
    from    =>  q{send@tester.org},
    subject =>  q{A test subject},
    body    => qq{<xml>This is some test stuff\n\nLots of test stuff</xml>},
    bcc     =>  q{one_bcc@tester.org two_bcc@tester.org},
    cc      =>  q{one_cc@tester.org two_cc@tester.org},
    precedence => q{auto},
    type => q{text/xml},
  });
  isa_ok($mailer, q{npg::util::mailer}, q{$mailer (including optional headers)});
  lives_ok { $mailer->mail(); } q{no croak mailing};
  my $mail = $util->parse_email($util->{emails}->[1], 1);
  is($mail->{to}, qq{receive\@tester.org, second_recepient\@tester.org\n}, q{to is correct});
  is($mail->{from}, qq{send\@tester.org\n}, q{from is correct});
  is($mail->{subject}, qq{A test subject\n}, q{subject is correct});
  is($mail->{body}, qq{<xml>This is some test stuff\n\nLots of test stuff</xml>}, q{body is correct});
  is($mail->{precendence}, qq{auto\n}, q{precendence is correct});
  is($mail->{cc}, qq{one_cc\@tester.org, two_cc\@tester.org\n}, q{cc is correct});
  is($mail->{bcc}, qq{one_bcc\@tester.org, two_bcc\@tester.org\n}, q{bcc is correct});
  is($mail->{content_type}, qq{text/xml\n}, q{content_type is correct});
}
1;

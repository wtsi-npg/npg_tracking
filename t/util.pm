#########
# Author:        rmp
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-12-17 14:00:36 +0000 (Mon, 17 Dec 2012) $
# Id:            $Id: util.pm 16335 2012-12-17 14:00:36Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/util.pm $
#
package t::util;

use strict;
use warnings;
use base qw(npg::util Exporter);
use t::dbh;
use Carp;
use npg::model::user;
use DateTime;
use CGI;
use English qw(-no_match_vars);
use Test::More;
use HTML::PullParser;
use YAML qw(LoadFile);
use MIME::Parser;
use MIME::Lite;
use GD;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16335 $ =~ /(\d+)/mx; $r; };

Readonly::Scalar our $DEFAULT_FIXTURES_PATH => q[t/data/fixtures];

$ENV{HTTP_HOST}     = 'test.npg.com';
$ENV{SCRIPT_NAME}   = '/cgi-bin/npg';
$ENV{dev}           = 'test';

sub dbh {
  my ($self, @args) = @_;

  if($self->{fixtures}) {
    return $self->SUPER::dbh(@args);
  }

  $self->{'dbh'} ||= t::dbh->new({'mock'=>$self->{'mock'}});
  return $self->{'dbh'};
}

sub fixtures_path {
  my ($self, $path) = @_;
  if ($path) {
    $self->{fixtures_path} = $path;
  } else {
    if (!$self->{fixtures_path}) {
      $self->{fixtures_path} = $DEFAULT_FIXTURES_PATH;
    }
  }
  return $self->{fixtures_path};
}

sub driver {
  my $self = shift;

  if($self->{fixtures}) {
    return $self->SUPER::driver();
  }

  return $self;
}

sub create {
  my ($self, @args) = @_;

  if($self->{fixtures}) {
    return $self->driver->create(@args);
  }

  return $self->dbh->do(@args);
}

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);

  if($self->{fixtures}) {
    $self->load_fixtures();
  }

  if($self->{fixtures}) {
    foreach my $i (@{npg::model::instrument->new({util=>$self})->current_instruments()}) {
      if ($i->does_sequencing) {
        if(!$i->current_instrument_status()) {
          $i->status_reset('wash required');
        }
      }
    }
  }
  $self->dbh->commit();

  return $self;
}

sub load_fixtures {
  my ($self) = shift;

  if($self->dbsection() ne 'test') {
    croak "dbsection is set to @{[$self->dbsection()]} which is not the same as 'test'. Refusing to go ahead!";
  }

  #########
  # build table definitions
  #
  if(!-e "data/schema.txt") {
    croak "Could not find data/schema.txt";
  }

  if ($self->dbh) {
    # This open handle causes a long wait for the next mysql client system call.
    # There is a lock on some tables despite the fact that all queries are finished.
    # This only started from MySQL server version 5.5.30 when the locking policy
    # has been tightten up, see http://sql.dzone.com/articles/implications-metadata-locking.
    # The lock might be internally set by the server and have nothing to do with us.
    eval { $self->dbh->disconnect; };
    $self->{'dbh'} = undef; #for good measure
  }

  $self->log('Loading data/schema.txt');
  my $cmd = q(cat data/schema.txt | mysql);
  my $local_socket = $self->dbhost() eq 'localhost' && $ENV{'MYSQL_UNIX_PORT'} ? $ENV{'MYSQL_UNIX_PORT'} : q[];
  if ($local_socket) {
    $cmd .= q( --no-defaults); #do not read ~/.my.cnf
                               #this should be the first option
  }

  $cmd .= sprintf q( -u%s %s -D%s),
                  $self->dbuser(),
                  $self->dbpass()?"-p@{[$self->dbpass()]}":q(),
                  $self->dbname();

  if ($local_socket) {
    $cmd .= qq( --socket=$local_socket);
  } else {
    $cmd .= ' -h' . $self->dbhost() . ' -P' . $self->dbport();
  }

  $self->log("Executing: $cmd");
  open my $fh, q(-|), $cmd or croak $ERRNO;
  while(<$fh>) {
    print;
  }
  close $fh or croak $ERRNO;

  my $path = $self->fixtures_path;

  #########
  # populate test data
  #
  opendir my $dh, $path or croak "Could not open $path";
  my @fixtures = sort grep { /\d+\-[a-z\d_]+\.yml$/mix } readdir $dh;
  closedir $dh;

  $self->log('Loading fixtures: '. join q[ ], @fixtures);

  my $dbh = $self->dbh();
  for my $fx (@fixtures) {
    my $yml     = LoadFile($path . q[/] . $fx);
    my ($table) = $fx =~ /\-([a-z\d_]+)/mix;
    my $row1    = $yml->[0];
    my @fields  = keys %{$row1};
    my $query   = qq(INSERT INTO $table (@{[join q(, ), @fields]}) VALUES (@{[join q(,), map { q(?) } @fields]}));

    for my $row (@{$yml}) {
      $dbh->do($query, {}, map { $row->{$_} } @fields);
    }
    $dbh->commit();
  }

  return;
}

sub requestor {
  my ($self, $req) = @_;

  if(ref $req && $req->isa('npg::model::user')) {
    $self->{requestor} = $req;
  } elsif($req) {
    $self->{requestor} = npg::model::user->new({
						util     => $self,
						username => $req,
					       });
  }

  $self->{requestor} ||= npg::model::user->new({
						util     => $self,
						username => 'public',
					       });
  return $self->{requestor};
}

sub date_today {
  my ($self,$database) = @_;
  my $dt = DateTime->now();
  $dt =~ s/T/ /gxms;
  return $dt;
}

sub cgi {
  my ($self, $cgi) = @_;

  if($cgi) {
    $self->{cgi} = $cgi;
  }

  $self->{cgi} ||= CGI->new();
  return $self->{cgi};
}

sub rendered {
  my ($self, $tt_name) = @_;
  local $RS = undef;
  open my $fh, q(<), $tt_name or croak "Error opening $tt_name: $ERRNO";
  my $content = <$fh>;
  close $fh or croak "Error closing $tt_name: $ERRNO";
  return $content;
}

sub test_rendered {
  my ($self, $chunk1, $chunk2) = @_;
  my $fn = $chunk2 || q[];

  if(!$chunk1) {
    diag q(No chunk1 in test_rendered);
  }

  if(!$chunk2) {
    diag q(No chunk2 in test_rendered);
  }

  if($chunk2 =~ m{^t/}mx) {
    $chunk2 = $self->rendered($chunk2);

    if(!length $chunk2) {
      diag("Zero-sized $chunk2. Expected something like\n$chunk1");
    }
  }

  my $chunk1els = $self->parse_html_to_get_expected($chunk1);
  my $chunk2els = $self->parse_html_to_get_expected($chunk2);
  my $pass      = $self->match_tags($chunk2els, $chunk1els);

  if($pass) {
    return 1;

  } else {
    if($fn =~ m{^t/}mx) {
      ($fn) = $fn =~ m{([^/]+)$}mx;
    }
    if(!$fn) {
      $fn = q[blob];
    }

    my $rx = "/tmp/${fn}-chunk-received";
    my $ex = "/tmp/${fn}-chunk-expected";
    open my $fh1, q(>), $rx or croak "Error opening $ex";
    open my $fh2, q(>), $ex or croak "Error opening $rx";
    print $fh1 $chunk1;
    print $fh2 $chunk2;
    close $fh1 or croak "Error closing $ex";
    close $fh2 or croak "Error closing $rx";
    diag("diff $ex $rx");
  }

  return;
}

sub parse_html_to_get_expected {
  my ($self, $html) = @_;
  my $p;
  my $array = [];

  if ($html =~ m{^t/}xms) {
    $p = HTML::PullParser->new(
			       file  => $html,
			       start => '"S", tagname, @attr',
			       end   => '"E", tagname',
			      );
  } else {
    $p = HTML::PullParser->new(
			       doc   => $html,
			       start => '"S", tagname, @attr',
			       end   => '"E", tagname',
			      );
  }

  my $count = 1;
  while (my $token = $p->get_token()) {
    my $tag = q{};
    for (@{$token}) {
      $_ =~ s/\d{4}-\d{2}-\d{2}/date/xms;
      $_ =~ s/\d{2}:\d{2}:\d{2}/time/xms;
      $tag .= " $_";
    }
    push @{$array}, [$count, $tag];
    $count++;
  }

  return $array;
}

sub match_tags {
  my ($self, $expected, $rendered) = @_;
  my $fail = 0;
  my $a;

  for my $tag (@{$expected}) {
    my @temp = @{$rendered};
    my $match = 0;
    for ($a= 0; $a < @temp;) {
      my $rendered_tag = shift @{$rendered};
      if ($tag->[1] eq $rendered_tag->[1]) {
        $match++;
        $a = scalar @temp;
      } else {
        $a++;
      }
    }

    if (!$match) {
      diag("Failed to match '$tag->[1]'");
      return 0;
    }
  }

  return 1;
}

###########
# for catching emails, so firstly they don't get sent from within a test
# and secondly you could then parse the caught email
#

sub catch_email {
  my ($self, $model) = @_;
  $model->{emails} ||= [];
  my $sub = sub {
    my $msg = shift;
    push @{$model->{emails}}, $msg->as_string;
    return;
  };
  MIME::Lite->send('sub', $sub);
  return;
}

##########
# for parsing emails to get information from them, probably caught emails
#

sub parse_email {
  my ($self, $email, $for_mailer) = @_;
  my $parser = MIME::Parser->new();
  $parser->output_to_core(1);
  my $entity = $parser->parse_data($email);
  if(! $entity->bodyhandle->as_string() ) {return {};}
  my $ref    = {
		annotation => $entity->bodyhandle->as_string(),
		subject    => $entity->head->get('Subject', 0),
		to         => $entity->head->get('To',0)   || undef,
		cc         => $entity->head->get('Cc',0)   || undef,
		bcc        => $entity->head->get('Bcc',0)  || undef,
		from       => $entity->head->get('From',0) || undef,
	       };
  if ($for_mailer) {
    $ref->{body}          = $entity->bodyhandle->as_string()     || undef;
    $ref->{precendence}   = $entity->head->get('Precedence',0)   || undef;
    $ref->{content_type}  = $entity->head->get('Content-Type',0) || undef;
  }
  return $ref;
}

sub is_colour {
  my ($png_response, @args) = @_;

  #########
  # strip HTTP response header
  #
  $png_response =~ s/.*?\n\n//smx;

  #########
  # convert blob to GD
  #
  my $gd = GD::Image->newFromPngData($png_response);

  #########
  # status coloured box extends to the bottom-right of the instrument image
  # so pull the bottom-right pixel and check its colour
  #
  my ($width, $height) = $gd->getBounds();
  my $rgb_index        = $gd->getPixel($width-1, $height-1);
  my @rgb              = $gd->rgb($rgb_index);
  diag("status colour is (@rgb)");

  return is_deeply(\@rgb, @args);
}

1;

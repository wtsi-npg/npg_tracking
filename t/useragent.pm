package t::useragent;
use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);
use Carp;

sub new {
  my ($class, $ref) = @_;
  $ref ||= {};
  $ref->{'mock'} ||= {};

  if(!exists $ref->{is_success}) {
    carp qq(Did you mean to leave ua->{'is_success'} unset?);
  }
  $ref->{last_request} = [];

  return bless $ref, $class;
}

sub mock {
  my ($self, $mock) = @_;
  if($mock) {
    $self->{mock} = $mock;
  }
  return $self->{mock};
}

sub last_request {
  my ($self, $last_request) = @_;
  if($last_request) {
    push @{$self->{last_request}}, $last_request;
  }
  return $self->{last_request}->[-1] || {};
}

sub requests {
  my $self = shift;
  return $self->{last_request};
}

sub get {
  my ($self, $uri) = @_;
  $self->{'uri'}   = $uri;
  return $self;
}

sub post {
  my ($self, $uri, %args) = @_;
  $self->{uri}            = $uri;
  push @{$self->{last_request}}, \%args;
  return $self;
}

sub request     {
  my ($self, $req) = @_;
  $self->{uri} = $req->uri();
  push @{$self->{last_request}}, $req;
  return $self;
}

sub requests_redirectable {
  my $self = shift;
  return [];
}

sub content {
  my $self = shift;

  my $test_data = $self->{mock}->{$self->{uri}};
  if (!$test_data) {
    croak qq(No mock data configured for $self->{'uri'});
  }
  
  if ($test_data && $test_data =~ /^t\/|\/tmp\//sm) {
    open my $fh, q(<), $test_data or croak qq(Error opening '$test_data': $ERRNO);
    local $RS   = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
  }
  return $test_data;
}

sub decoded_content {
  my $self = shift;
  return $self->content();
}

sub response    { my $self = shift; return $self; }
sub is_success  { my $self = shift; return $self->{'is_success'}; }
sub status_line { return 'error in t::useragent'; }
sub headers {
  my $self = shift;
  return $self;
}
sub header { return q[]; }

1;

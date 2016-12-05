package t::request;
use strict;
use warnings;

use IO::Scalar;
use Carp;
use CGI;
use t::util;
use npg::controller;
use npg::model::user;

*IO::Scalar::BINMODE = sub {};

sub new {
  my ($class, $ref) = @_;

  if(!exists $ref->{PATH_INFO}) {
    croak q[Must specify PATH_INFO];
  }

  if(!exists $ref->{REQUEST_METHOD}) {
    croak q[Must specify REQUEST_METHOD];
  }

  if(!exists $ref->{username}) {
    croak q[Must specify username];
  }

  $ENV{HTTP_HOST}       = q[test];
  $ENV{SERVER_PROTOCOL} = q[HTTP];
  $ENV{REQUEST_METHOD}  = $ref->{REQUEST_METHOD};
  $ENV{PATH_INFO}       = $ref->{PATH_INFO};
  $ENV{REQUEST_URI}     = "/perl/prodsoft/npg/npg$ref->{PATH_INFO}";


  # This is required to work with CGI > 3.43 (conflict with Clearpress/Catalyst)
  local $ENV{CONTENT_LENGTH} = 0;


  my $util = $ref->{util} || t::util->new( { fixtures => 1, } );
  $util->catch_email($ref);
  $util->cgi( CGI->new() );


  my $cgi = $util->cgi();

  for my $k (keys %{$ref->{cgi_params}}) {
    my $v = $ref->{cgi_params}->{$k};
    if(ref $v eq 'ARRAY') {
      $cgi->param($k, @{$v});
    } else {
      $cgi->param($k, $v);
    }
  }

  $ref->{util} = $util;
  if($util->isa('t::util')) {
    $util->requestor($ref->{username});
  } else {
    $util->requestor(npg::model::user->new({
					    username => $ref->{username},
					   }));
  }

  if($util->requestor->username() ne $ref->{username}) {
    croak q[Failed to set requestor - was @{[$util->requestor->username()]}];
  }

  my $str;
  my $io = tie *STDOUT, 'IO::Scalar', \$str;
  npg::controller->handler($util);
  return $str;
}

1;

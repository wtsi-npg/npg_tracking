use strict;
use warnings;
use Test::More tests => 5;
use Test::Exception;
use t::util;
use DateTime;
use npg::oidc;

my $code = '4/uXdxXgD8SHFP4bsyavHy_88gnM4n.crr_JcejDLMaOl05ti8ZT3bzZlP2hAI';
my $id_token = q(eyJhbGciOiJSUzI1NiIsImtpZCI6ImEwMTdkZTY4ZThlY2ZmNGJiZjJjZDdlMDlhZmIzZjg1OWVkODcwM2EifQ.eyJpc3MiOiJhY2NvdW50cy5nb29nbGUuY29tIiwiZW1haWwiOiJqczEwQHNhbmdlci5hYy51ayIsInN1YiI6IjExMTE5ODE4NzM1MTM1MTM5Nzg2NyIsImF1ZCI6IjIyODM2MDEyOTk4MS5hcHBzLmdvb2dsZXVzZXJjb250ZW50LmNvbSIsImF0X2hhc2giOiJBeHJzT3daaXFoVi1ZMFhsYVh6WGlBIiwiZW1haWxfdmVyaWZpZWQiOiJ0cnVlIiwiaGQiOiJzYW5nZXIuYWMudWsiLCJhenAiOiIyMjgzNjAxMjk5ODEuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJpYXQiOjEzODUwNDYxODIsImV4cCI6MTM4NTA1MDA4Mn0.K38oHrhzCmK9V8YmaqRmOt9T-rtlCFCzDqh9ELBVXbcqKOqLGHT8EXvUURZBs6AeMQnitNGVGNO41ukuCfiHLixxFCE557VuswSGbL98A5l3VvQettLNc5NX1p7zunaxG3ybokf_Fhvt5yEAKKkf-JpmeRUxe05GIEnAVfb6UG4,);

my $oidc = npg::oidc->new;
is($oidc->domain, 'oidc_google');
is($oidc->client_id(), '228360129981.apps.googleusercontent.com');
is($oidc->server, 'https://accounts.google.com');
is($oidc->access_token_path, '/o/oauth2/token');

my $payload = $oidc->verify($id_token);
is($payload->{email},'js10@sanger.ac.uk');



1;

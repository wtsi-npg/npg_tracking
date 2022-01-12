package npg::view;

use strict;
use warnings;
use POSIX qw(strftime);
use URI::URL;
use Carp;
use Try::Tiny;

use npg::util;
use npg::model::user;
use npg::model::usergroup;
use npg::authentication::sanger_sso qw/sanger_cookie_name sanger_username/;
use npg::authentication::sanger_ldap qw/person_info/;
use npg_tracking::util::config qw/get_config/;

use base qw(ClearPress::view);

our $VERSION = '0';

sub new {
  my ($class, @args) = @_;
  my $self           = $class->SUPER::new(@args);
  my $util           = $self->util();
  my $username       = $util->username();
  my $cgi            = $util->cgi();
  my $rfid           = q{};
  my $req_method     = $cgi->request_method() || q{GET};
  if ( uc $req_method ne q{GET} ) {
    $rfid = $util->cgi->param('rfid') || q{};
  }

  if (!$username) {
    my $cookie = $cgi ? $cgi->cookie(sanger_cookie_name()) : q();
    if($cookie) {
      $username = sanger_username($cookie, $self->util()->decription_key());
    }
  }

  my $requestor      = $util->requestor() || npg::model::user->new({
     util     => $util,
     username => $username || 'public',
     rfid     => $rfid,
  });
  #########
  # Force load (and cache) of requestor's memberships
  # and tack on the virtual 'public' group if it's not there already
  #
  if(!scalar grep { $_->groupname() eq 'public' } @{$requestor->usergroups() || []}) {
    push @{ $requestor->{usergroups} }, npg::model::usergroup->new({
      util         => $util,
      groupname    => 'public',
    });
  }

  $self->util->requestor($requestor);

  if ($self->model()) {
    my $model = $self->model();
    $model->aspect($self->aspect());

    if ($model->location_is_instrument() &&
        $requestor->username() eq q{public} &&
        $self->method_name() !~ m/\A(?:create|update|delete)/xms ) {
      my $usergroups = $requestor->usergroups();
      push @{ $usergroups }, npg::model::usergroup->new({
        util => $self->util(),
        groupname => q{loaders},
      });
    }

  }

  return $self;
}

sub get_inst_format {
  my $self = shift;

  my $inst_format = $self->util->cgi->param( q{inst_format} ) || q{HK};
  $self->model->{'inst_format'} = $self->model->sanitise_input( $inst_format );
  return $self->model->{'inst_format'};
}

sub authorised {
  my ( $self ) = @_;
  if ( $self->model() && $self->model->location_is_instrument()
         &&
       $self->action() ne q{create}
         &&
       $self->action() ne q{update} ) {
    return 1;
  }
  return $self->SUPER::authorised();
}

sub realname {
  my ($self, $username) = @_;

  $username ||= $self->util->requestor->username();

  if (!$username || $username eq q[pipeline] || $username eq q[public]) {
    return $username;
  }

  my $realname;
  try {
    $realname = $self->person($username)->{'name'};
  } catch {
    carp $_;
  };
  $realname ||= $username;

  return $realname ;
}

sub person {
  my ($self, $username) = @_;

  $username ||= $self->util->requestor->username();

  my $info = {};
  try {
    $info = person_info($username);
  } catch {
    carp $_;
  };
  return $info;
}

sub app_version {
  return $VERSION;
}

sub time_rendered {
  return strftime '%Y-%m-%dT%H:%M:%S', localtime;
}

sub is_prod {
  my $self = shift;
  my $db =  lc $self->util->dbsection;
  return $db eq q[live] ? 1 : 0;
}

sub staging_urls {
  my ($self, $staging_server) = @_;

  my $config;
  my $esa_sv_name;
  my $esa_pattern = 'esa-sv';
  $staging_server ||= 'default';

  $config = get_config();
  $config  = $config->{'staging_areas2webservers'} || {};
  if ($staging_server =~ /$esa_pattern/msx
        && $self->model->is_in_staging && $config->{$esa_pattern}) {
    $esa_sv_name = $staging_server;
    $staging_server = $esa_pattern;
  }
  $config  = $config->{$staging_server} || $config->{'default'} || {};

  my %config_copy = %{$config};
  $config = \%config_copy;
  my $tracking_key = 'npg_tracking';

  my $surl = $config->{$tracking_key};
  if (!$surl) {
    delete $config->{$tracking_key};
  }

  if ($esa_sv_name) {
    my $replace = sub {
      my $url = shift;
      $url =~ s/$esa_pattern/$esa_sv_name/msx;
      return $url;
    };
    if ($config->{$tracking_key}) {
      $config->{$tracking_key} = $replace->($config->{$tracking_key});
    }
    my $seqqc_key = 'seqqc';
    if ($config->{$seqqc_key}) {
      $config->{$seqqc_key} = $replace->($config->{$seqqc_key});
    }
  }

  return $config;
}

sub lims_batches_url {
  my $self = shift;
  return $self->util->lims_url . '/batches/';
}

1;

__END__

=head1 NAME

npg::view - New pipeline MVC view superclass, derived from ClearPress::View

=head1 VERSION

=head1 SYNOPSIS

  my $oView = npg::view::<subclass>->new({'util' => $oUtil});
  $oView->model($oModel);

  print $oView->decor()?
    $sw->header()
    :
    q(Content-type: ).$oView->content_type()."\n\n";

  print $oView->render();

  print $oView->decor()?$sw->footer():q();

=head1 DESCRIPTION

View superclass for the NPG MVC application

=head1 SUBROUTINES/METHODS

=head2 new - constructor

  my $oView = npg::view::<subclass>->new({'util' => $oUtil, ...});

=head2 get_inst_format

returns inst_format from cgi params, sanitised

  my $sInstFormat = $oDerivedViewClass->get_inst_format();

=head2 authorised

=head2 realname

  the real name of the user (from LDAP server interface)

  my $sRealName = $oViewer->realname();

=head2 person

  returns hash containing name and team of the user

  my $person = $oViewer->person();
  print $person->{name};
  print $person->{team};

=head2 app_version

=head2 is_prod

=head2 time_rendered  timestamp

=head2 staging_urls

Returns a hash containing urls of a tracking and seqqc servers that
potentially run on a different host where they can access run folders
residing on staging areas.

=head2 lims_batches_url

  Returns a string with the prefix for LIMs batch URL up to /batches/, e.g.

    http://limsserver.net:8080/batches/

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item npg::util

=item npg::model::user

=item npg::model::usergroup

=item npg::authentication::sanger_sso qw/sanger_cookie_name sanger_username/

=item npg::authentication::sanger_ldap qw/person_info/

=item ClearPress::view

=item Carp

=item Try::Tiny

=item URI::URL

=item strict

=item warnings

=item POSIX qw(strftime)

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett
Marina Gourtovaia

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 Genome Research Ltd

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut

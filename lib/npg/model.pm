#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model;
use strict;
use warnings;
use base qw(ClearPress::model);
use npg::util;
use English qw(-no_match_vars);
use Carp;
use Socket;
use npg::model::cost_group;
use Readonly;

our $VERSION = '0';

Readonly::Scalar our $NINETY_DAYS => 90;

sub uid {
  my $self  = shift;
  my $zdate = $self->zdate();
  $zdate    =~ s/[^[:lower:]\d]//smigx;
  $zdate   .= $self->{'_uid_sequence'}++;
  return $zdate;
}

sub model_type {
  my $self = shift;
  my ($obj_type)  = (ref $self) =~ /([^:]+)$/smx;
  return $obj_type;
}

sub all_tags_assigned_to_type {
  my $self = shift;
  if(!$self->{all_tags}) {
    my $query = q{SELECT DISTINCT tf.frequency, t.tag, t.id_tag
                  FROM   tag_frequency tf, tag t, entity_type e
                  WHERE  tf.id_tag = t.id_tag
                  AND    tf.id_entity_type = e.id_entity_type
                  AND    e.description = ?
                  ORDER BY t.tag};
    $self->{all_tags} = $self->gen_getarray('npg::model::tag', $query, $self->model_type());
  }
  return $self->{all_tags};
}

sub dbh_datetime {
  my $self = shift;
  return $self->util->dbh->selectall_arrayref('SELECT NOW()',{})->[0]->[0];
}

sub dates_of_last_ninety_days {
  my ($self) = @_;
  if (!$self->{_dates_of_last_ninety_days}) {
    $self->{_dates_of_last_ninety_days} = [];
    my @temp;
    foreach my $i (0..$NINETY_DAYS) {
      my $dt = DateTime->now(time_zone => 'floating');
      $dt->subtract( days=> $i );
      push @temp, $dt->ymd();
    }
    @{$self->{_dates_of_last_ninety_days}} = reverse @temp;
  }
  return $self->{_dates_of_last_ninety_days};
}

sub aspect {
  my ($self, $aspect) = @_;
  if ($aspect) {
    $self->{aspect} = $aspect;
  }
  return $self->{aspect};
}

sub sanitise_input {
  my ( $self, $input ) = @_;
  my ( $sanitised_input ) = $input =~ /([a-z0-9_]+)/ixms;
  if ( $input ne $sanitised_input ) {
    croak $input . q{ ne } . $sanitised_input;
  }
  return $sanitised_input;
}

sub location_is_instrument {
  my ( $self, $instrument ) = @_;

  if ( $self->{location_is_instrument} ) {
    return $self->{location_is_instrument};
  }

  $instrument ||= npg::model::instrument->new({
    util          => $self->util(),
  });
  my $id_instrument;

  my @possible_ips = ();
  my $x_forward =  $ENV{HTTP_X_FORWARDED_FOR} || q[];
  if ($x_forward) {
    push @possible_ips, (split /,\s/smx, $x_forward);
  }

  my $x_sequencer = $ENV{HTTP_X_SEQUENCER};
  if ($x_sequencer) {
    push @possible_ips, split /\s+/smx, $x_sequencer;
  }

  my $remote_addr = $ENV{REMOTE_ADDR};
  if ( $remote_addr ) {
    push @possible_ips, $remote_addr;
  }

  for my $ip ( @possible_ips ) {
    if ($ip =~ /[^\d\.]/smx) { # the ip address should contain dots and digits only
                               # HTTP_X_FORWARDED_FOR list contains something else
                               # that later causes warnings
      next;
    }
    my $cname = _comp_name_by_host( $ip );
    if ($cname) {
      my $selected_instrument = $instrument->instrument_by_instrument_comp ( $cname );
      if ( $selected_instrument ) {
        $id_instrument = $selected_instrument->id_instrument();
        last;
      }
    }
  }

  $self->{'location_is_instrument'} = $id_instrument;

  return $id_instrument;
}

sub _comp_name_by_host {
  my ( $ip ) = @_;
  ##no critic(RequireCheckingReturnValueOfEval)
  my $comp_name;
  eval {
    my $hostname = gethostbyaddr inet_aton($ip), AF_INET;
    if ($hostname) {
      ( $comp_name ) = $hostname =~ /^((?:\w|-)+)/mxs;
    }
  };
  return $comp_name;
}

sub ajax_array_cost_group_values {
  my ( $self, $group ) = @_;
  my $return_string = q{['};
  $return_string .= join q{','}, @{ npg::model::cost_group->new({
    util => $self->util(),
    name => $group,
  })->group_codes() };
  $return_string .= q{']};

  return $return_string;
}

1;
__END__

=head1 NAME

npg::model - a base class for the NPG family, derived from ClearPress::model

=head1 VERSION

=head1 SYNOPSIS

 use strict;
 use warning;
 use base qw(npg::model);

 __PACKAGE__->mk_accessors(__PACKAGE__->fields());

 sub fields { return qw(...); }

=head1 DESCRIPTION

As legend would have it, this set of modules was written for SVV in
under 20 minutes in the Autumn of 2006.

=head1 SUBROUTINES/METHODS

=head2 uid - a basic method for generating low-volume (time-based) unique IDs

  my $id = $oModelSubClass->uid();

=head2 model_type - a basic method for a model to identify its model (entity) type by returning last part of reference (package name)

  my $model_type = $oModelSubClass->model_type();

=head2 all_tags_assigned_to_type - returns an arrayref containing all tag objects, that have been linked to runs, that also have the frequency that they have been assigned to runs

  my $aAllTagsAssignedToType = $oRun->all_tags_assigned_to_type();

=head2 dbh_datetime - returns a DateTime from the database

=head2 aspect - accessor to allow to store and retrieve the aspect/method that was called in the view

  my $sAspect = $oModelSubClass->aspect($sAspect);

=head2 sanitise_input

runs input through a regex to sanitise that the input has no bad characters - only allows /[a-z0-9_]+/ixms

  my $sSanitisedInput = $oModelSubClass->sanitise_input( $sInput );

=head2 dates_of_last_ninety_days

returns arrayref of the last 90 days, ascending order in format ymd from DateTime
caches this for reuse

  my $aDateOfLast90Days = $oModelSubClass->dates_of_last_ninety_days();

=head2 location_is_instrument

returns id_instrument if the requesting computer is an instrument currently
registered in the database, else undef

Optionally, can take an instrument object to reduce the need to create one

  my $iIdInstrument = $oModelSubClass->location_is_instrument( $oInstrument );

A cache is set, so this is a once per request lookup, since it is highly unlikely the requesting instrument is likely to change as we create a page, but the page might need to call this method more than once

Access from the sequencers is via a proxy which sets X-F-F request header

=head2 ajax_array_cost_group_values

returns a string of comma separated cost codes for R&D

  my $sCostCodeList = $oModelSubClass->ajax_array_cost_group_values();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut

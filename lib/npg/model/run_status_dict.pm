#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::run_status_dict;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::run_status;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_all();

sub fields {
  return qw(id_run_status_dict description temporal_index);
}

sub init {
  my $self = shift;

  if($self->{description} &&
     !$self->{id_run_status_dict}) {
    my $query = q(SELECT id_run_status_dict
                  FROM   run_status_dict
                  WHERE  description = ?);
    my $ref   = [];
    eval {
      $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->description());

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    if(@{$ref}) {
      $self->{id_run_status_dict} = $ref->[0]->[0];
    }
  }
  return 1;
}

sub runs {
  my ($self, $params ) = @_;
  $params ||= {};
  $params->{id_instrument_format} ||= q{all};

  my $pkg   = 'npg::model::run';
  my $query = qq(SELECT @{[join q(, ), map { "r.$_" } $pkg->fields()]}
                 FROM   @{[$pkg->table()]} r,
                        run_status         rs
                 WHERE  rs.id_run             = r.id_run
                 AND    rs.iscurrent          = 1
                 AND    rs.id_run_status_dict = ?);

  if ( $params->{id_instrument} && $params->{id_instrument} =~ /\d+/xms ) {
    $query .= qq[ AND id_instrument = $params->{id_instrument}];
  } else {
    if ( $params->{id_instrument_format} ne q{all} && $params->{id_instrument_format} =~ /\A\d+\z/xms ) {
      $query .= qq[ AND r.id_instrument_format = $params->{id_instrument_format}];
    }
  }
  $query .= q( ORDER BY r.id_run DESC);

  $query    = $self->util->driver->bounded_select($query,
                                                 $params->{len},
                                                 $params->{start});

  return $self->gen_getarray($pkg, $query, $self->id_run_status_dict());
}

sub count_runs {
  my ( $self, $params ) = @_;
  $params ||= {};
  $params->{id_instrument_format} ||= q{all};
  $self->{count_runs} ||= {};

  if ( ! defined $self->{count_runs}->{id_instrument_format} ) {

    my $pkg   = 'npg::model::run';
    my $query = qq(SELECT COUNT(*)
                   FROM   @{[$pkg->table()]} r,
                          run_status         rs
                   WHERE  rs.id_run             = r.id_run
                   AND    rs.iscurrent          = 1
                   AND    rs.id_run_status_dict = ?);

    if ( $params->{id_instrument} && $params->{id_instrument} =~ /\d+/xms ) {
      $query .= qq[ AND id_instrument = $params->{id_instrument}];
    } else {
      if ( $params->{id_instrument_format} ne q{all} && $params->{id_instrument_format} =~ /\A\d+\z/xms ) {
        $query .= qq[ AND r.id_instrument_format = $params->{id_instrument_format}];
      }
    }

    my $ref = $self->util->dbh->selectall_arrayref($query, {}, $self->id_run_status_dict());

    if ( defined $ref->[0] &&
         defined $ref->[0]->[0] ) {
      $self->{count_runs}->{ $params->{id_instrument_format} } = $ref->[0]->[0];
    }
  }

  return $self->{count_runs}->{ $params->{id_instrument_format} } || 0;
}

sub run_status_dicts_sorted {
  my ( $self ) = @_;

  my $pkg = __PACKAGE__;
  my $query = q(SELECT id_run_status_dict, description, temporal_index FROM ) .
                  $pkg->table().
                  q( WHERE iscurrent = 1
                  ORDER BY temporal_index);

  return $self->gen_getarray($pkg, $query);
}

1;
__END__

=head1 NAME

npg::model::run_status_dict

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 init - support load-by-description

  $oRunStatusDict->init();

  e.g.
  my $oRSD = npg::model::run_status_dict->new({
      'util'        => $oUtil,
      'description' => 'pending',
  });

  print $oRSD->id_run_status_dict();

=head2 run_status_dicts - Arrayref of npg::model::run_status_dicts

  my $arRunStatusDicts = $oRunStatusDict->run_status_dicts();

=head2 runs - arrayref of npg::model::runs with a current status having this id_run_status_dict

  my $arRuns = $oRunStatusDict->runs();

Takes an optional hash of params, id_instrument_format => (all,1,2,3..) (defaults to all)
If this is given, the runs returned will only be for instruments of that format

=head2 count_runs - Count the runs with this rsd as their current status

  my $iCountRuns = $oRunStatusDict->count_runs();

Takes an optional hash of params, id_instrument_format => (all,1,2,3..) (defaults to all)
If this is given, the count of runs returned will only be for instruments of that format

=head2 run_status_dicts_sorted

Use instead of generated run_status_dicts to get a temporal ordered, current list

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 GRL, by Roger Pettett

This file is part of NPG.

NPG is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .

=cut

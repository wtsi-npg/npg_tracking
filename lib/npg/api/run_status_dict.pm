#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::api::run_status_dict;
use strict;
use warnings;
use base qw(npg::api::base);
use Carp;
use npg::api::run;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_run_status_dict description);
}

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);

  if(!$self->{'id_run_status_dict'} &&
     $self->{'description'}) {
    my $all_rsd = $self->run_status_dicts();
    my ($rsd)   = grep { $_->description() eq $self->{'description'} } @{$all_rsd};
    return $rsd;
  }
  return $self;
}

sub run_status_dicts {
  my $self             = shift;
  my $run_status_dicts = $self->list->getElementsByTagName('run_status_dicts')->[0];
  my $pkg              = ref $self;
  return [map { $self->new_from_xml($pkg, $_); } $run_status_dicts->getElementsByTagName('run_status_dict')];
}

sub runs {
  my $self    = shift;
  my $runs    = $self->read->getElementsByTagName('runs')->[0];
  return [map { $self->new_from_xml('npg::api::run', $_); } $runs->getElementsByTagName('run')];
}

1;
__END__

=head1 NAME

npg::api::run_status_dict - an interface onto npg.run_status_dict

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 new - Constructor inherited from npg::api::base

  Takes optional util.

  my $oRunStatusDict = npg::api::run_status_dict->new();

  my $oRunStatusDict = npg::api::run_status_dict->new({
    'id_run_status_dict' => $iIdRunStatusDict,
    'util'               => $oUtil,
  });

  my $oRunStatusDict = npg::api::run_status_dict->new({
    'description'        => $sDescription,
  });
  $oRunStatusDict->create();

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::api::<pkg>->fields();

=head2 id_run_status_dict - Get/set the id of this object

  my $iIdRunStatusDict = $oRunStatusDict->id_run_status_dict();
  $oRunStatusDict->id_run_status_dict($iIdRunStatusDict);

=head2 description - Get/set the dictionary description

  my $sDescription = $oRunStatusDict->description();
  $oRunStatusDict->description($sDescription);

=head2 runs - Arrayref of npg::api::runs with this status type

  my $arRuns = $oRunStatusDict->runs();

=head2 run_status_dicts - Arrayref of all npg::api::run_status_dicts

  my $arRunStatusDicts = $oRunStatusDict->run_status_dicts();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

npg::api::base
npg::api::run_status

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

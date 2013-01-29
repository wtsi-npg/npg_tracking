#########
# Author:        gq1
# Maintainer:    $Author: gq1 $
# Created:       2010-04-27
# Last Modified: $Date: 2010-05-04 15:28:42 +0100 (Tue, 04 May 2010) $
# Id:            $Id: instrument_status_annotation.pm 9207 2010-05-04 14:28:42Z gq1 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/model/instrument_status_annotation.pm $
#
package npg::model::instrument_status_annotation;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::annotation;
use npg::model::instrument_status;
use Readonly;

Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 9207 $ =~ /(\d+)/mxs; $r; };

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_instrument_status_annotation
            id_instrument_status
            id_annotation);
}

sub instrument_status {
  my $self = shift;
  return $self->gen_getobj('npg::model::instrument_status');
}

sub annotation {
  my $self = shift;
  return $self->gen_getobj('npg::model::annotation');
}

sub create {
  my $self       = shift;
  my $annotation = $self->annotation();
  my $util       = $self->util();
  my $tr_state   = $util->transactions();

  $util->transactions(0);

  if(!$annotation->id_annotation()) {
    $annotation->create();
  }

  $util->transactions($tr_state);

  $self->{'id_annotation'} = $annotation->id_annotation();

  return $self->SUPER::create();
}

1;
__END__

=head1 NAME

npg::model::instrument_status_annotation 

=head1 VERSION

$LastChangedRevision: 9207 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 instrument_status - npg::model::instrument_status for this status_annotation

=head2 annotation - npg::model::annotation for this status_annotation

=head2 create - coordinate saving the annotation and the instrument_status_annotation link

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi, E<lt>gq1@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

package npg::model::run_lane_annotation;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::annotation;
use npg::model::run_lane;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  return qw(id_run_lane_annotation
            id_run_lane
            id_annotation);
}

sub run_lane {
  my $self = shift;
  return $self->gen_getobj('npg::model::run_lane');
}

sub annotation {
  my ( $self, $annotation ) = @_;
  if ( ! $self->{annotation} ) {
    $self->{annotation} = $self->gen_getobj('npg::model::annotation');
  }
  return $self->{annotation};
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
  $self->SUPER::create();

  return 1;
}

1;
__END__

=head1 NAME

npg::model::run_lane_annotation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 run_lane - npg::model::run_lane for this run_lane_annotation

  my $oRunLane = $oRunLaneAnnotation->run_lane();

=head2 annotation - npg::model::annotation for this run_annotation

  my $oAnnotation = $oRunLaneAnnotation->annotation();

=head2 create - coordinate saving the annotation and the run_lane_annotation link

  $oRunLaneAnnotation->create();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007, 2026 Genome Research Ltd.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

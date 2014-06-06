#########
# Author:        rmp
# Created:       2006-10-31
#
package npg::model::run_annotation;
use strict;
use warnings;
use base qw(npg::model);
use English qw(-no_match_vars);
use Carp;
use npg::model::annotation;
use npg::model::run;
use npg::model::event;
use npg::model::entity_type;
use npg::model::instrument_annotation;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a([qw(run annotation)]);

sub fields {
  return qw(id_run_annotation
            id_run
            id_annotation
            run_current_ok
            current_cycle
           );
}

sub _lane_annotation_create {
  my ( $self ) = @_;
  my $util = $self->util();
  my $cgi  = $util->cgi();
  my @lanes = $cgi->param( q{annotate_lanes} );

  if ( ! scalar @lanes ) {
    croak 'No lanes provided';
  }

  my $id_run = $cgi->param( q{id_run} );
  my $tr_state   = $util->transactions();

  my $annotation = $self->annotation();
  $util->transactions(0);

  if ( ! $annotation->id_annotation() ) {
    $annotation->create();
  }

  foreach my $position ( @lanes ) {
    my $id_run_lane = npg::model::run_lane->new( {
      util => $util,
      id_run => $id_run,
      position => $position,
    } )->id_run_lane();
    npg::model::run_lane_annotation->new( {
      util => $util,
      id_run_lane => $id_run_lane,
      annotation => $annotation,
    } )->create();
  }

  ##########
  # add the annotation to the instrument if checked to do so
  $self->_save_annotation_to_instrument( { annotation => $annotation } );

  $util->transactions($tr_state);

  $util->transactions() and $util->dbh->commit();

  return 1;
}

sub create {
  my $self       = shift;
  my $util       = $self->util();
  my $cgi = $util->cgi();
  if ( $cgi->param( q{switch_to_lanes} ) ) {
    return $self->_lane_annotation_create();
  }


  my $annotation = $self->annotation();
  my $tr_state   = $util->transactions();

  if(defined $self->current_cycle() && $self->current_cycle() eq q{}){
     $self->current_cycle(undef);
  }

  my $run_ok  = defined $cgi->param( q{run_current_ok} ) ? $cgi->param( q{run_current_ok} )
              :                                            undef
              ;

  $self->run_current_ok( $run_ok );

  $util->transactions(0);

  if(!$annotation->id_annotation()) {
    $annotation->create();
  }

  if ( $cgi->param( q{multiple_runs} ) ) {
    $self->_multiple_run_annotation_create( $annotation );
  } else {
    $self->_single_run_annotation_create( { annotation => $annotation } );
  }


  #########
  # re-enable transactions for final create
  #
  $util->transactions($tr_state);

  $util->transactions() and $util->dbh->commit();

  return 1;
}

sub _multiple_run_annotation_create {
  my ( $self, $annotation ) = @_;

  my $util = $self->util();
  my $cgi  = $util->cgi();
  my @run_ids = $cgi->param( 'run_ids' );

  my %seen_instrument;

  foreach my $id_run ( @run_ids ) {
    my $args = { annotation => $annotation };
    my $run = npg::model::run->new( {
      util => $util,
      id_run => $id_run,
    } );
    if ( $cgi->param( 'include_instruments' ) ) {

      my $id_instrument = $run->id_instrument();
      # make sure we only link annotation to an instrument once
      if ( ! $seen_instrument{ $id_instrument } ) {
        $args->{id_instrument} = $id_instrument;
        $seen_instrument{ $id_instrument }++;
      }
    }

    npg::model::run_annotation->new( {
      util => $util,
      id_run => $id_run,
      run_current_ok => $self->run_current_ok(),
      current_cycle => $run->actual_cycle_count(),
    } )->_single_run_annotation_create( $args );
  }

  return 1;
}

# create the run_annotation for this single run
sub _single_run_annotation_create {
  my ( $self, $arg_refs ) = @_;

  my $annotation = $arg_refs->{annotation};
  my $count = 1;

  my $description = $annotation->user->username() . q{ annotated run } . $self->run->name() . qq{\n};

  if ( $arg_refs->{current_cycle} ) {
    $self->current_cycle( $arg_refs->{current_cycle} );
  }

  if ( $self->current_cycle() ){
    $description .= q{Current Cycle: }. $self->current_cycle() . qq{\n};
  }

  if( defined $self->run_current_ok() ){
     $description .= 'Currently Run Ok: ';
     if( $self->run_current_ok() ){
        $description .= 'Yes';
     } else {
        $description .= 'No';
     }
     $description .= "\n";
  }

  if ( $annotation->comment() ) {
     $description .= $annotation->comment();
  }

  $self->{id_annotation} = $annotation->id_annotation();
  # we create this row here, so that the event table can receive the correct info
  # Yes, we do want SUPER, as we would otherwise end up in a loop
  $self->SUPER::create();

  my $event = npg::model::event->new({
    util                    => $self->util(),
    entity_type_description => 'run_annotation',
    event_type_description  => 'annotation',
    entity_id               => $self->id_run_annotation(),
    description             => $description,
  });
  $event->create({run => $self->id_run()});

  ##########
  # add the annotation to the instrument if checked to do so
  $self->_save_annotation_to_instrument( $arg_refs );

  return 1;
}

sub _save_annotation_to_instrument {
  my ( $self, $arg_refs ) = @_;
  my $annotation = $arg_refs->{annotation};
  my $util = $self->util();
  my $id_instrument = $arg_refs->{id_instrument} || $util->cgi->param('include_instrument');
  if ( $id_instrument ) {
    my $inst_annotation = npg::model::instrument_annotation-> new({
      util          => $util,
      id_instrument => $id_instrument,
      id_annotation => $annotation->id_annotation(),
      from_run_anno => 1,
    });
    $inst_annotation->create();
  }

  return 1;
}

1;
__END__

=head1 NAME

npg::model::run_annotation

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 run - npg::model::run for this run_annotation

  my $oRun = $oRunAnnotation->run();

=head2 annotation - npg::model::annotation for this run_annotation

  my $oAnnotation = $oRunAnnotation->annotation();

=head2 create - coordinate saving the annotation and the run_annotation link

  $oRunAnnotation->create();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

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

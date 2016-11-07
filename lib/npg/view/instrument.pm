#########
# Author:        rmp
# Created:       2007-03-28
#
package npg::view::instrument;

use strict;
use warnings;
use base qw(npg::view);
use npg::model::instrument;
use npg::model::instrument_format;
use npg::model::instrument_status;
use npg::model::instrument_status_dict;
use npg::model::run_status_dict;
use npg::model::instrument_status_dict;
use GD;
use GD::Text;
use Carp;
use English qw(-no_match_vars);
use Readonly;
use List::MoreUtils qw(any);
use DateTime::Format::MySQL;
use DateTime;

our $VERSION = '0';
##no critic(ProhibitManyArgs ProhibitMagicNumbers)

Readonly::Scalar our $PAGINATION_LEN   => 40;
Readonly::Scalar our $PAGINATION_START => 0;
Readonly::Scalar our $IMAGE_DIMENSIONS            => 110;
Readonly::Scalar our $FILLED_RECTANGLE_INFO       => 80;
Readonly::Scalar our $FILLED_RECTANGLE_TWO        => 66;
Readonly::Scalar our $FILLED_RECTANGLE_FOUR       => 76;
Readonly::Scalar our $BATCH_END_ONE               => 75;
Readonly::Scalar our $BATCH_TWO                   => 4;
Readonly::Scalar our $END_TWO                     => 16;
Readonly::Scalar our $PAIRED_ONE                  => -6;
Readonly::Scalar our $LINE_SIZE_ADJUST            => 20;
Readonly::Scalar our $ARC_SIZE_ADJUST             => 10;
Readonly::Scalar our $DEGREES_IN_CIRCLE           => 360;
Readonly::Scalar our $INS_NAME_VALUE_ONE          => 36;
Readonly::Scalar our $INS_NAME_VALUE_TWO          => 14;
Readonly::Scalar our $INS_STATUS_VALUE_ONE        => 4;
Readonly::Scalar our $INS_STATUS_VALUE_TWO        => 80;
Readonly::Scalar our $RUN_NAME_VALUE_TWO          => 80;
Readonly::Scalar our $RUN_STATUS_VALUE_TWO        => 94;
Readonly::Scalar our $INS_DOWN_THICKNESS          => 4;
Readonly::Scalar our $PLOTTER_WIDTH               => 1000;
Readonly::Scalar our $PLOTTER_HEIGHT              => 400;
Readonly::Scalar our $X_LABEL_SKIP                => 24;
Readonly::Scalar our $Y_ALERT                     => 49;
Readonly::Scalar our $Y_ALERT_TOP                 => 29;
Readonly::Scalar our $ALERT_MARGIN                => 4;
Readonly::Scalar our $ALERT_MINUTES_THRESHOLD     => 30;
Readonly::Scalar our $HUNDRED_PERCENT             => 100;

Readonly::Scalar our $COLOUR_WHITE  => [(255,255,255)];
Readonly::Scalar our $COLOUR_GREEN  => [(3,219,59)];
Readonly::Scalar our $COLOUR_RED    => [(219,59,3)];
Readonly::Scalar our $COLOUR_ORANGE => [(217,116,23)];
Readonly::Scalar our $COLOUR_LIGHT_ORANGE => [(252,174,42)];
Readonly::Scalar our $COLOUR_BLUE   => [(61,171,255)];
Readonly::Scalar our $COLOUR_YELLOW => [(246,229,171)];
Readonly::Scalar our $COLOUR_PINK   => [(255,192,203)];
Readonly::Scalar our $PROGRESS_BAR_BG   => [(220,220,220)];
Readonly::Scalar our $PROGRESS_BAR_FG   => [(225,225,60)];

Readonly::Scalar our $KEY_OFFSET_Y     => 12;
Readonly::Scalar our $KEY_OFFSET_X     => 4;
Readonly::Scalar our $KEY_BLOCK_WIDTH  => 20;
Readonly::Scalar our $KEY_BLOCK_HEIGHT => 10;
Readonly::Scalar our $KEY_FONTSIZE     => 24;

sub authorised {
  my $self   = shift;
  my $util   = $self->util();
  my $action = $self->action();
  my $aspect = $self->aspect();
  my $requestor = $util->requestor();

  if($aspect eq 'update_statuses' && $requestor->is_member_of('engineers')) {
    return 1;
  }

  return $self->SUPER::authorised();
}

sub new {
  my ($class, @args) = @_;
  my $self  = $class->SUPER::new(@args);
  my $model = $self->model();

  if($model && $model->id_instrument() &&
     $model->id_instrument() ne 'key' &&
     $model->id_instrument() !~ /^\d+$/smx) {
    $model->name($model->id_instrument());
    $model->id_instrument(0);
    $model->init();
  }

  return $self;
}

sub list {
  my $self  = shift;
  my $util  = $self->util();
  my $cgi   = $util->cgi();
  my $model = $self->model();
  my $id_instrument_format = $cgi->param('id_instrument_format');

  if($id_instrument_format) {
    my $instrument_format = npg::model::instrument_format->new({
                util => $util,
                id_instrument_format => $id_instrument_format,
                     });
    $model->{instruments} = $instrument_format->instruments();

  } else {
    $model->{instruments} = $model->current_instruments();
  }

  $model->{instruments} = [map {$_->[0]} sort {
    ($a->[1] <=> $b->[1]) or ($a->[3]<=>$b->[3]) or ($a->[2] cmp $b->[2])
  } map {[$_, $_->id_instrument_format, $_->name, $_->name=~/(\d+)/smx]} @{$model->{instruments} }];

  return 1;
}

sub list_textual {
  my ($self, @args) = @_;
  return $self->list(@args);
}

sub list_graphical {
  my ($self, @args) = @_;
  return $self->list(@args);
}

sub list_edit_statuses {
  my ($self, @args) = @_;

  my $root_isd = npg::model::instrument_status_dict->new({
                util => $self->util(),
               });
  $self->model->{instrument_status_dicts} = $root_isd->current_instrument_status_dicts();

  my $root_imd = npg::model::instrument_mod_dict->new({
                   util => $self->util(),
                  });
  $self->model->{instrument_mod_dicts} = $root_imd->instrument_mod_dicts();

  return $self->list(@args);
}

sub update_statuses {
  my $self  = shift;
  my $model = $self->model();
  my $util  = $self->util();
  my $cgi   = $util->cgi();

  if($model->name() ne 'group') {
    return;
  }

  my @id_instruments = $cgi->param('id_instrument');
  my $iisd           = $cgi->param('id_instrument_status_dict');
  my $id_user        = $util->requestor->id_user();
  my $comment        = $cgi->param('comment') || q();

  if(!$comment) {
    $self->add_warning('No comment given');
    $self->aspect('list_edit_statuses');
    return $self->list_edit_statuses();
  }

  for my $id_instrument (@id_instruments) {
    my $is = npg::model::instrument_status->new({
             util                      => $util,
             id_instrument             => $id_instrument,
             id_instrument_status_dict => $iisd,
             id_user                   => $id_user,
             comment                   => $comment,
            });
    $is->create();
  }

  return 1;
}


sub read { ## no critic (ProhibitBuiltinHomonyms)
  my $self    = shift;
  my $util    = $self->util();
  my $cgi     = $util->cgi();
  my $model   = $self->model();
  my $aspect  = $self->aspect();
  my $session = $util->session();
  my $len     = $cgi->param('len')   || $PAGINATION_LEN;
  my $start   = $cgi->param('start') || $PAGINATION_START;
  my $id_rsd  = $cgi->param('id_run_status_dict') || $session->{id_run_status_dict} || 'all';
  my $all_rsd = npg::model::run_status_dict->new({
              util => $util,
             })->run_status_dicts();

  $model->{start}            = $start;
  $model->{len}              = $len;
  $model->{run_status_dicts} = $all_rsd;

  $model->{runs} = $model->runs({
         len                => $len,
         start              => $start,
         id_run_status_dict => ($id_rsd ne 'all')?$id_rsd:undef,
        });
  $model->{count_runs} = $model->count_runs({id_run_status_dict => ($id_rsd ne 'all')?$id_rsd:undef});

  $model->{id_run_status_dict}   = $id_rsd;
  $session->{id_run_status_dict} = $id_rsd;

  return 1;
}

sub read_key_png {
  my $self = shift;

  my $im       = GD::Image->new($IMAGE_DIMENSIONS,$IMAGE_DIMENSIONS);
  my $colours = $self->_allocate_colours($im);
  my $font     = gdSmallFont;

  Readonly::Scalar my $TYPES => [
                                 {'busy'          => $colours->{'green'},  },
                                 {'idle'          => $colours->{'blue'},   },
                                 {'wash required' => $colours->{'yellow'}, },
                                 {'plnd. repair'  => $colours->{'pink'},   },
                                 {'down4repair'   => $colours->{'red'},    },
                                 {'plnd. service' => $colours->{'lorange'},},
                                 {'down4service'  => $colours->{'orange'},    },
                                ];
  my $y = $KEY_OFFSET_Y;
  for my $type (@{$TYPES}) {
    my ($k, $v) = %{$type};
    $im->filledRectangle($KEY_OFFSET_X, $y, $KEY_BLOCK_WIDTH, $y+$KEY_BLOCK_HEIGHT, $v);
    $im->string($font, $KEY_OFFSET_X*2+$KEY_BLOCK_WIDTH, $y, $k, $colours->{'black'});
    $y += $KEY_OFFSET_Y;
  }

  return $im->png();
}

sub _allocate_colours {
  my ($self, $im) = @_;

  my $colours = {};
  $colours->{'white'}  = $im->colorAllocate(@{$COLOUR_WHITE});
  $colours->{'black'}  = $im->colorAllocate(0,0,0);
  $colours->{'green'}  = $im->colorAllocate(@{$COLOUR_GREEN});
  $colours->{'red'}    = $im->colorAllocate(@{$COLOUR_RED});
  $colours->{'orange'} = $im->colorAllocate(@{$COLOUR_ORANGE});
  $colours->{'lorange'} = $im->colorAllocate(@{$COLOUR_LIGHT_ORANGE});
  $colours->{'blue'}   = $im->colorAllocate(@{$COLOUR_BLUE});
  $colours->{'yellow'} = $im->colorAllocate(@{$COLOUR_YELLOW});
  $colours->{'pink'}   = $im->colorAllocate(@{$COLOUR_PINK});
  $colours->{'pbar_bg'}   = $im->colorAllocate(@{$PROGRESS_BAR_BG});
  $colours->{'pbar_fg'}   = $im->colorAllocate(@{$PROGRESS_BAR_FG});
  return $colours;
}

sub _read_png_colour {
  my ($self, $im, $colours, $statuses) = @_;
  my $model         = $self->model();

  my $finished_work = 0;
  my $bg            = $colours->{'red'};

  if ( $statuses->{run}
       && $statuses->{run} !~ / run[ ](?: cancelled | stopped[ ]early )/smix )
  {
    if ( $statuses->{run} !~ / run[ ](?: pending | in[ ]progress ) /smix ) {
       $finished_work = 1;
    }
  } elsif ( $model->instrument_format->model() eq 'cBot' ) {
    if ( !defined $model->percent_complete() ) {
        $finished_work = 1;
    }
    # 'Busy' cBots get to here.
  } else {
    $finished_work = 1;
  }

  if ( !$finished_work ) {
    $bg = $colours->{'green'};
  } else {
    $bg = $colours->{'blue'};
    if ( $statuses->{instrument} =~ /^wash/smx ) {
      $bg = $colours->{'yellow'};
    }
  }
  ##no critic (ProhibitCascadingIfElse)
  if ( $statuses->{instrument} eq 'down for repair') {
    $bg = $colours->{'red'};
  } elsif ( $statuses->{instrument} eq 'planned repair') {
    $bg = $colours->{'pink'};
  } elsif ( $statuses->{instrument} eq 'down for service') {
    $bg = $colours->{'orange'};
  } elsif ( $statuses->{instrument} eq 'planned service') {
    $bg = $colours->{'lorange'};
  }

  return $bg;
}

sub _run2image {
  my ($self, $im, $colours, $font, $current_run, $run_status, $ins_status, $complete, $x_offset) = @_;

  if (!defined $x_offset) { $x_offset = 0; }

  my $bg = $self->_read_png_colour($im, $colours, {instrument => $ins_status, run => $run_status});
  $im->filledRectangle($x_offset,$FILLED_RECTANGLE_INFO, $x_offset+$IMAGE_DIMENSIONS,$IMAGE_DIMENSIONS, $bg);

  my $run_name = $current_run        ? $current_run->name()
                 : defined $complete   ? q{}
                 :                       'idle';

  my $first_line = $npg::model::instrument_status_dict::SHORT_DESCRIPTIONS{$ins_status};
  if (!$first_line) {
    carp "WARNING: No short description for instrument status \"$ins_status\"";
    $first_line = $ins_status ? $ins_status : q[?];
  }
  if ($run_name) {
    $first_line = join q[ ], $first_line, $run_name;
  }

  my $gd_text = GD::Text->new( text => $first_line, );
  $gd_text->set_font($font);
  my $w = $gd_text->get('width');
  my $x_start = int ($IMAGE_DIMENSIONS - $w)/2;
  $im->string($font, $x_offset+$x_start, $RUN_NAME_VALUE_TWO, $first_line, $colours->{'black'});

  if ($run_status) {
    $gd_text->set_text($run_status);
    $w = $gd_text->get('width');
    $x_start = int ($IMAGE_DIMENSIONS - $w)/2;
    $im->string($font, $x_offset+$x_start, $RUN_STATUS_VALUE_TWO, $run_status, $colours->{'black'});
  }
  return;
}

sub _batch2image {
  my ($self, $current_run, $im, $font, $black, $x_offset, $is_ms) = @_;

  if (!$current_run) { return; }
  if (!defined $x_offset) { $x_offset = 0; }
  my $batch_x_start = $BATCH_END_ONE + $x_offset;
  my $batch_y_start = $BATCH_TWO;
  if ( $is_ms ) {
    $batch_x_start += -15;
    $batch_y_start += 25;
  }
  $im->string($font, $batch_x_start, $batch_y_start, (sprintf q(B%d), $current_run->batch_id()), $black);

  if($current_run->is_paired()) {
    $im->string($font, $batch_x_start, $END_TWO, (sprintf q(Run %d), $current_run->end()), $black);
  } else {
    my $is_paired_read = $current_run->is_paired_read;
    if(defined $is_paired_read){
      my $y_coord = $END_TWO;
      if ( $is_ms ) {
        $y_coord += 25;
      }
      if($is_paired_read==1){
        $im->string($font, $batch_x_start + $PAIRED_ONE, $y_coord, 'paired', $black);
      } else {
        $im->string($font, $batch_x_start + $PAIRED_ONE, $y_coord, 'single', $black);
      }
    }
  }
  return;
}

sub _progress_bar_image {
  my ($self, $im, $colours, $font, $current_run, $run_status, $complete, $x_offset) = @_;

  if (!defined $x_offset) { $x_offset = 0; }

  if ( $current_run or defined $complete ) {
    if ( ( $run_status eq 'run in progress' ) or ( defined $complete ) ) {
      my $ecc = ( defined $complete ) ? $HUNDRED_PERCENT : $current_run->expected_cycle_count();
      my $acc = ( defined $complete ) ? $complete        : $current_run->actual_cycle_count();
      my $fraction = $ecc ? $acc * $IMAGE_DIMENSIONS / $ecc : 0;
      $im->filledRectangle($x_offset, $FILLED_RECTANGLE_TWO, $x_offset+$IMAGE_DIMENSIONS,$FILLED_RECTANGLE_FOUR, $colours->{'pbar_bg'});
      $im->filledRectangle($x_offset, $FILLED_RECTANGLE_TWO,$x_offset+$fraction,$FILLED_RECTANGLE_FOUR, $colours->{'pbar_fg'});
      $im->string($font, $x_offset, $FILLED_RECTANGLE_TWO, (defined $complete ? sprintf q(%2d%%), $acc : sprintf q(%2d/%2d), $acc, $ecc), $colours->{'black'});
    }
  }
  return;
}

sub _run_status4image {
  my ($self, $run) = @_;
  return $run ? $run->current_run_status->run_status_dict->description() : q();
}

sub read_png { ## no critic (Subroutines::ProhibitExcessComplexity)
  my $self       = shift;
  my $model      = $self->model();
  my $util       = $self->util();

  return $self->read_key_png() if $model->id_instrument() eq 'key';

  my $inst_model = $model->instrument_format->model();
  my $is2slot = $model->is_two_slot_instrument;
  my $is_ms = $model->is_miseq_instrument;

  my $ins_status_obj = $model->current_instrument_status;
  if (!$ins_status_obj) {
    carp 'WARNING: Current status not available for instrument ' . $model->name;
  }
  my $ins_status  = $ins_status_obj ? $ins_status_obj->instrument_status_dict->description() : q{?};
  my $current_run;
  my $run_status;

  if ( !$is2slot ) {
    $current_run = $model->current_run();
    $run_status  = $self->_run_status4image($current_run);
    if($current_run && $current_run->is_paired_read() && ! $is_ms ) {
      $inst_model .= '_PE';
    }
  }

  my $im_fn  = sprintf q(%s/gfx/%s.png), $util->data_path(), $inst_model;
  my $src    = (-e $im_fn)
                ? GD::Image->newFromPng($im_fn)
                : GD::Image->new($IMAGE_DIMENSIONS,$IMAGE_DIMENSIONS);
  $src->colorAllocate(@{$COLOUR_WHITE});

  my $width  = $is2slot ? 2*$IMAGE_DIMENSIONS+2 : $IMAGE_DIMENSIONS;
  my $height = $IMAGE_DIMENSIONS;
  my $im     = GD::Image->new($width, $height);
  my $colours = $self->_allocate_colours($im);
  my $font   = gdSmallFont;

  # copy the image of the instrument to our image, align to the centre
  my $src_width = $src->width();
  if ($src_width > $width) {$src_width = $width;}
  my $src_height = $src->height();
  if ($src_height > $height) {$src_height = $height;}
  my $x_start = int ($width - $src_width)/2;
  $im->copy($src, $x_start, 0, 0, 0, $src_width, $src_height);

  # if instrument has not been connected to  th threshold duration add disconnect icon
  if ( my $lc=$model->latest_contact) {
    if (DateTime::Format::MySQL->parse_datetime($lc)->add(minutes=> $ALERT_MINUTES_THRESHOLD) < DateTime->now()) {
      my $im_fn_ds  = sprintf q(%s/gfx/disconnect.png), $util->data_path();
      my $src_ds    = GD::Image->newFromPng($im_fn_ds);
      $im->copy($src_ds, $im->width - $src_ds->width - $ALERT_MARGIN , $Y_ALERT, 0,0,$src_ds->width,$src_ds->height);
    }
  }

  # if current_runs have copying_problem tag add drive error icon
  if (my @r = @{$model->current_runs}) {
    if (any {$_->has_tag_with_value(q(copying_problem))} @r) {
      my $im_fn_ds  = sprintf q(%s/gfx/drive_error.png), $util->data_path();
      my $src_ds    = GD::Image->newFromPng($im_fn_ds);
      $im->copy($src_ds, $im->width - $src_ds->width - $ALERT_MARGIN , $Y_ALERT_TOP, 0,0,$src_ds->width,$src_ds->height);
    }
  }

  # if the instrument is down, draw a circle with a line across
  if($ins_status =~ /down/xms) {
    my $sign_colour = $ins_status =~ /service/xms ? $colours->{'orange'} : $colours->{'red'};
    my $y_centre = int $height/2;
    my $x_centre = int $width/2;
    my $line_half_dim = $y_centre - $LINE_SIZE_ADJUST;

    $im->setThickness($INS_DOWN_THICKNESS);
    $im->line($x_centre-$line_half_dim, $y_centre-$line_half_dim, $x_centre+$line_half_dim, $y_centre+$line_half_dim,  $sign_colour);
    my $circle_size = $height-$ARC_SIZE_ADJUST;
    $im->arc($width/2, $height/2, $circle_size, $circle_size, 0, $DEGREES_IN_CIRCLE, $sign_colour);
  }

   # display instrument model name
   my $instr_annot_x = $is2slot ? 45 : $is_ms ? -10 : 0;
   $instr_annot_x += $INS_NAME_VALUE_ONE;
   my $instr_annot_y = $is2slot ? -7 : $is_ms ? -7 : 0;
   $instr_annot_y += $INS_NAME_VALUE_TWO;
   $im->string($font, $instr_annot_x, $instr_annot_y, $model->name(),
     $model->is_cbot_instrument ? $colours->{'blue'} : $colours->{'black'});

   if(any{$_->description eq q(R&D)}@{$model->designations()||[]}){
     $im->string(gdGiantFont, $instr_annot_x, $INS_NAME_VALUE_TWO*2, 'R&D', $colours->{'yellow'});
   }

  # display run-related info
  my $complete;
   if (!$is2slot) {
     $complete = $model->percent_complete(); # Short-hand for cBots
     $self->_run2image($im, $colours, $font, $current_run, $run_status, $ins_status, $complete);
     $self->_progress_bar_image($im, $colours, $font, $current_run, $run_status, $complete);
     if (!$model->is_cbot_instrument) {
       my $colour = $is_ms ? $colours->{'blue'} : $colours->{'black'};
       $self->_batch2image($current_run, $im, $font, $colour, 0, $is_ms);
     }
   } else {
     my $map = $model->fc_slots2current_runs;
     my $x_offset = 0;
     my $count = 0;
     foreach my $fc_slot (sort keys %{$map}) {

       my @runs = @{$map->{$fc_slot}};
       my $run;
       if (@runs) {
         $run = $model->current_run_by_id($runs[0]);
       }
       my $r_status = $self->_run_status4image($run);

       if ($count) {$x_offset = $IMAGE_DIMENSIONS + 2;}
       $self->_run2image($im, $colours, $font, $run, $r_status, $ins_status, $complete, $x_offset);
       $self->_progress_bar_image($im, $colours, $font, $run, $r_status, $complete, $x_offset);
       my $batch_offset = $count ? -20 : -60;
       $self->_batch2image($run, $im, $font, $colours->{'black'}, $x_offset+$batch_offset);

       $count++;
     }
   }

  return $im->png();
}
## use critic (Subroutines::ProhibitExcessComplexity)

sub read_runs {
  my $self = shift;
  return $self->read();
}

sub read_runs_ajax {
  my $self = shift;
  return $self->read_runs();
}

sub decor {
  my ($self, @args) = @_;

  my $aspect = $self->aspect();
  if($aspect ne 'list_graphical' &&
     $aspect =~ /_(graphical|png)$/smx) {
    return 0;
  }

  return $self->SUPER::decor(@args);
}

sub content_type {
  my ($self, @args) = @_;

  my $aspect = $self->aspect();
  if($aspect ne 'list_graphical' &&
     $aspect =~ /_(graphical|png)$/smx) {
    return 'image/png';
  }

  return $self->SUPER::content_type(@args);
}

sub render {
  my ($self, @args) = @_;

  my $aspect = $self->aspect();
  if($aspect eq 'read_png') {
    my $image = q[];
    eval {
      $image = $self->read_png();
      1;
    } or do {
      my $e = $EVAL_ERROR;
      my $i = $self->model->name;
      carp "ERROR generating image for instrument $i: $e";
    };
    return $image;
  }

  return $self->SUPER::render(@args);
}

1;

__END__

=head1 NAME

npg::view::instrument - view handling for instruments

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 authorised - handling for permissions for certain action/group members

=head2 new - handling for creation by instrument-name

=head2 list - handling for a specific instrument_format or instruments

=head2 list_graphical - handling for graphical listings

=head2 read - additional handling for listing runs by status

=head2 read_png - annotated instrument graphic

=head2 read_key_png - special case handling for instrument of id 'key'

=head2 read_runs - additional handling for listing runs by status

=head2 read_runs_ajax - additional handling for listing runs by status

=head2 content_type - specifics for read_graphical

=head2 decor - specifics for read_graphical

=head2 render - specifics for read_graphical

=head2 list_edit_statuses - batch instrument_status listing/form

=head2 list_textual - basic text listing

=head2 update_statuses - batch instrument_status update (form action)

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item base

=item npg::view

=item strict

=item warnings

=item npg::model::instrument_format

=item npg::model::instrument_status

=item npg::model::instrument_status_dict

=item npg::model::run_status_dict

=item npg::model::instrument_status_dict

=item GD

=item Carp

=item English

=back

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

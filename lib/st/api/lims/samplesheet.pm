#########
# Author:        Marina Gourtovaia mg8@sanger.ac.uk
# Created:       4 September 2013
#

package st::api::lims::samplesheet;

use Carp;
use Moose;
use File::Slurp;
use MooseX::StrictConstructor;
use Readonly;
use List::MoreUtils qw/none/;
use Clone qw(clone);
use URI::Escape qw(uri_unescape);

use npg_tracking::util::types;
use st::api::lims;
with qw/  
          npg_tracking::glossary::run
          npg_tracking::glossary::lane
          npg_tracking::glossary::tag
       /;

=head1 NAME

st::api::lims::samplesheet

=head1 SYNOPSIS

=head1 DESCRIPTION

LIMs parser for the Illumina-style extended samplesheet

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar  our $SAMPLESHEET_RECORD_SEPARATOR => q[,];
Readonly::Scalar  our $SAMPLESHEET_ARRAY_SEPARATOR  => q[ ];
Readonly::Scalar  our $SAMPLESHEET_HASH_SEPARATOR   => q[:];
Readonly::Scalar  my  $NOT_INDEXED_FLAG             => q[NO_INDEX];
Readonly::Scalar  my  $RECORD_SPLIT_LIMIT           => -1;
Readonly::Scalar  my  $DATA_SECTION                 => q[Data];
Readonly::Scalar  my  $HEADER_SECTION               => q[Header];

=head2 path #or input as a filehandle?

Samplesheet path

=cut
has 'path' => (
                  isa => 'NpgTrackingReadableFile',
                  is  => 'ro',
                  required => 1,
);

=head2 id_run

Run id, optional attribute.

=cut
has '+id_run'   =>        (required        => 0, writer => '_set_id_run',);

=head2 position

Position, optional attribute.

=cut
has '+position' =>        (required        => 0,);


=head2 BUILD

Validates attributes given to the constructor against data

=cut
sub BUILD {
  my $self = shift;
  if ($self->position && !exists $self->data->{$DATA_SECTION}->{$self->position}) {
    croak sprintf 'Position %s not defined in %s', $self->position, $self->path;
  }
  if ($self->tag_index && !exists $self->data->{$DATA_SECTION}->{$self->position}->{$self->tag_index}) {
    croak sprintf 'Tag index %s not defined in %s', $self->tag_index, $self->path;
  }
  return;
}

=head2 data

Hash representation of LIMS data

=cut
has 'data' => (
                  isa => 'HashRef',
                  is  => 'ro',
                  lazy => 1,
                  builder => '_build_data',
                  trigger => \&_validate_data,
               );
sub _build_data {
  my $self = shift;

  my @lines = read_file($self->path);
  my $d = {};
  my $current_section = q[];
  my @data_columns = ();

  foreach my $line (@lines) {
    if ($line) {$line =~ s/\s+$//mxs;}
    if (!$line) {
      next;
    }
    my @columns = split $SAMPLESHEET_RECORD_SEPARATOR, $line, $RECORD_SPLIT_LIMIT;
    my @empty = grep {(!defined $_ || $_ eq q[] || $_ =~ /^\s+$/smx)} @columns;
    if (scalar @empty == scalar @columns) {
      next;
    }

    my $section;
    if ( ($section) = $columns[0] =~ /^\[(\w+)\]$/xms) {
      $current_section = $section;
      $d->{$current_section} = undef;
      next;
    }

    if ($current_section eq 'Data') {
      if (!@data_columns) {
        @data_columns = @columns;
        next;
      }
      my $row = {'Lane' => 1,};
      foreach my $i (0 .. $#columns) {
        $row->{$data_columns[$i]} = $columns[$i];
      }
      my @lanes = split /\+/smx, $row->{'Lane'};
      if ($row->{'Index'}) {
        $row->{'default_tag_sequence'} = $row->{'Index'};
        delete $row->{'Index'};
      }
      my $index = $row->{'tag_index'};
      if ($index) {
        delete $row->{'tag_index'};
      } elsif ($row->{'default_tag_sequence'}) {
        $index = $d->{$current_section}->{$lanes[0]} ?
          scalar keys %{$d->{$current_section}->{$lanes[0]}} : 0;
        $index += 1;
      } else {
        $index = $NOT_INDEXED_FLAG;
      }
      delete $row->{'Lane'};

      # There might be no index column header or the value might be undefined
      foreach my $lane (@lanes) { #give all lanes explicitly
        if (exists $d->{$current_section}->{$lane}->{$index}) {
          croak "Multiple $current_section section definitions for lane $lane index $index";
        }
        $d->{$current_section}->{$lane}->{$index} = $row;
      }
   } elsif ($current_section eq 'Reads') {
     my @reads = grep { $_ =~/\d+/smx} @columns;
     if (!@reads) {
       next;
     }
     if (scalar @reads > 1) {
       croak 'Multiple read lengths in one row';
     }
     if (!exists $d->{$current_section}) {
       $d->{$current_section} = [$reads[0]];
     } else {
       push @{$d->{$current_section}}, $reads[0];
     }
   } else {
     my @row = grep { defined $_ && ($_ ne q[]) } @columns;
     if (scalar @row > 2) {
       croak "More than two columns defined in one row in section $current_section";
     }
     $d->{$current_section}->{$row[0]} = $row[1];
   }
  }

  if (!$self->id_run) {
    my $en = $d->{$HEADER_SECTION}->{'Experiment Name'};
    $self->_set_id_run($en);
    carp qq[id_run is set to Experiment Name, $en];
  }

  return $d;
}

sub _validate_data { # this is a callback for Moose trigger
                     # $old_data might not be set
  my ( $self, $data, $old_data ) = @_;
  if (!exists $data->{'Reads'} || !@{ $data->{'Reads'}}) {
    croak 'Information about read lengths is not available';
  }
  #Are read lengths numbers?

  foreach my $section (($DATA_SECTION, $HEADER_SECTION)) {
    if (!exists $data->{$section}) {
      croak "$section section is missing";
    }
  }

  my $id_run = $data->{$HEADER_SECTION}->{'Experiment Name'};
  if ($id_run && $self->id_run && $id_run != $self->id_run) {
    carp sprintf 'Supplied id_run %i does not match Experiment Name, %s',
                  $self->id_run, $id_run;
  }

  #What are compulsory Data section? - check for them
  #Do we have at least one lane? - should be numbers as well
  #Do we have a mixture of indices and non-indexed in one lane?
  #Are all indices numbers?
  return;
}

=head2 is_pool

Read-only boolean accessor, not possible to set from the constructor.
True for a pooled lane on a lane level or tag zero, otherwise false.

=cut
has 'is_pool' =>          (isa             => 'Bool',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_is_pool {
  my $self = shift;
  if ( $self->position && !$self->tag_index && #lane level or tag zero
      (!exists $self->data->{$DATA_SECTION}->{$self->position}->{$NOT_INDEXED_FLAG}) ) {
    return 1;
  }
  return 0;
}

has '_data_row' =>        (isa             => 'Maybe[HashRef]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build__data_row {
  my $self = shift;

  if ($self->position) {
    if ($self->tag_index) {
      if (!exists $self->data->{$DATA_SECTION}->{$self->position}->{$self->tag_index}) {
        croak sprintf 'Tag index %s not defined for %s',
                    $self->tag_index, $self->to_string;
      }
      return $self->data->{$DATA_SECTION}->{$self->position}->{$self->tag_index};
    }
    if (!defined $self->tag_index &&
           exists $self->data->{$DATA_SECTION}->{$self->position}->{$NOT_INDEXED_FLAG}) {
      return $self->data->{$DATA_SECTION}->{$self->position}->{$NOT_INDEXED_FLAG};
    }
  }

  return; #nothing on run level, lane-level pool or tag zero
}

has '_sschildren' =>      (isa             => 'ArrayRef',
                           is              => 'ro',
                           init_arg        => undef,
                           clearer         => 'free_children',
                           lazy_build      => 1,
                          );
sub _build__sschildren {
  my $self = shift;

  my $child_attr_name;
  if ($self->position) {
    if ($self->is_pool) { # lane level pool and tag zero - return plexes
      $child_attr_name = 'tag_index';
    }
  } else { # run level - return lanes
    $child_attr_name = 'position';
  }

  my @children = ();
  if ($child_attr_name) {

    my $h = $child_attr_name eq 'position' ?
               $self->data->{$DATA_SECTION} :
               $self->data->{$DATA_SECTION}->{$self->position};

    my $init = {};
    foreach my $init_attr (qw/id_run path/) {
      if ($self->$init_attr) {
        $init->{$init_attr} = $self->$init_attr;
      }
    }
    if ($child_attr_name eq 'tag_index') {
      $init->{'position'} = $self->position;
    }

    foreach my $attr_value (sort {$a <=> $b} keys %{$h}) {
      $init->{$child_attr_name} = $attr_value;
      $init->{'data'}           = clone($self->data);
      push @children, __PACKAGE__->new($init);
    }
  }

  return \@children;
}

=head2 children

Method returning a list objects that are associated with this object
and belong to the next (one lower) level. An empty list for a non-pool lane and for a plex.
For a pooled lane and tag zero contains plex-level objects. On a run level, when the position 
accessor is not set, returns lane level objects.

=cut
sub children {
  my $self = shift;
  return @{$self->_sschildren()};
}

my @attrs = __PACKAGE__->meta->get_attribute_list;
for my $m (grep { my $delegated = $_; none {$_ eq $delegated} @attrs } @st::api::lims::DELEGATED_METHODS ) {

  __PACKAGE__->meta->add_method( $m, sub {
        my $self=shift;
        if ($self->_data_row) {
          my $column_name = $m;
          if ($m eq 'library_id') {
            $column_name = 'Sample_ID';
          } elsif ($m eq 'sample_name' && (!exists $self->_data_row->{$column_name}) ) {
            $column_name = 'Sample_Name';
          }
          my $value =  $self->_data_row->{$column_name};
          if (defined $value && $value eq q[]) {
            $value = undef;
	  }
          if ($m =~ /s$/smx) {
            my @temp = $value ? split $SAMPLESHEET_ARRAY_SEPARATOR, $value : ();
            $value = \@temp;
	  } elsif ($m eq 'required_insert_size_range') {
            my $h = {};
            if ($value) {
              my @temp = split $SAMPLESHEET_ARRAY_SEPARATOR, $value;
              foreach my $pair (@temp) {
                my ($key, $val) = split $SAMPLESHEET_HASH_SEPARATOR, $pair;
                $h->{$key} = $val;
	      }
            }
            $value = $h;
	  } else {
            if ($value) {
              $value = uri_unescape($value);
	    }
	  }
          return $value;
	}
        return;
  });
}

=head2 to_string

Human friendly description of the object

=cut
sub to_string {
  my $self = shift;
  my $s = __PACKAGE__ . q[, path ] . $self->path;
  if (defined $self->id_run) {
    $s .= q[ id_run ] . $self->id_run;
  }
  if (defined $self->position) {
    $s .= q[ position ] . $self->position;
  }
  if (defined $self->tag_index) {
    $s .= q[ tag_index ] . $self->tag_index;
  }
  return $s;
}

no Moose;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::StrictConstructor

=item Carp

=item Readonly

=item File::Slurp

=item List::MoreUtils

=item Readonly

=item Clone

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2013 GRL, by Marina Gourtovaia

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
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

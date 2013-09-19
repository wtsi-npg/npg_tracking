#########
# Author:        Marina Gourtovaia mg8@sanger.ac.uk
# Created:       24 June 2013
#

package npg_tracking::illumina::run::lims::samplesheet;

use Carp;
use English qw(-no_match_vars);
use Moose;
use File::Slurp;
use MooseX::StrictConstructor;
use Template;
use DateTime;
use Readonly;
use List::MoreUtils qw/any/;

use npg_tracking::util::types;
with qw/  npg_tracking::glossary::run
          npg_tracking::glossary::lane
          npg_tracking::glossary::tag
       /;

=head1 NAME

npg_tracking::illumina::run::lims::samplesheet

=head1 SYNOPSIS


=head1 DESCRIPTION

LIMs-agnostic parser and generator of the Illumina-style sanplesheet for sequencing
and downstream analysis. 

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar  my  $SAMPLESHEET_FILE_EXTENSION   => q[.csv];
Readonly::Scalar  my  $SAMPLESHEET_RECORD_SEPARATOR => q[,];
Readonly::Scalar  my  $NOT_INDEXED_FLAG             => q[NO_INDEX];
Readonly::Scalar  my  $DEFAULT_WORKFLOW             => q[LibraryQC];
Readonly::Scalar  my  $DEFAULT_CHEMISTRY            => q[Default];
Readonly::Scalar  my  $RECORD_SPLIT_LIMIT           => -1;
Readonly::Scalar  my  $DATA_SECTION                  => q[Data];
Readonly::Scalar  my  $HEADER_SECTION               => q[Header];
Readonly::Scalar  my  $IS_CONTROL_COLUMN            => q[WTSI_IsControl];
Readonly::Scalar  my  $LIB_ID_COLUMN                => q[Sample_ID];
Readonly::Scalar  my  $LIB_NAME_COLUMN              => q[Sample_Name];

=head2 data

Hash representation of LIMS data

=cut
has 'data' => (
                  isa => 'HashRef',
                  is  => 'ro',
                  #'metaclass' => 'NoGetopt',
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
      my $index = $row->{'Index'} || $NOT_INDEXED_FLAG;
      delete $row->{'Lane'};
      delete $row->{'Index'};
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
     if (length @reads > 1) {
       croak 'Multiple read lengths in one row';
     }
     if (!exists $d->{$current_section}) {
       $d->{$current_section} = [$reads[0]];
     } else {
       push @{$d->{$current_section}}, $reads[0];
     }
   } else {
     my @row = grep { defined $_ } @columns;
     if (length @row > 2) {
       croak "More than two columns defined in one row in section $current_section";
     }
     $d->{$current_section}->{$row[0]} = $row[1];
   }
  }
  #$self->_validate_data($d);
  return $d;
}

=head2 chip_id

Illumina chip id

=cut
has 'chip_id' => (
                  isa => 'Maybe[Str]',
                  is  => 'ro',
);

=head2 filename

Samplesheet file name

=cut
has 'filename' => (
                  isa => 'Maybe[Str]',
                  is  => 'ro',
                  lazy => 1,
                  builder => '_build_filename',
);
sub _build_filename {
  my $self = shift;
  if ($self->chip_id) {
    return $self->chip_id . $SAMPLESHEET_FILE_EXTENSION;
  }
  return;
}

=head2 dir

Directory with/for the samplesheet

=cut
has 'dir' => (
                  isa => 'Maybe[NpgTrackingDirectory]',
                  is  => 'ro',
);

=head2 path

Samplesheet path

=cut
has 'path' => (
                  #isa => 'NpgTrackingReadableFile',
                  isa => 'Str',
                  is  => 'ro',
                  lazy => 1,
                  builder => '_build_path',
);

sub _build_path {
  my $self = shift;
  if ($self->file_name) {
    if ($self->dir) {
      return abs_path(catfile($self->dir, $self->filename));
    }
    return $self->file_name;
  }
  croak 'Samplesheet file name not known';
}

=head2 id_run

Run id, optional attribute. If not set, batch_id should be set.

=cut
has '+id_run'   =>        (required        => 0,);

=head2 position

Position, optional attribute.

=cut
has '+position' =>        (required        => 0,);


=head2 is_pool

Read-only boolean accessor, not possible to set from the constructor.
True for a pooled lane on a lane level, otherwise false.

=cut
has 'is_pool' =>          (isa             => 'Bool',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_is_pool {
  my $self = shift;
  if ($self->position) {
    if (!exists $self->data->{$DATA_SECTION}->{$self->position}->{$NOT_INDEXED_FLAG}) {
      return 1;
    }
  }
  return 0;
}

has '_entity' =>          (isa             => 'Maybe[HashRef]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build__entity {
  my $self = shift;
  if ($self->position) {
    if (!exists $self->data->{$DATA_SECTION}->{$self->position}) {
      croak sprintf 'Position %s not defined for %s',
                    $self->position, $self->to_string;
    }
    if ($self->is_pool) {
      if (defined $self->tag_index) {
        if (!exists $self->data->{$DATA_SECTION}->{$self->position}->{$self->tag_index}) {
           croak sprintf 'Tag index %s not defined for %s',
                    $self->tag_index, $self->to_string;
	}
        return $self->data->{$DATA_SECTION}->{$self->position}->{$self->tag_index};
      }
    } else {
      return $self->data->{$DATA_SECTION}->{$self->position}->{$NOT_INDEXED_FLAG};
    }
  }
  return;
}

=head2 is_control

Read-only boolean accessor, not possible to set from the constructor.
True for a control lane and for the spiked phix plex, otherwise false.

=cut
has 'is_control' =>       (isa             => 'Bool',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_is_control {
  my $self = shift;
  if ($self->_entity) {
    return $self->_entity->{$IS_CONTROL_COLUMN} ? 1 : 0;
  }
  return 0;
}

has '_sschildren' =>      (isa             => 'ArrayRef',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build__sschildren {
  my $self = shift;
  my @children = ();
  if (defined $self->position) {
    if ($self->is_pool && !$self->tag_index) {
      foreach my $tag_index (sort keys %{$self->data->{$DATA_SECTION}->{$self->position}}) {
        my $init = $self->init_args();
        $init->{'tag_index'} = $tag_index;
        #$init->{'data'}     = $self->data;
        push @children, __PACKAGE__->new($init);
      }
    }
  } else {
    foreach my $position (sort keys %{$self->data->{$DATA_SECTION}}) {
      my $init = $self->init_args();
      $init->{'position'} = $position;
      #$init->{'data'}     = $self->data;
      push @children, __PACKAGE__->new($init);
    }
  }
  return \@children;
}

=head2 library_id

Read-only accessor, not possible to set from the constructor.

=cut
has 'library_id' =>       (isa             => 'Maybe[Int]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_library_id {
  my $self = shift;
  my $id;
  if($self->_entity) {
    $id = $self->_entity->{$LIB_ID_COLUMN};
  }
  $id ||= undef;
  return $id;
}

=head2 library_name

Read-only accessor, not possible to set from the constructor.

=cut
has 'library_name' =>     (isa             => 'Maybe[Str]',
                           is              => 'ro',
                           init_arg        => undef,
                           lazy_build      => 1,
                          );
sub _build_library_name {
  my $self = shift;
  my $name;
  if($self->_entity) {
    $name = $self->_entity->{$LIB_NAME_COLUMN};
  }
  $name ||= undef;
  return $name;
}

=head2 children

Method returning a list objects that are associated with this object
and belong to the next (one lower) level. An empty list for a non-pool lane and for a plex.
For a pooled lane contains plex-level objects. On a batch level, when the position 
accessor is not set, returns lane level objects.

=cut
sub children {
  my $self = shift;
  return @{$self->_sschildren()};
}

has '_template_text' => (
  'isa'       => 'Str',
  'is'        => 'ro',
  #'metaclass' => 'NoGetopt',
  'lazy'      =>1,
  'builder'   => '_build__template_text',
);




sub _build__template_text {
  my $tt = <<'END_OF_TEMPLATE';
[% 
   num_fields = additional_data_fields.size + 3;
   IF has_index; num_fields=num_fields+1; END;
   IF multiple_lanes; num_fields=num_fields+1; END;  
   IF !separator.defined; separator = ','; END;
-%]
[Header][% all_empty %]
[% FOREACH key IN d.Header.keys -%]
[% key %],[% d.Header.$key %][% separator.repeat(num_fields-1) %]
[% END -%]
[% separator.repeat(num_fields) -%]

[Reads][% separator.repeat(num_fields) %]
[% FOREACH read IN d.Reads -%]
[% read %][% separator.repeat(num_fields) %]
[% END -%]
[% separator.repeat(num_fields) -%]

[Settings][% separator.repeat(num_fields) %]
[% separator.repeat(num_fields) -%]

[Manifests][% separator.repeat(num_fields) %]
[% separator.repeat(num_fields) -%]

[Data][% separator.repeat(num_fields) %]
[% IF multiple_lanes %]Lanes,[% END -%]
Index,Sample_ID,Sample_Name,GenomeFolder,
[% FOREACH lane IN d.Data.keys.nsort -%]
[% FOREACH index IN d.Data.${lane}.keys.sort -%]
[% IF multiple_lanes; lane _ separator; END -%]
[% index_string = separator;
   IF index != not_indexed_flag;
     index_string = index _ separator;
   END;
   index_string; -%]
[%- d.Data.${lane}.${index}.Sample_ID %],
[%- d.Data.${lane}.${index}.Sample_Name %],
[%- d.Data.${lane}.${index}.GenomeFolder %],
[% IF additional_data_fields;
     FOREACH other_column IN additional_data_fields.sort;d.Data.${lane}.${index}.${other_column} _ ',';END;END; %]
[% END; END -%]
END_OF_TEMPLATE
  ##no critic(RegularExpressions::RequireExtendedFormatting)
  $tt =~s/(?<!\r)\n/\r\n/smg; # we need CRLF not just LF
  ##use critic
  return $tt;
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
    croak sprintf 'Supplied id_run %i does not match "Experiment Name" %s',
                  $self->id_run, $id_run;
  }

  #What are compulsory Data section? - check for them
  #Do we have at least one lane? - should be numbers as well
  #Do we have a mixture of indices and non-indexed in one lane?
  #Are all indices numbers?
  $self->_assign_defaults($data);
  return;
}

sub _assign_defaults {
  my ($self, $d) = @_;
  my $now = DateTime->now();
  if (!$d->{'Header'}->{'Investigator Name'}) {
    $d->{'Header'}->{'Investigator Name'} = q[unknown];
  }
  if (!$d->{'Header'}->{'Experiment Name'}) {
    my $e = $self->chip_id || $self->file_name || q[unknown];
    $d->{'Header'}->{'Experiment Name'} = join q[_], $e, $now;
  }
  if (!$d->{'Header'}->{'Project Name'}) {
    $d->{'Header'}->{'Project Name'} = q[unknown];
  }
  if (!$d->{'Header'}->{'Date'}) {
    $d->{'Header'}->{'Date'} = $now;
  }
  if (!$d->{'Header'}->{'Workflow'}) {
    $d->{'Header'}->{'Workflow'} = $DEFAULT_WORKFLOW;
  }
  if (!$d->{'Header'}->{'Chemistry'}) {
    $d->{'Header'}->{'Chemistry'} = $DEFAULT_CHEMISTRY;
  }
  return;
}

sub _has_index {
  my $self = shift;
  foreach my $lane_num (keys %{$self->{'Data'}}) {
    my @indices = keys %{$self->{'Data'}->{$lane_num}};
    if (any {/^[ATCG]+$/smxi} @indices) {
      return 1;
    }
  }
  return 0;
}

sub _data_fields {
  my $self = shift;
  my $fields = {'Lane}' => 1, 'Index' => 1,};
  foreach my $lane_num (keys %{$self->{'Data'}}) {
    foreach my $field ( keys %{$self->{'Data'}->{$lane_num}}) {
      $fields->{$field} = 1;
    }
  }
  return keys %{$fields};
}

=head2 generate

Generates a samplesheet

=cut
sub generate {
  my ($self, @processargs) = @_;
  my $tt=Template->new();
  my $template = $self->_template_text;
  my @data_fields = $self->_data_fields();
  my @non_default_data_fields =
    grep {$_ !~ /Lane|Index|Sample_ID|Sample_Name|GenomeFolder/smx } @data_fields;
  my $multiple_lanes = scalar(keys %{$self->data->{'Data'}}) == 1 ? 0 : 1;
  $tt->process(\$template,{
    d                      => $self->data,
    has_index              => $self->_has_index(),
    additional_data_fields => \@non_default_data_fields,
    separator              => $SAMPLESHEET_RECORD_SEPARATOR,
    multiple_lanes         => $multiple_lanes,
    not_indexed_flag       => $NOT_INDEXED_FLAG,
  }, $self->path,@processargs)||croak $tt->error();
  return;
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

=item English

=item Readonly

=item File::Slurp

=item Template

=item Readonly

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

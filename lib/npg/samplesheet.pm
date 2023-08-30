package npg::samplesheet;

use Moose;
use namespace::autoclean;
use Class::Load qw(load_class);
use Template;
use Carp qw(carp croak confess);
use List::MoreUtils qw(any uniq);
use URI::Escape qw(uri_escape_utf8);
use Readonly;
use open q(:encoding(UTF8));

use npg_tracking::Schema;
use st::api::lims;
use st::api::lims::samplesheet;
use npg_tracking::util::config qw(get_config_staging_areas);
use npg_tracking::util::abs_path qw(abs_path);

with 'npg_tracking::glossary::run';

our $VERSION = '0';

=head1 NAME

npg::samplesheet

=head1 VERSION

=head1 SYNOPSIS

  my $ss = npg::samplesheet->new(id_run => 7007); # default samplesheet
  $ss->process(); # samplesheet is written to a file in the current directory

  my $result = q();
  $ss = npg::samplesheet->new(extend => 1, lims => \@lims, output=> \$result);
  $ss->process(); # samplesheet data is in the $result variable

  $ss = npg::samplesheet->new(extend => 1, lims => \@lims, output=> 'path/to/myss.csv');
  $ss->process(); # samplesheet is written to a file (path/to/myss.csv)
  

=head1 DESCRIPTION

Class for creating samplesheets to cache LIMs data used during analysis.

The format of the samplesheet follows Illumina's guidelines, see
http://emea.support.illumina.com/downloads/miseq_sample_sheet_quick_reference_guide_15028392.html

If the 'extend' flag is set, custom fields are added to the default Illumina
format.

By setting the 'lims' attribute and the 'extend' flag in the constructor it is
possible to combine data from multiple runs in a single samplesheet. In this case
an extra custom field, 'id_run', is added to the samplesheet and two default
fields, 'Index' and 'Index2' are removed. Information about tag sequences is
still retained in the relevant custom fields.

=head1 SUBROUTINES/METHODS

=cut

my$config=get_config_staging_areas();
Readonly::Scalar my $SAMPLESHEET_PATH => $config->{'samplesheets'}||q(samplesheets/);
Readonly::Scalar my $MIN_COLUMN_NUM   => 3;
Readonly::Scalar my $DEFAULT_LIMS_DRIVER_TYPE => 'ml_warehouse';

##################################################################
####################### Public attributes ########################
##################################################################

=head2 lims_driver_type

LIMs driver type to use, defaults to ml_warehouse.

=cut

has 'lims_driver_type' => (
  'isa'      => 'Str',
  'required' => 0,
  'is'       => 'ro',
  'default'  => $DEFAULT_LIMS_DRIVER_TYPE,
);

=head2 id_run

An optional attribute

=cut

has '+id_run' => (
  'lazy_build' => 1,
  'required'   => 0,
);
sub _build_id_run {
  my ($self) = @_;
  if($self->has_tracking_run()){
    return $self->run()->id_run();
  }
  confess 'id_run or a run is required';
}

=head2 samplesheet_path

An optional attribute.

=cut

has 'samplesheet_path' => (
  'isa'        => 'Str',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build_samplesheet_path {
  if($ENV{dev} and not $ENV{dev}=~/live/smix){
    my ($suffix) = $ENV{dev}=~/(\w+)/smix;
    return $SAMPLESHEET_PATH . $suffix . q(/);
  }
  return $SAMPLESHEET_PATH;
}

=head2 extend

A boolean attribute, false by default.
If false, a samlesheet similar to Illumina one for a MiSeq run
is generated. If true, the Illumina-style header of the file is removed
and the data section is extended by columns for extra LIMs data.

=cut

has 'extend' => (
  'isa' => 'Bool',
  'is'  => 'ro',
);

=head2 mkfastq

A boolean attribute, false by default.

=cut

has 'mkfastq' => (
  'isa' => 'Bool',
  'is'  => 'ro',
);

=head2 repository

An attribute, a path to the root of the reference repository.

=cut

has 'repository' => ( 'isa' => 'Str', 'is' => 'ro' );

=head2 npg_tracking_schema

An attribute, DBIx Schema object for the tracking database.

=cut

has 'npg_tracking_schema' => (
  'isa'        => 'npg_tracking::Schema',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build_npg_tracking_schema {
  my ($self) = @_;
  my$s = $self->has_tracking_run() ?
         $self->run()->result_source()->schema() :
         npg_tracking::Schema->connect();
  return $s
}

=head2 run

An attribute, DBIx object for a row in the run table of the tracking database.

=cut

has 'run' => (
  'isa'        => 'npg_tracking::Schema::Result::Run',
  'is'         => 'ro',
  'predicate'  => 'has_tracking_run',
  'lazy_build' => 1,
);
sub _build_run {
  my $self=shift;
  return $self->npg_tracking_schema->resultset(q(Run))->find($self->id_run);
}

=head2 lims

An attribute, an array of st::api::lims type objects.

This attribute should normally be provided by the caller via the
constuctor. If the attribute is not provided, it it built automatically.

=cut

has 'lims' => (
  'isa'        => 'ArrayRef[st::api::lims]',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build_lims {
  my $self=shift;
  my $id = $self->run->batch_id;
  return [st::api::lims->new(
            batch_id => $id,
            driver_type => $self->lims_driver_type)->children];
};

=head2 output

An attribute, a file path or handle or a scalar reference.

=cut

has 'output' => (
  'is'         => 'ro',
  'lazy_build' => 1,
  'isa'        => 'Str | FileHandle | ScalarRef',
);
sub _build_output {
  my ($self) = @_;
  my $reagent_kit = $self->run->flowcell_id();
  #MiSeq looks for samplesheet name without padded zeroes in the reagent kit suffix....
  $reagent_kit =~ s/(?<!\d)0*(\d+)-0*(\d+)(V\d+)?\s*\z/sprintf(q(%07d-%d%s),$1,$2,uc($3||''))/esmxg;
  return $self->samplesheet_path . $reagent_kit . q(.csv);
}

=head2 limsreflist

=cut

has _limsreflist => (
        'traits'     => ['Array'],
        'is'         => 'ro',
        'isa'        => 'ArrayRef[ArrayRef]',
        'lazy_build' => 1,
        'handles' => {
          limsreflist => 'elements',
        },
);
sub _build__limsreflist {
  my $self = shift;
  my @lims;

  for my $l (@{$self->lims}) {
    for my $tmpl ( $l->is_pool ? $l->children : ($l) ) {

      my $ref = q[];
      my @row = ();
      if ($self->_multiple_lanes) {
        push @row, $tmpl->position;
      }

      foreach my $attr (qw/library_id sample_publishable_name/) {
        my $value = _csv_compatible_value($tmpl->$attr);
        if (!$value) {
          croak sprintf '%s is not available for position %i %s',
            $attr, $tmpl->position,
            defined $tmpl->tag_index ? 'tag index ' . $tmpl->tag_index : q[];
        }
        if ($self->mkfastq) {
          # when making a samplesheet for mkfastq, replace value by run_position
          $value = $self->id_run . q[_] . $tmpl->position;
          if($self->_index_read) {
            # add the tag sequences
            ##no critic ( ControlStructures::ProhibitDeepNests)
            if ($tmpl->tag_sequences->[0]) {
              $value .= q[_] . $tmpl->tag_sequences->[0];
              if ($self->_dual_index) {
                $value .= $tmpl->tag_sequences->[1] || q[];
              }
            }
            ##use critic
          }
        }
        push @row, $value;
      }

      push @row, $ref;

      if($self->_index_read) {
        push @row, $tmpl->tag_sequences->[0] || q[];
        if ($self->_dual_index) {
          push @row, $tmpl->tag_sequences->[1] || q[];
        }
      }
      if ($self->extend) {
        push @row, map { _csv_compatible_value($tmpl->$_) } @{$self->_additional_columns};
      }

      if ($self->mkfastq) {
        # when making a samplesheet for mkfastq skip controls
        if (!$tmpl->is_control) {
          push @lims, \@row;
        }
      } else {
        push @lims, \@row;
      }

    }
  }
  return \@lims;
}

=head2 study_names 

=cut

has 'study_names' => (
  'isa'        => 'ArrayRef',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build_study_names {
  my $self = shift;
  my $studies = {};
  foreach my $l (@{$self->lims}) {
    foreach my $name ($l->study_names) {
      $studies->{_csv_compatible_value($name)} = 1;
    }
  }
  my @names = sort keys %{$studies};
  return \@names;
}

##################################################################
####################### Public methods ###########################
##################################################################

=head2 process

Generates a samplesheet.

=cut

sub process {
  my ($self, @processargs) = @_;

  my %processargs = @processargs==1 ? %{$processargs[0]} : @processargs;
  if (not exists $processargs{'binmode'}){
    $processargs{'binmode'} = ':utf8';
  }
  my $tt=Template->new();

  my $template = $self->_template_text;

  my $stash = {};
  $stash->{'separator'} = $st::api::lims::samplesheet::SAMPLESHEET_RECORD_SEPARATOR;
  $stash->{'with_header'}         = !$self->extend;
  $stash->{'limsa'}               = [$self->limsreflist];
  $stash->{'has_multiple_lanes'}  = $self->_multiple_lanes;
  $stash->{'has_index_read'}      = $self->_index_read;
  $stash->{'has_dual_index'}      = $self->_dual_index;
  $stash->{'additional_columns'}  = $self->_additional_columns;
  $stash->{'num_sep'}             = $self->_num_columns;
  $stash->{'project_name'}        = join(q[ ], @{$self->study_names}) || 'unknown';
  if (!$self->extend) {
    $stash->{'run'}               = $self->run;
    $stash->{'pendingstatus'}     =
    $self->run->run_statuses->search({q(run_status_dict.description)=>q(run pending)},{join=>q(run_status_dict)})->first;
  }

  $tt->process(\$template, $stash, $self->output, \%processargs) || croak $tt->error();

  return;
}

##################################################################
####################### Private attributes #######################
##################################################################

has '_index_read' => (
  'isa'        => 'Bool',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build__index_read {
  my $self = shift;
  return any {$_->is_pool} @{$self->lims};
}

has '_dual_index' => (
  'isa'        => 'Bool',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build__dual_index {
  my $self=shift;
  if ($self->_index_read) {
    for my $l ( @{$self->lims} ) {
      if ($l->is_pool && any { scalar @{$_->tag_sequences} == 2 } $l->children) {
        return 1;
      }
    }
  }
  return 0;
}

has '_multiple_lanes' => (
  'isa'        => 'Bool',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build__multiple_lanes {
  my $self = shift;
  # when making a samplesheet for mkfastq we want the Lane column,
  # so assume there are multiple lanes
  return ($self->mkfastq || (scalar(@{$self->lims}) > 1));
}

has '_add_id_run_column' => (
  'isa'        => 'Bool',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build__add_id_run_column {
  my $self = shift;

  my $num_unique_runs = scalar uniq
                               grep { $_ }
                               map  { $_->id_run }
                               grep { $_->can('id_run') }
                               @{$self->lims};

  $num_unique_runs > 1 and ($self->has_id_run() or $self->has_tracking_run()) and
    croak 'Run data set (id_run or run) where LIMs data are for multiple runs';

  not $self->extend and $num_unique_runs > 1 and
    croak 'Cannot have data for multiple runs in a default samplesheet';

  return ($num_unique_runs > 1);
}

has '_additional_columns' => (
  'isa'        => 'ArrayRef',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build__additional_columns {
  my $self = shift;
  my @names = ();
  if ($self->extend) {
    @names = grep {$_ ne 'library_id'} st::api::lims->driver_method_list();  #library_id goes to SAMPLE_ID
    push @names, 'tag_index';
    $self->_add_id_run_column and push @names, 'id_run';
    @names = sort @names;
  }
  return \@names;
}

has '_num_columns' => (
  'isa'        => 'Int',
  'is'         => 'ro',
  'lazy_build' => 1,
);
sub _build__num_columns {
  my $self = shift;

  my $num_columns = $MIN_COLUMN_NUM;
  if ($self->_index_read) {
    $num_columns ++; # a column for index
  }
  if ($self->_multiple_lanes) {
    $num_columns ++; # a column for lane number
  }
  if ($self->extend) {
    $num_columns += scalar @{$self->_additional_columns};
  }
  return $num_columns;
}

has '_template_text' => (
  'isa'        => 'Str',
  'is'         => 'ro',
  'lazy_build' =>1,
);
sub _build__template_text {

  my $tt = <<'END_OF_TEMPLATE';
[% one_less_sep = num_sep; IF num_sep > 1; one_less_sep = num_sep - 1; END -%]
[% IF with_header -%]
[Header][% separator.repeat(num_sep) %]
Investigator Name,[% pendingstatus.user.username %][% separator.repeat(one_less_sep) %]
Project Name[% separator _ project_name %][% separator.repeat(one_less_sep) %]
Experiment Name[% separator _ run.id_run %][% separator.repeat(one_less_sep) %]
Date[% separator _ pendingstatus.date %][% separator.repeat(one_less_sep) %]
Workflow[% separator %]GenerateFASTQ[% separator.repeat(one_less_sep) %]
Chemistry[% separator %][% IF has_dual_index %]Amplicon[% ELSE %]Default[% END -%]
[% separator.repeat(one_less_sep) %]
[% separator.repeat(num_sep) -%]

[Reads][% separator.repeat(num_sep) %]
[% run.forward_read.expected_cycle_count; separator.repeat(num_sep) %]
[% SET rcycles = run.reverse_read.expected_cycle_count -%]
[% IF rcycles -%]
[% rcycles %][% separator.repeat(num_sep) %]
[% END -%]
[% separator.repeat(num_sep) -%]

[Settings][% separator.repeat(num_sep) %]
[% separator.repeat(num_sep) %]
[Manifests][% separator.repeat(num_sep) %]
[% separator.repeat(num_sep); %]
[% END -%]
[Data][% separator.repeat(num_sep) %]
[% 
   colnames = ['Sample_ID', 'Sample_Name', 'GenomeFolder'];
   IF has_index_read; colnames.push('Index') ;END;
   IF has_dual_index; colnames.push('Index2'); END;
   IF has_multiple_lanes; colnames.unshift('Lane'); END;
   colnames.join(separator);
   separator;
   IF additional_columns.size; additional_columns.join(separator);separator;END;
%]
[% FOREACH values_list = limsa; values_list.join(separator); separator; %]
[% END -%]
END_OF_TEMPLATE
  ##no critic(RegularExpressions::RequireExtendedFormatting)
  $tt =~s/(?<!\r)\n/\r\n/smg; # we need CRLF not just LF
  ##use critic
  return $tt;
}

##################################################################
####################### Private methods ##########################
##################################################################

sub _csv_compatible_value {
  my $value = shift;

  if ($value) {
    my $as = $st::api::lims::samplesheet::SAMPLESHEET_ARRAY_SEPARATOR;
    my $hs = $st::api::lims::samplesheet::SAMPLESHEET_HASH_SEPARATOR;
    my $type = ref $value;
    if ($type) {
      if ($type eq 'ARRAY') {
        $value = join $as, @{$value};
      } elsif ($type eq 'HASH') {
        my @tmp = ();
        while (my ($key,$val) = each %{$value}) {
          push @tmp, join $hs, $key, $val;
        }
        $value = join $as, sort @tmp;
      } else {
      croak "Do not know how to serialize $type to a samplesheet";
      }
    } else {
      $value = uri_escape_utf8($value);
      $value =~ s/\%20/ /smxg;
      $value =~ s/\%28/(/smxg;
      $value =~ s/\%29/)/smxg;
      #value is URI escaped other than spaces and brackets
    }
  }
  if (!defined $value) {
    $value = q[];
  }
  return $value;
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 process

=head1 DEPENDENCIES

=over

=item Moose

=item namespace::autoclean

=item Class::Load

=item Template

=item Readonly

=item Carp

=item List::MoreUtils

=item URI::Escape

=item open

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019,2020 Genome Research Ltd.

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


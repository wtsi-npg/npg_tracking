#########
# Author:        David K. Jackson
# Created:       2011-11-04
#

package npg::samplesheet;

use Moose;
use Template;
use Carp;
use English qw(-no_match_vars);
use List::MoreUtils qw/any/;
use URI::Escape qw(uri_escape_utf8);
use Readonly;
use npg_tracking::Schema;
use st::api::lims;
use st::api::lims::samplesheet;
use npg_tracking::data::reference;
use Cwd qw(abs_path);

our $VERSION = '0';

=head1 NAME

npg::samplesheet

=head1 VERSION

=head1 SYNOPSIS

  my $samplesheet = npg::samplesheet->new(id_run => 7007);
  $samplesheet->process;

=head1 DESCRIPTION

Class for creating a MiSeq samplesheet using NPG tracking info and Sequencescape LIMs info.

=head1 SUBROUTINES/METHODS

=cut

Readonly::Scalar our $REP_ROOT => q(/nfs/sf45);
Readonly::Scalar our $SAMPLESHEET_PATH => q(/nfs/sf49/ILorHSorMS_sf49/samplesheets/);
Readonly::Scalar our $DEFAULT_FALLBACK_REFERENCE_SPECIES=> q(PhiX);
Readonly::Scalar my  $MIN_COLUMN_NUM => 3;
Readonly::Scalar my  $DUAL_INDEX_TAG_LENGTH => 16;

with 'MooseX::Getopt';
with 'npg_tracking::glossary::run';
has '+id_run' => (
  'lazy_build' => 1,
  'required' => 0,
);

sub _build_id_run {
  my ($self) = @_;
  if($self->has_run()){
    return $self->run()->id_run();
  }
  croak 'id_run or a run is required';
}

has 'samplesheet_path' => (
  'isa' => 'Str',
  'is' => 'ro',
  'lazy_build' => 1,
);
sub _build_samplesheet_path {
  if($ENV{dev} and not $ENV{dev}=~/live/smix){
    my ($suffix) = $ENV{dev}=~/(\w+)/smix;
    return $SAMPLESHEET_PATH . $suffix . q(/);
  }
  return $SAMPLESHEET_PATH;
}

has 'extend' => ( 'isa' => 'Bool', 'is' => 'ro',);

has 'dual_index_size' => (
  'isa' => 'Int',
  'is' => 'ro',
  'lazy_build' => 1,
);
sub _build_dual_index_size {
  my $self=shift;
  if ($self->_index_read) {
    for my $l (@{$self->lims}) {
      for my $tmpl ( $l->is_pool ? $l->children : ($l) ) {
        if ($tmpl->tag_sequence && length($tmpl->tag_sequence) == $DUAL_INDEX_TAG_LENGTH) {
          return $DUAL_INDEX_TAG_LENGTH/2;
        }
      }
    }
  }
  return 0;
}

has 'repository' => ( 'isa' => 'Str', 'is' => 'ro', default => $REP_ROOT );

has 'npg_tracking_schema' => (
  'isa' => 'npg_tracking::Schema',
  'is' => 'ro',
  'lazy_build' => 1,
  'metaclass' => 'NoGetopt',
);
sub _build_npg_tracking_schema {
  my ($self) = @_;
  my$s = $self->has_run() ? $self->run()->result_source()->schema() : npg_tracking::Schema->connect();
  return $s
}

has 'run' => (
  'isa' => 'npg_tracking::Schema::Result::Run',
  'is' => 'ro',
  'lazy_build' => 1,
  'metaclass' => 'NoGetopt',
);
sub _build_run { my $self=shift; my$r=$self->npg_tracking_schema->resultset(q(Run))->find($self->id_run); return $r;}

has lims => (
  'isa' => 'ArrayRef[st::api::lims]',
  'is' => 'ro',
  'lazy_build' => 1,
  'metaclass' => 'NoGetopt',
);
sub _build_lims {
  my $self=shift;
  my $id = $self->run->batch_id;
  if ($id=~/\A\d{13}\z/smx) {
    ##no critic (ProhibitStringyEval)
    eval 'require st::api::lims::warehouse' or do { croak $EVAL_ERROR;} ;
    ##use critic
    return [st::api::lims->new( position=>1, driver => st::api::lims::warehouse->new( position=>1, tube_ean13_barcode=>$id) )];
  }
  return [st::api::lims->new( batch_id=> $id )->children];
};

has output => (
  'is'  => 'ro',
  'lazy_build' => 1,
  'isa' => 'Str | FileHandle | ScalarRef',
);
sub _build_output {
  my ($self) = @_;
  my $reagent_kit = $self->run->flowcell_id();
  $reagent_kit =~ s/(?<!\d)0*(\d+)-0*(\d+)(V\d+)?\s*\z/sprintf(q(%07d-%d%s),$1,$2,uc($3||''))/esmxg; #MiSeq looks for samplesheet name without padded zeroes in the reagent kit suffix....
  return $self->samplesheet_path . $reagent_kit . q(.csv);
}

has fallback_reference => (
  'is'  => 'ro',
  'lazy_build' => 1,
  'isa' => 'Str',
);
sub _build_fallback_reference {
  my ($self) = @_;
  return Moose::Meta::Class->create_anon_class(
    roles=>[qw(npg_tracking::data::reference::find)]
  )->new_object(
    species=>$DEFAULT_FALLBACK_REFERENCE_SPECIES,
    aligner => q(fasta),
    ($self->repository ? ('repository' => $self->repository) : ()),
  )->ref_info->ref_path;
}

has _limsreflist => (
        'traits'  => ['Array'],
        'is'      => 'ro',
        'isa'     => 'ArrayRef[ArrayRef]',
        'lazy_build'    => 1,
        'handles' => {
            limsreflist    => 'elements',
        },
);
sub _build__limsreflist {
  my $self = shift;
  my @lims;

  for my $l (@{$self->lims}) {
    for my $tmpl ( $l->is_pool ? $l->children : ($l) ) {

      my $dataref = npg_tracking::data::reference->new(
              ($self->repository ? ('repository' => $self->repository) : ()),
              aligner => q(fasta),
              lims=>$tmpl, position=>$tmpl->position, id_run=>$self->run->id_run
      );
      my @refs = @{$dataref->refs ||[]};
      my $ref = shift @refs;
      $ref ||= $self->fallback_reference();
      $ref=~s{(/fasta/).*$}{$1}smgx;
      $ref=~s{(/references)}{}smgx;
      my$repository= abs_path $dataref->repository();
      $ref=~s{^$repository}{C:\\Illumina\\MiSeq Reporter\\Genomes\\WTSI_references}smgx;
      $ref=~s{/}{\\}smgx;

      my @row = ();
      if ($self->_multiple_lanes) {
        push @row, $tmpl->position;
      }
      push @row, $tmpl->library_id;
      push @row, $tmpl->sample_publishable_name;
      push @row, $ref;
      if($self->_index_read) {
        if ($tmpl->tag_sequence && length($tmpl->tag_sequence) == (2 * $self->dual_index_size())) {
          push @row, substr $tmpl->tag_sequence, 0, $self->dual_index_size();
          push @row, substr $tmpl->tag_sequence, $self->dual_index_size();
        } else {
          push @row, $tmpl->tag_sequence || q[];
          if ($self->dual_index_size) { push @row, q[]; }
        }
      }
      if ($self->extend) {
        push @row, map { _csv_compatible_value($tmpl->$_) } @{$self->_additional_columns};
      }
      push @lims, \@row;
    }
  }
  return \@lims;
}

has study_names => (isa => 'ArrayRef', 'is'  => 'ro', 'lazy_build' => 1,);
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

has _index_read => (isa => 'Bool', 'is'  => 'ro', 'lazy_build' => 1,);
sub _build__index_read {
  my $self = shift;
  return any {$_->is_pool} @{$self->lims};
}

has _multiple_lanes => (isa => 'Bool', 'is'  => 'ro', 'lazy_build' => 1,);
sub _build__multiple_lanes {
  my $self = shift;
  return scalar(@{$self->lims}) > 1;
}

has _additional_columns => ('isa' => 'ArrayRef', 'is'  => 'ro', 'lazy_build' => 1,);
sub _build__additional_columns {
  my $self = shift;
  my @names = ();
  if ($self->extend) {
    @names = grep {$_ ne 'library_id'} st::api::lims::driver_method_list();  #library_id goes to SAMPLE_ID
    push @names, 'tag_index';
    @names = sort @names;
  }
  return \@names;
}

has _num_columns => ('isa' => 'Int', 'is'  => 'ro', 'lazy_build' => 1,);
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
        while (my ($key,$val) = each $value) {
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

has template_text => (
  'isa' => 'Str',
  'is' => 'ro',
  'metaclass' => 'NoGetopt',
  'lazy_build' =>1,
);
sub _build_template_text {

  my $tt = <<'END_OF_TEMPLATE';
[% one_less_sep = num_sep; IF num_sep > 1; one_less_sep = num_sep - 1; END -%]
[Header][% separator.repeat(num_sep) %]
Investigator Name,[% pendingstatus.user.username %][% separator.repeat(one_less_sep) %]
Project Name[% separator _ project_name %][% separator.repeat(one_less_sep) %]
Experiment Name[% separator _ run.id_run %][% separator.repeat(one_less_sep) %]
Date[% separator _ pendingstatus.date %][% separator.repeat(one_less_sep) %]
Workflow[% separator %]LibraryQC[% separator.repeat(one_less_sep) %]
Chemistry[% separator %][% IF has_dual_index_size %]Amplicon[% ELSE %]Default[% END -%]
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
[% separator.repeat(num_sep) -%]

[Data][% separator.repeat(num_sep) %]
[% 
   colnames = ['Sample_ID', 'Sample_Name', 'GenomeFolder'];
   IF has_index_read; colnames.push('Index') ;END;
   IF has_dual_index_size; colnames.push('Index2'); END;
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

sub process {
  my ($self, @processargs) = @_;
  my %processargs = @processargs==1 ? %{$processargs[0]} : @processargs;
  if (not exists $processargs{'binmode'}){
    $processargs{'binmode'} = ':utf8';
  }
  my$tt=Template->new();

  my $template = $self->template_text;
  my $ir = $self->_index_read;
  my $ml = $self->_multiple_lanes;
  my $ac = $self->_additional_columns;
  my $nc = $self->_num_columns;

  $tt->process(\$template,{
    run                =>$self->run,
    pendingstatus      =>
      $self->run->run_statuses->search({q(run_status_dict.description)=>q(run pending)},{join=>q(run_status_dict)})->first,
    limsa              => [$self->limsreflist],
    separator          => $st::api::lims::samplesheet::SAMPLESHEET_RECORD_SEPARATOR,
    has_multiple_lanes => $ml,
    has_index_read     => $ir,
    has_dual_index_size     => $self->dual_index_size,
    additional_columns => $ac,
    num_sep            => $nc,
    project_name       => join(q[ ], @{$self->study_names}) || 'unknown',
  }, $self->output, \%processargs) || croak $tt->error();
  return;
}

no Moose;
1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 process

=head1 DEPENDENCIES

=over

=item Moose

=item Template

=item Readonly

=item Carp

=item List::MoreUtils

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by David K. Jackson 

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


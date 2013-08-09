#########
# Author:        David K. Jackson
# Maintainer:    $Author: mg8 $
# Created:       2011-11-04
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# Id:            $Id: samplesheet.pm 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg/samplesheet.pm $
#

package npg::samplesheet;
use Moose;
use Template;
use Carp;
use English qw(-no_match_vars);

use npg_tracking::Schema;
use st::api::lims;
use npg_tracking::data::reference;

use Readonly; Readonly::Scalar our $VERSION    => do { my ($r) = q$Revision: 16549 $ =~ /(\d+)/smx; $r; };

=head1 NAME

npg::samplesheet

=head1 VERSION

$Revision: 16549 $

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
  'isa' => 'st::api::lims',
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
    return st::api::lims->new( position=>1, driver => st::api::lims::warehouse->new( position=>1, tube_ean13_barcode=>$id) );
  }
  return st::api::lims->new( batch_id=> $id, position=>1, );
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
        'isa'     => 'ArrayRef[HashRef]',
        'lazy_build'    => 1,
        'handles' => {
            limsreflist    => 'elements',
        },
);
sub _build__limsreflist {
          my $self = shift;
          my @lims;
          my $l = $self->lims;
          for my $tmpl ( $l->associated_lims ? $l->associated_lims : ($l) ){
            my @refs = @{npg_tracking::data::reference->new(
              ($self->repository ? ('repository' => $self->repository) : ()),
              aligner => q(fasta),
              lims=>$tmpl, position=>$tmpl->position, id_run=>$self->run->id_run
            )->refs ||[]};
            my $ref = shift @refs;
            $ref ||= $self->fallback_reference();
            $ref=~s{(/fasta/).*$}{$1}smgx;
            $ref=~s{(/references)}{}smgx;
            $ref=~s{^/nfs/sf(\d+)}{C:\\Illumina\\MiSeq Reporter\\Genomes\\WTSI_references}smgx;
            $ref=~s{/}{\\}smgx;
            my %h;
            $h{'library_id'} = $tmpl->library_id;
            $h{'sample_publishable_name'} = $tmpl->sample_publishable_name;
            $h{'tag_sequence'} = $tmpl->tag_sequence;
            $h{'reference_genome'} =  $ref;
            push @lims, \%h;
          }
          return \@lims;
};


has template_text => (
  'isa' => 'Str',
  'is' => 'ro',
  'metaclass' => 'NoGetopt',
  'lazy_build' =>1,
);
sub _build_template_text {
  my $tt = <<'END_OF_TEMPLATE';
[Header],,,,
Investigator Name,[% pendingstatus.user.username %],,,
Project Name,[% lims.study_names || 'unknown' %],,,
Experiment Name,[% run.id_run %],,,
Date,[% pendingstatus.date %],,,
Workflow,LibraryQC,,,
Chemistry,Default,,,
,,,,
[Reads],,,,
[% run.forward_read.expected_cycle_count %],,,,
[% SET rcycles = run.reverse_read.expected_cycle_count -%]
[% IF rcycles -%]
[% rcycles %],,,,
[% END -%]
,,,,
[Settings],,,,
,,,,
[Manifests],,,,
,,,,
[Data],,,,
[% IF limsa.max; -%]
Sample_ID,Sample_Name,GenomeFolder,Index,
[% ELSE -%]
Sample_ID,Sample_Name,GenomeFolder,,
[% END -%]
[%  FOREACH lim = limsa -%]
[%   lim.library_id %],[% lim.sample_publishable_name %],[% lim.reference_genome %],[% lim.tag_sequence %],
[%  END -%]
END_OF_TEMPLATE
  ##no critic(RegularExpressions::RequireExtendedFormatting)
  $tt =~s/(?<!\r)\n/\r\n/smg; # we need CRLF not just LF
  ##use critic
  return $tt;
}

sub process {
  my ($self, @processargs) = @_;
  my$tt=Template->new();
  my $template = $self->template_text;
  $tt->process(\$template,{
    run=>$self->run,
    pendingstatus=>$self->run->run_statuses->search({q(run_status_dict.description)=>q(run pending)},{join=>q(run_status_dict)})->first,
    lims=>$self->lims,
    limsa=>[$self->limsreflist]
  }, $self->output,@processargs)||croak $tt->error();
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

=item strict

=item warnings

=item Moose

=item Template

=item Readonly

=item Carp

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: David K. Jackson E<lt>david.jackson@sanger.ac.ukE<gt>

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


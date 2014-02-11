#########
# Author:        Marina Gourtovaia
# Maintainer:    $Author: mg8 $
# Created:       14 April 2009
# Last Modified: $Date: 2013-01-23 16:49:39 +0000 (Wed, 23 Jan 2013) $
# Id:            $Id: find.pm 16549 2013-01-23 16:49:39Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/lib/npg_tracking/data/reference/find.pm $
#

package npg_tracking::data::reference::find;

use strict;
use warnings;
use Moose::Role;
use Carp;
use English qw(-no_match_vars);
use File::Spec::Functions qw(catfile);
use Cwd qw(abs_path);
use Readonly;

use npg_tracking::data::reference::info;
use npg_tracking::util::messages;
use st::api::lims;

with qw/ npg_tracking::data::reference::list /;

our $VERSION = do { my ($r) = q$Revision: 16549 $ =~ /(\d+)/smx; $r; };

Readonly::Scalar our $NPG_DEFAULT_ALIGNER_OPTION => q{npg_default};
Readonly::Scalar our $MINUS_ONE                  => -1;

=head1 NAME

npg_tracking::data::reference::find

=head1 VERSION

$Revision: 16549 $

=head1 SYNOPSIS

An example of a class that implements this role

 package reference_user;
 use Moose;
 with qw(npg_tracking::data::reference::find);

 sub id_run   { return 1937; }
 sub position { return 1; }
 sub my_function { do something;}

 1;
 __END__

Using your class

 my $r_user = reference_user->new();
 $r_user->refs();
 my @messages = $r_user->messages->messages;

See npg_qc::autoqc::checks::insert_size for an example of using this role.

=head1 DESCRIPTION

Interface (Moose role) for retrieving a reference sequence for a lane or
a list of samples.

=head1 SUBROUTINES/METHODS

=cut


Readonly::Scalar our $ALIGNER          => q[bwa];
Readonly::Scalar our $STRAIN           => q[default];
Readonly::Scalar our $SUBSET           => q[all];
Readonly::Scalar our $PHIX             => q[PhiX];
Readonly::Array  our @REQUIRED_ACCESSORS  => qw/id_run position tag_index/;

=head2 reference_genome

Reference genome string in the format 'organism (strain)' as set in LIMS.
See npg_tracking::data::reference::list::short_report

=cut
has 'reference_genome'  => (isa             => 'Maybe[Str]',
                            is              => 'ro',
                            required        => 0,
                           );

=head2 species

Species name

=cut
has 'species'  => (isa             => 'Maybe[Str]',
                   is              => 'ro',
                   required        => 0,
                   writer          => '_set_species',
                   lazy_build      => 1,
                  );
sub _build_species {
  my $self = shift;

  my @a = $self->_parse_reference_genome;
  if (@a) {
    $self->_set_strain($a[1]);
    return $a[0];
  }

  if ($self->for_spike || $self->lims->is_control) {
    return $PHIX;
  }

  return;
}

=head2 strain

Strain, defaults to the default strain in the repository

=cut
has 'strain'=>    (isa             => 'Str',
                   is              => 'ro',
                   required        => 0,
                   writer          => '_set_strain',
                   lazy_build      => 1,
                  );
sub _build_strain {
  my $self = shift;
  my @a = $self->_parse_reference_genome;
  if (@a) {
    $self->_set_species($a[0]);
    return $a[1];
  }
  return $STRAIN;
}

=head2 subset

Subset (i.e., chromosome), defaults to all

=cut
has 'subset'=>    (isa             => 'Str',
                   is              => 'ro',
                   required        => 0,
                   default         => $SUBSET,
                  );

=head2 aligner

Aligner name, defaults to bwa

=cut
has 'aligner'  => (isa             => 'Str',
                   is              => 'ro',
                   required        => 0,
                   default         => $ALIGNER,
                  );

=head2 messages

An npg_tracking::util::messages object to log the messages

=cut
has 'messages' => (isa          => 'npg_tracking::util::messages',
                   is           => 'ro',
                   required     => 0,
                   default      => sub { npg_tracking::util::messages->new(); },
                  );

=head2 for_spike

A boolean flag inndicating whethe rth ereference is needed
for a spike rather than for the main content of the lane

=cut
has 'for_spike'  => (isa             => 'Bool',
                     is              => 'ro',
                     required        => 0,
                     default         => 0,
                    );

=head2 lims

An object providing access to the LIM system

=cut
has 'lims'      => (isa             => 'st::api::lims',
                    is              => 'ro',
                    required        => 0,
                    lazy_build      => 1,
                   );
sub _build_lims {
  my $self = shift;

  foreach my $method (@REQUIRED_ACCESSORS) {
    if (!$self->can($method)) {
      croak qq[Need '$method' accessor to access lims data];
    }
  }
  return st::api::lims->new(id_run => $self->id_run, position => $self->position, tag_index => $self->tag_index);
}

sub _abs_ref_path {
  my $path = shift;
  (my $name) = $path =~ /\/([^\/]+)$/smx;
  $path =~ s/$name$//smx;
  ##no critic (CodeLayout::ProhibitParensWithBuiltins)
  return join(q[/], abs_path($path), $name);
}

=head2 refs

A reference to a list of reference paths.
If no reference found, an empty list is returned.
Examine the messages attribute after calling this function.

The object consuming this role should have id_run and position fields defined.

=cut
sub refs {
  my $self = shift;

  my @refs = ();
  my $ref_hash = {};

  if ($self->reference_genome && $self->reference_genome eq $npg_tracking::data::reference::list::NO_ALIGNMENT_OPTION) {
    $self->messages->push($self->reference_genome);
    return \@refs;
  }

  if ($self->species) {
    push @refs, $self->_get_reference_path($self->species, $self->strain);
  } else {

    my $spiked_phix_index = $MINUS_ONE;
    if ($self->lims->is_pool && !$self->tag_index && $self->lims->spiked_phix_tag_index) {
      $spiked_phix_index = $self->lims->spiked_phix_tag_index;
    }

    my @alims = $self->lims->associated_lims;
    if (!@alims) {
      @alims = ($self->lims);
    }
    foreach my $lims (@alims) {
      if ($spiked_phix_index >= 0 && $spiked_phix_index == $lims->tag_index) {
        next;
      }
      my $path = $self->lims2ref($lims);
      if ($path) {
        $ref_hash->{_abs_ref_path($path)} = 1;
      }
    }
    @refs = keys %{$ref_hash};
  }
  @refs = map {_abs_ref_path($_)} @refs;
  return \@refs;
}

=head2 single_ref_found

Returns true if only one reference has been found.
Returns false if no references found or multiple references found.

=cut
sub single_ref_found {

  my $self = shift;
  carp 'This method is depricated. Please use the refs method and evaluate the size of the returned array.';

  my @refs;
  eval {
    @refs = @{$self->refs()};
    1;
  } or do {
    return 0;
  };
  if (!@refs || scalar @refs > 1) { return 0; }
  return 1;
}


=head2 reset_strain

Reset the strain value to default.

=cut
sub reset_strain {
  my $self = shift;
  $self->_set_strain($STRAIN);
  return;
}


=head2 ref_info

An npg_tracking::data::reference::info object or undef

=cut
sub ref_info {
  my $self = shift;

  my $refs = $self->refs();

  if (scalar @{$refs} == 1) {

    my $refpath = $refs->[0];
    my $ref = npg_tracking::data::reference::info->new(aligner => $self->aligner, ref_path => $refpath);
    my $opts_in = $ref->ref_path . q[.options];
    if (-e $opts_in) {
      ## no critic (RequireBriefOpen)
      open my $fh, q[<], $opts_in or croak qq[Cannot open $opts_in for reading: $ERRNO];
      my $found = q{};
      while (my $line = <$fh>) {
        if ($line ne qq[\n] && $line !~ /^\#/smx) {
          $line =~ s/^\s+//sxm;
          $line =~ s/\s+$//sxm;
          $found = $line;
          last;
       }
      }
      close $fh or croak qq[Cannot close $opts_in : $ERRNO];
      ## use critic

     $ref->aligner_options($found);

    }else{
       $ref->aligner_options($NPG_DEFAULT_ALIGNER_OPTION);
    }
    return $ref;
  }elsif(scalar @{$refs} > 1) {

     carp 'More than one reference found: '. (join q[;], @{$refs});
     return;
  }

  carp 'No reference found';
  return;
}


=head2 _get_reference_path

Returns a path to a binary reference (with a prefix of the reference itself). The organism should be one of the listed in our repository.

=cut
sub _get_reference_path {

  my ($self, $organism, $strain) = @_;

  if (!$organism) {
      croak q[Organism should be defined in arguments to _get_reference_path()];
  }

  $strain = $strain || $self->strain;

  # check that the directory for the chosen aligner exists
  my $base_dir = catfile($self->ref_repository, $organism, $strain, $self->subset);
  my $dir = catfile($base_dir, $self->aligner);

  if (!-e $dir) {
    ##no critic (ProhibitInterpolationOfLiterals)
    my $message = sprintf "Binary %s reference for %s, %s, %s does not exist; path tried %s",
        $self->aligner, $organism, $strain, $self->subset, $dir;
    ##use critic
    croak $message;
  }

  # read the fasta directory and get the file name with the reference
  return catfile($dir, $self->ref_file_prefix($base_dir));
}

=head2 lims2ref

Returns a path to a binary reference (with a prefix of the reference itself) for an asset object.
Undefined value returned if the search has failed

=cut
sub lims2ref {
  my ($self, $lims) = @_;

  my $ref_path = q[];
  my $preset_genome = $lims->reference_genome;
  my $no_alignment_option = $npg_tracking::data::reference::list::NO_ALIGNMENT_OPTION;
  my $no_alignment = $preset_genome && ($preset_genome eq $no_alignment_option) ? 1 : 0;
  if($no_alignment) {
    $self->messages->push($no_alignment_option);
  } else {
    if ($preset_genome) {
      $ref_path = $self->_preset_ref2ref_path($preset_genome);
    }
    if (!$ref_path) {
      my $taxon_id = $lims->organism_taxon_id;
      if ($taxon_id) {
        my $description = $self->taxonid2species($taxon_id);
        if ($description->{species})  {
          my $strain =  $description->{strain} ?  $description->{strain} : q[];
          $ref_path = $self->_get_reference_path($description->{species}, $strain);
        }
        if (!$ref_path) {
          $self->messages->push(qq[no reference for taxon id $taxon_id]);
        }
      } else {
        foreach my $name (($lims->library_name, $lims->sample_name)) {
          if ($name && $name =~ /phix/ismx ) {
            $ref_path = $self->_get_reference_path($PHIX);
            last;
          }
        }
      }
    }
  }

  return $ref_path;
}

sub _parse_reference_genome {
  my ($self, $reference_genome) = @_;
  $reference_genome ||= $self->reference_genome;
  if ($reference_genome) {
    my @a = $reference_genome =~/ (\S+) \s+ [(] (\S+) [)] /smx;
    if (scalar @a >= 2 && $a[0] && $a[1]) {
      return @a;
    }
  }
  return;
}

sub _preset_ref2ref_path {
  my ($self, $ref) = @_;

  if (!$ref) {
      croak q[Reference genome is not defined or empty];
  }

  my $ref_path = q[];
  my ($species, $strain) = $self->_parse_reference_genome($ref);
  if ($species && $strain) {
    $ref_path = $self->_get_reference_path($species, $strain);
  } else {
    $self->messages->push(qq[Incorrect reference genome format $ref]);
  }
  return $ref_path;
}

no Moose::Role;

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item Moose::Role

=item Carp

=item English

=item File::Spec::Functions

=item Readonly

=item Cwd

=item npg_tracking::util::messages

=item npg_tracking::data::reference::list

=item st::api::lims

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Author: Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2011 GRL, by Marina Gourtovaia

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

package npg_tracking::illumina::runfolder;

########
# 04 January 2018
# Copied from svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/data_handling/trunk/lib/srpipe/runfolder.pm
#

use Moose;
use namespace::autoclean;
use Carp;
use File::Spec;
use List::Util qw(first);

our $VERSION = '0';

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

npg_tracking::illumina::runfolder

=head1 SYNOPSIS

  my $oRunfolder = npg_tracking::illumina::runfolder->new(id_run => 3220);
  chdir $oRunfolder->runfolder_path;

  my $oRunfolder = npg_tracking::illumina::runfolder->new(runfolder_path => '/staging/IL29/incoming/090721_IL29_3379/');
  my $name = $oRunfolder->name; # 090721_IL29_3379
  my $id = $oRunfolder->id_run; # 3379

=head1 DESCRIPTION

Utility to locate and extract run information from the Illumina runfolder
directory heirarchy and from the files within it.

=head1 SUBROUTINES/METHODS

=cut

with 'npg_tracking::illumina::run::short_info';
with 'npg_tracking::illumina::run::folder';
with 'npg_tracking::illumina::run::long_info';

sub _build_run_folder {
  my $self = shift;
  ($self->_given_path or $self->has_id_run or $self->has_name)
      or croak 'Need a path to work out a run_folder';
  return first {$_ ne q()} reverse File::Spec->splitdir($self->runfolder_path);
}

=head2 path

Alias for runfolder_path

=cut

*path = \&runfolder_path;

around BUILDARGS => sub {
  my $orig  = shift;
  my $class = shift;

  my %h = ref $_[0] eq q{HASH} ? %{$_[0]} : @_;
  if ( exists $h{path} ) {
    $h{runfolder_path}=$h{path};
    return $class->$orig(\%h);
  } else {
    return $class->$orig(@_);
  }
};

__PACKAGE__->meta->make_immutable;

1;

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item File::Spec

=item List::Utils

=item namespace::autoclean

=back

=head1 INCOMPATIBILITIES

The Moose builder and before constructs used here may not be particularly
appropriate for inheritance - review required should you subclass.

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David K. Jackson, E<lt>david.jackson@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018 GRL

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

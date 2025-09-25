package Monitor::Ultimagen::RunParser;

use Moose;
use Carp;
use Readonly;
use JSON;
use File::Spec::Functions qw( catfile );
use File::Basename;
use DateTime;
use List::Util qw( sum );
use DateTime::Format::Strptime;
use Perl6::Slurp;
use Try::Tiny;
use XML::LibXML;

use npg_tracking::util::types;

our $VERSION = '0';

=head1 NAME

Monitor::Ultimagen::RunParser

=head1 VERSION

=head1 SYNOPSIS

C<<use Monitor::Ultimagen::RunParser;
   my $run_folder = Monitor::Ultimagen::RunParser->new(
     runfolder_path      => $run_folder);
  >>

=head1 DESCRIPTION

A parser for Ultima Genomics (Ultimagen) run info.

=head1 SUBROUTINES/METHODS

=head2 runfolder_path

Directory path of the run folder.

=cut

has q{runfolder_path} => (
  isa           => q{NpgTrackingDirectory},
  is            => q{ro},
  required      => 1,
);

=head2 runfolder_glob

Parent directory of the run folders in the staging area.

=cut
has q{runfolder_glob}  => (
  isa             => q{Str},
  is              => q{ro},
  required        => 0,
  lazy_build      => 1,
);
sub _build_runfolder_glob {
  my $self = shift;
  return dirname($self->runfolder_path);
}

=head2 flowcell_id

A string containing the RunId taken as flowcell ID.
It is retrieved from *_LibraryInfo.xml file.

=cut
has q{flowcell_id}  => (
  isa             => q{Str},
  is              => q{ro},
  required        => 0,
  lazy_build      => 1,
);
sub _build_flowcell_id {
  my $self = shift;
  my $flowcell_id = $self->_library_info_data()
    ->getDocumentElement()->getAttribute("RunId");
  if (! $flowcell_id) {
    croak 'Empty value in RunId';
  }
  return $flowcell_id;
}

=head2 folder_name

A string containing the RunID (considered as flowcell_id) 
and time stamp that define a run folder name. 
It is retrieved from the runfolder_path.

=cut
has q{folder_name}    => (
  isa               => q{Str},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_folder_name {
  my $self = shift;
  my $folder_name = basename $self->runfolder_path;
  if (! $folder_name) {
    croak 'Empty value in folder_name';
  }
  return $folder_name;
}

=head2 batch_id

The sequencing batch ID. It is retrieved from the Library_Pool field
of the *_LibraryInfo.xml file.

Not being able to extract batch ID from the run name is not 
an error. Walk-up runs are not tracked through LIMS.

=cut
has q{batch_id}     => (
  isa           => q{Maybe[NpgTrackingPositiveInt]},
  is            => q{ro},
  required      => 0,
  lazy_build    => 1,
);
sub _build_batch_id {
  my $self = shift;
  my $library_pool_info = $self->_library_info_data()
    ->getDocumentElement()->getAttribute("Library_Pool");
  my ($batch_id) = $library_pool_info =~ /batch_(\d+)/smx;
  if (!$batch_id) {
    carp "batch_id: wrong format in *_LibraryInfo.xml";
  }
  return $batch_id;
}

=head2 date_created

The date when the run was created.
By default, it is retrieved from the folder_name.
If not present, the time stamp of the directory is choosen.

=cut
has q{date_created} => (
  isa               => q{DateTime},
  is                => q{ro},
  required          => 0,
  lazy_build        => 1,
);
sub _build_date_created {
  my $self = shift;

  my ($date_string) = $self->folder_name =~ m/\d+-(\d+_\d+)/ms;
  my $date;
  if ($date_string) {
    try {
      $date = DateTime::Format::Strptime->new(
        pattern=>'%Y%m%d_%H%M',
        strict=>1,
        on_error=>q[croak]
      )->parse_datetime($date_string);
    } catch {
      croak "date_created: failed to parse $date_string";
    };
  } else {
    croak 'date_created: No valid value in ' . $self->folder_name;
  }
  
  return $date;
}

#####
# Hash reference that represents the XML file content of runID_LibraryInfo.xml file.
has q{_library_info_data} => (
  isa               => q{XML::LibXML::Document},
  is                => q{ro},
  required          => 0,
  init_arg          => undef,
  lazy_build        => 1,
);
sub _build__library_info_data {
  my $self = shift;
  my @library_info = grep { /\d+_LibraryInfo/ } 
    ( glob catfile($self->runfolder_path, '*.xml') );
  if ( @library_info != 1 ) {
    croak 'Wrong folder format: LibraryInfo.xml error';
  }
  return XML::LibXML->load_xml(location => $library_info[0]);
}

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item Readonly

=item JSON

=item File::Spec::Functions

=item File::Basename

=item DateTime

=item List::Util

=item DateTime::Format::Strptime

=item Perl6::Slurp

=item Try::Tiny

=item npg_tracking::util::types

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Marco M. Mosca

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 Genome Research Ltd.

This program is free software: you can redistribute it and/or modify
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

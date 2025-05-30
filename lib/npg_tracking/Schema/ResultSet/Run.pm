package npg_tracking::Schema::ResultSet::Run;

use Moose;
use MooseX::MarkAsMethods autoclean => 1;
use Carp;

extends 'DBIx::Class::ResultSet';

our $VERSION = '0';

sub find_with_attributes {
  my ($self, $runfolder_name, $flowcell_id, $instrument_name) = @_;

  ($runfolder_name && $flowcell_id && $instrument_name) or croak
    "One of runfolder name, flowcell ID or barcode or instrument name" .
    " is undefined";

  my $rs =   $self->result_source()->schema()->resultset('Instrument')
    ->search( {'-or' => [name => $instrument_name,
                         external_name => $instrument_name]} );
  my $instrument_record = $rs->next();
  if (!$instrument_record) {
    croak "Instrument with name or external name $instrument_name does not exist";
  }
  if ($rs->next()) {
    croak "Multiple instrument records with name or external name $instrument_name";
  }

  $rs = $self->search({
                        'flowcell_id' => $flowcell_id,
                        'folder_name' => $runfolder_name,
                        'id_instrument' => $instrument_record->id_instrument
                      });
  my $run_record = $rs->next();
  if ($run_record && $rs->next()) {
    croak sprintf
     "Multiple run records for run folder %s, flowcell %s and instrument %s",
     $runfolder_name, $flowcell_id, $instrument_name;
  } 

  return $run_record;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;

__END__

=head1 NAME

npg_tracking::Schema::ResultSet::Run

=head1 SYNOPSIS

  my $run_folder_name = '20250127_AV244103_NT1850075L';
  my $instrument_name = 'AV244134';
  my $flowcell_id = '2427499508';
  my $run_row = $schema->resultset('Run')->find_with_attributes(
    $run_folder_name, $flowcell_id, $instrument_name
  );
  if (!$run_row) {
    print "Run with this attributes is not tracked\n";
  } else {
    print 'Found tracked run with ID ' . $run_row->id_run . "\n";
  }

=head1 DESCRIPTION

An extension for the ResultSet object for C<run> table.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 SUBROUTINES/METHODS

=head2 find_with_attributes

Tries to find a run record using three attributes of a run, which are provided
as three arguments, run folder name, flowcell identifier and instrument's
name or external name.

The instrument name argument is validated by searching for an instrument record
that has this value as either name or an external name. An error is raised if
either none or multiple instrument records are found.

Returns a single C<npg_tracking::Schema::Result::Run> object if one run record
is found. Returns an undefined value if no run records are found. Errors if
multiple run records are found.

=head1 DEPENDENCIES

=over

=item Moose

=item MooseX::MarkAsMethods

=item DBIx::Class::ResultSet

=item Carp

=back

=head1 INCOMPATIBILITIES

This code does not work with MooseX::NonMoose hence false inline_constructor
option is used when calling ->make_immutable.

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia <lt>mg8@sanger.ac.uk<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2025 GRL Genome Research Ltd.

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


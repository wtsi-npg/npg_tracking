package Monitor::Elembio::Enum;

use strict;
use warnings;
use Readonly;

use Exporter;

our @ISA= qw( Exporter );
our @EXPORT = qw(
  $USERNAME
  $INSTRUMENT_TABLE
  $RUN_TABLE
  $RUNLANE_TABLE
  $BASECALL_FOLDER
  $CONSUMABLES
  $CYCLES
  $CYCLE_FILE_PATTERN
  $DATE
  $FLOWCELL
  $FOLDER_NAME
  $INSTRUMENT_NAME
  $LANES
  $RUN_NAME
  $SERIAL_NUMBER
  $SIDE
  $TIME_PATTERN
  $RUN_CYTOPROFILE
  $RUN_PARAM_FILE
  $RUN_MANIFEST_FILE
  $RUN_STANDARD
  $RUN_STATUS_COMPLETE
  $RUN_STATUS_INPROGRESS
  $RUN_STATUS_TIME_PATTERN
  $RUN_STATUS_TYPE
  $RUN_TYPE
  $RUN_UPLOAD_FILE
);

our $VERSION = '0';

# Pipeline Enums
Readonly::Scalar our $USERNAME => 'pipeline';

# Database Enums
Readonly::Scalar our $INSTRUMENT_TABLE => 'Instrument';
Readonly::Scalar our $RUN_TABLE => 'Run';
Readonly::Scalar our $RUNLANE_TABLE => 'RunLane';

# Property Enums
Readonly::Scalar our $BASECALL_FOLDER => 'BaseCalls';
Readonly::Scalar our $CONSUMABLES => 'Consumables';
Readonly::Scalar our $CYCLES => 'Cycles';
Readonly::Scalar our $CYCLE_FILE_PATTERN => qr/^[IR][12]_C\d{3}/;
Readonly::Scalar our $DATE => 'Date';
Readonly::Scalar our $FLOWCELL => 'Flowcell';
Readonly::Scalar our $FOLDER_NAME => 'RunFolderName';
Readonly::Scalar our $INSTRUMENT_NAME => 'InstrumentName';
Readonly::Scalar our $LANES => 'AnalysisLanes';
Readonly::Scalar our $RUN_NAME => 'RunName';
Readonly::Scalar our $SERIAL_NUMBER => 'SerialNumber';
Readonly::Scalar our $SIDE => 'Side';
Readonly::Scalar our $TIME_PATTERN => '%Y-%m-%dT%H:%M:%S.%NZ'; # 2023-12-19T13:31:17.461926614Z
Readonly::Scalar our $RUN_STATUS_TIME_PATTERN => '%Y-%m-%dT%H:%M:%S';

# Run Enums
Readonly::Scalar our $RUN_CYTOPROFILE => 'Cytoprofiling';
Readonly::Scalar our $RUN_PARAM_FILE => 'RunParameters.json';
Readonly::Scalar our $RUN_MANIFEST_FILE => 'RunManifest.json';
Readonly::Scalar our $RUN_STANDARD => 'Sequencing';
Readonly::Scalar our $RUN_TYPE => 'RunType';
Readonly::Scalar our $RUN_UPLOAD_FILE => 'RunUploaded.json';
Readonly::Scalar our $RUN_STATUS_COMPLETE => 'run complete';
Readonly::Scalar our $RUN_STATUS_INPROGRESS => 'run in progress';
Readonly::Scalar our $RUN_STATUS_TYPE => 'StatusType';

1;

__END__

=head1 NAME

Monitor::Elembio::Enum

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

Package containing a set of Enum variables used in Elembio modules

=head1 SUBROUTINES/METHODS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Readonly

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

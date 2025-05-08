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
  $RUN_STANDARD
  $RUN_TYPE
);

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

# Run Enums
Readonly::Scalar our $RUN_CYTOPROFILE => 'Cytoprofiling';
Readonly::Scalar our $RUN_STANDARD => 'Standard';
Readonly::Scalar our $RUN_TYPE => 'RunType';

1;

__END__


Illumina Sequencing Instruments Tracking
========================================

Currently supported instrument types: NovaSeqX, NovaSeq, HiSeq, MiSeq.

Top Level Directories
---------------------

+ `lib` - Perl modules and classes
  + `npg::`          - web application
  + `npg_tracking::`
    + general definitions
    + access to genomic references and other reference data
    + API for extended Illumina rundolder structure
  + `npg_tracking::Schema` - DBIx binding for the tracking database
  + `st::api::`      - LIMS API
  + `Monitor::`      - monitoring runfolders on staging servers up to the
                       analysis stage
  + `npg_testing::`  - supplimentary modules for testing
+ `bin` - production Perl scripts
+ `cgi-bin` - cgi scripts for the web application
+ `scripts` - supplimentary scripts
+ `htdocs` - images and client-side scripts for the web application
+ `data`
  + templates for the web app and some cron jobs
  + example database configuration file for the web application
+ `docs` - directory for documentation
+ `wtsi_local` - Apache httpd web server configuration files
+ `t` - unit tests, test data, supplimentary scripts and modules for testing

Environment Variables and Their Meaning
---------------------------------------

+ `NPG_CACHED_SAMPLESHEET_FILE` - a path to a file with cached LIMS data,
                                  see `st::api::lims`

Tags and Their Meaning
----------------------
Run and lane tags are described [here](docs/tag_semantics.md)

Runs Lifecycle
--------------
Run statuses are explained [here](docs/run_states.md)

Sequencing Instrument Lifecycle and Management
----------------------------------------------
See [code snippets](docs/instruments.md) for creating and updating
database records for instruments.

User Management
---------------
Users may ask to get some permissions to create new runs in the tracking system. 
To grant permissions the User Management [guide](docs/user_management.md) 
explains how to assign the users to different groups.

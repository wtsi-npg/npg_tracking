Illumina Sequencing Instruments Tracking
========================================

Currently supported instrument types: NovaSeq, HiSeq, MiSeq.

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
+ `wtsi_local` - Apache web server configuration files
+ `t` - unit tests, test data, supplimentary scripts and modules for testing


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
+ `docs` - directory for documentation
+ `wtsi_local` - Apache httpd web server configuration files
+ `t` - unit tests, test data, supplimentary scripts and modules for testing

Environment Variables and Their Meaning
---------------------------------------

+ `NPG_CACHED_SAMPLESHEET_FILE` - a path to a file with cached LIMS data,
                                  see `st::api::lims`
+ `NPG_WEBSERVICE_CACHE_DIR` - a cache directory for test LIMS and NPG servers
                               XML feeds, used in unit tests only

Tags and Their Meaning
----------------------

Text tags can be associated with sequencing runs and individual lanes of a run.
Arbitrary tags are supported. Tags can be assigned both manually by the users
via a web page of a run and automatically by differnt cron jobs. Access to the
tracking database is needed for the latter.

Formally speaking, the tags are not curated, but some tags trigger special
features in the data processing pipelines. Some of special tags are listed
below. Once associated with the run, the tag is not removed, unless this is
explicitly stated. Any tag can be removed manually via a web page of a run.

+ `staging` - A run is assigned this tag the first time the run folder is seen
              by the staging daemon, see the `staging_area_monitor` script in
              this package. The tag is removed by a cron job that deletes
              run folders from the staging area.
+ `multiplex` - The staging daemon assigns this tag to a run if the run had
                an indexing read.
+ `no_mqc_skipper` - This tag can be manually assigned to a run to prevent the
                     data being assessed by a
[script](https://github.com/wtsi-npg/npg_qc/blob/master/bin/npg_mqc_skipper)
                     that can change the run status from `qc review pending` to
                     `archival pending` bypassing the stage of manual QC.
+ `no_auto_analysis` - This tag can be manually assigned to a run to prevent
                       it being considered by the analysis daemon.
+ `no_auto_archive` - This tag can be manually assigned to a run to prevent
                      it being considered by the archival daemon.
+ `no_auto` - This tag can be manually assigned to a run to prevent it being
              considered by any automatic processing.

User Management
---------------
Users may ask to get some permissions to create new runs in the tracking system. 
To grant permissions the User Management 
[guide](https://github.com/wtsi-npg/npg_tracking/tree/devel/docs/user_management.md) 
explains how to assign the users to different groups.
<!-- Space: NPG -->
<!-- Parent: Tracking -->
<!-- Title: Tag Semantics -->

<!-- Macro: :box:([^:]+):([^:]*):(.+):
     Template: ac:box
     Icon: true
     Name: ${1}
     Title: ${2}
     Body: ${3} -->

:box:info:Note:This page is automatically generated; any edits will be overwritten:

###### Repository information

<!-- Include: includes/repo-metadata.md -->

Tags and Their Meaning

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

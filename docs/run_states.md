# Run States

The Tracking interface shows a sequence of states for Illumina runs. They have the following meanings in approximate order of execution:

| Run state      | Meaning |
|----------------|---------|
| run pending    | Run is being set up in the Illumina lab |
| run in progress| Sequencing in progress on the instrument, data for at least one cycle has been transferred to the staging server |
| run on hold    | Run is temporarily stopped |
| run complete   | Instrument software believes that all data have been copied to the staging area |
| run cancelled  | Run has been cancelled in the lab. If sequencing has not started, the flowcell could be transferred to another instrument. |
| run stopped early | Run has been stopped in the lab. If sequencing has not started, the flowcell could be transferred to another instrument. |
| data discarded | Problem in sequencing, data should be discarded, no need to analyse or archive |
| run mirrored   | NPG have checked the data and believe that it has all been transferred from the instrument |
| run imported   | Data for this run came from outside, no sequencing done and the above states do not apply |
| analysis pending | Run is ready to be picked up by the analysis daemon |
| analysis in progress | Run has been automatically submitted for analysis. Stage 1 analysis is in progress |
| secondary analysis in progress | All data are now in stage 2 of the analysis - alignment, QC checks and secondary pipelines such as for the Heron study |
| analysis on hold | Something went wrong either during analysis or in Manual QC. Investigating, probably re-analysing |
| analysis complete | Analysis has finished |
| qc review pending | Run is ready for manual QC |
| qc in progress | Manual QC in progress (Data team in Ops) |
| qc on hold | Problem detected, investigation in progress by the QC team. They may involve NPG or PSD to learn more. Change to LIMS data in Sequencescape and ml warehouse and re-analysis might be required |
| archival pending | Run is ready to be archived, waiting to be picked up by the archival daemon. Normally run is automatically transferred to this status once manual QC of all lanes of the run is complete. However, Heron runs are transferred to this status straight after ‘analysis complete’, bypassing the manual QC step. |
| archival in progress | Run has been submitted for archival. Data in our QC database and ml-warehouse will be uploaded/updated, data are uploaded to/updated in iRODS |
| run archived | Archival to iRODS is finished |
| qc complete | NPG hands the data off. End users can safely access it from iRODS/warehouse etc. Once this status is reached, staging data becomes eligible for deletion after a grace period. Faculty data is allowed to remain for two weeks after completion |

## See also

[Analysis pipeline flow](https://github.com/wtsi-npg/npg_seq_pipeline/blob/devel/data/config_files/function_list_central.json.png)
[Archival pipeline flow](https://github.com/wtsi-npg/npg_seq_pipeline/blob/devel/data/config_files/function_list_post_qc_review.json.png)

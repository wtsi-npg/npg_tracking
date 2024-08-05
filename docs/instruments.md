<!-- Space: NPG -->
<!-- Parent: Tracking -->
<!-- Title: All About Illumina Instruments -->

<!-- Macro: :box:([^:]+):([^:]*):(.+):
     Template: ac:box
     Icon: true
     Name: ${1}
     Title: ${2}
     Body: ${3} -->

:box:info:Note:This page is automatically generated; any edits will be overwritten:

###### Repository information

<!-- Include: includes/repo-metadata.md -->

# All About Illumina Instruments

## Create Instrument

To create a new validated instrument, execute the appropriate one-liner using
the correct instrument names. The value of the `external_name` field is the
unique manufacturer's name of the instrument.

The initial status of the instrument is 'wash required'.


NovaSeq instrument:

```
perl -le 'use strict; use npg_tracking::Schema; my $s=npg_tracking::Schema->connect(); $s->txn_do(sub{my $m=$s->resultset(q(Instrument))->find_or_create({name=>q[NV22], instrument_format=>{model=>q(NovaSeq)}}); $m->update({iscurrent=>1, external_name=>q(A00518)}); $m->add_to_designations({description=>q(Accepted)}); print join",",$m->get_columns; print join",",$_->get_columns foreach $m->designations; print "current instrument status: ".$m->current_instrument_status;});'
```

NovaSeqX instrument:

```
perl -le 'use strict; use npg_tracking::Schema; my $s=npg_tracking::Schema->connect(); $s->txn_do(sub{my $m=$s->resultset(q(Instrument))->find_or_create({name=>q[NX1], instrument_format=>{model=>q(NovaSeqX)}}); $m->update({iscurrent=>1, external_name=>q(Pi1-9)}); $m->add_to_designations({description=>q(Accepted)}); print join",",$m->get_columns; print join",",$_->get_columns foreach $m->designations; print "current instrument status: ".$m->current_instrument_status;});'
```

## Delete Instrument

To decommission an instrument, set `iscurrent` attribute to 0:

```
perl -le 'use strict; use npg_tracking::Schema; my $s=npg_tracking::Schema->connect(); $s->txn_do(sub{my $m=$s->resultset(q(Instrument))->find({name=>q[HS86]}); $m->update({iscurrent=>0}); print join",",$m->get_columns;})'
```


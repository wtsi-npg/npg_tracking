# All About Illumina Instruments

## Create Instrument

To create a new validated instrument, execute the appropriate one-liner using
the correct instrument name.
The initial status of the instrument is 'wash required'.

HiSeq instrument:

```
perl -le 'use strict; use npg_tracking::Schema; my $s=npg_tracking::Schema->connect(); $s->txn_do(sub{my $m=$s->resultset(q(Instrument))->find_or_create({name=>q[HS86], instrument_format=>{model=>q(HiSeq)}}); $m->update({iscurrent=>1, instrument_comp=>lc $m->name}); $m->add_to_designations({description=>q(Accepted)}); print join",",$m->get_columns; print join",",$_->get_columns foreach $m->designations; print "current instrument status: ".$m->current_instrument_status;});'
```

HiSeqX instrument:

```
perl -le 'use strict; use npg_tracking::Schema; my $s=npg_tracking::Schema->connect(); $s->txn_do(sub{my $m=$s->resultset(q(Instrument))->find_or_create({name=>q[HX92], instrument_format=>{model=>q(HiSeqX)}}); $m->update({iscurrent=>1, instrument_comp=>lc $m->name}); $m->add_to_designations({description=>q(Accepted)}); print join",",$m->get_columns; print join",",$_->get_columns foreach $m->designations; print "current instrument status: ".$m->current_instrument_status;});'
```

NovaSeq instrument:

```
perl -le 'use strict; use npg_tracking::Schema; my $s=npg_tracking::Schema->connect(); $s->txn_do(sub{my $m=$s->resultset(q(Instrument))->find_or_create({name=>q[NV22], instrument_format=>{model=>q(NovaSeq)}}); $m->update({iscurrent=>1, external_name=>q(A00518)}); $m->add_to_designations({description=>q(Accepted)}); print join",",$m->get_columns; print join",",$_->get_columns foreach $m->designations; print "current instrument status: ".$m->current_instrument_status;});'
```

## Delete Instrument

To decommission an instrument, set `iscurrent` attribute to 0:

```
perl -le 'use strict; use npg_tracking::Schema; my $s=npg_tracking::Schema->connect(); $s->txn_do(sub{my $m=$s->resultset(q(Instrument))->find({name=>q[HS86]}); $m->update({iscurrent=>0}); print join",",$m->get_columns;})'
```


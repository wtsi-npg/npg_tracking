<!-- Space: NPG -->
<!-- Parent: Tracking -->
<!-- Title: API usage -->

<!-- Macro: :box:([^:]+):([^:]*):(.+):
     Template: ac:box
     Icon: true
     Name: ${1}
     Title: ${2}
     Body: ${3} -->

:box:info:Note:This page is automatically generated; any edits will be overwritten:

###### Repository information

<!-- Include: docs/includes/repo-metadata.md -->

# NPG Tracking API usage

There are two APIs in active use for NPG Tracking: once Clearpress based, the other DBIx::Class based.

Here is an example of using a combinaiton of both (which can be useful as their functionality does not completely overlap).


## Examples

### Update a selection of runs to remove their staging tag and add an annotation

The initial DBIx::Class selection of runs is those who have a `sf` in the path glob field and a `staging` tag. Those which do not have a folder on disk matching this path then have their staging tag removed and an Annotation added.

```
( #use a subshell for temporary set up
export dev=dev; # test with dev DB 
export DBI_TRACE=0; 
export PATH=$PATH:/software/npg/20221020/bin/; 
export PERL5LIB=/software/npg/20221020/lib/perl5; 
perl -le '
  use strict;
  use ClearPress::driver::mysql;
  use npg::util;
  use npg::model::run;
  use npg_tracking::Schema;
  my$s=npg_tracking::Schema->connect(); 
  $s->txn_do(sub{ #everything in one DB transaction
    # now setup Clearpress from the DBIC DB handle, turn off Clearpress transactions to not clash with DBIC transaction
    my$u=npg::util->new({driver=>ClearPress::driver::mysql->new({dbh=>$s->storage->dbh}), transactions=>0, username=>(getpwuid $<)[0]});
    my $oUser = npg::model::user->new({util=>$u,username=>$u->username()});
    $u->requestor($oUser); # use the same User object to simulate what would come from a Clearpress view object
    warn $u->username; warn $oUser->id_user;
    my $oAnnotation = npg::model::annotation->new({util=>$u,id_user=>$oUser->id_user() ,comment=>"Bulk removal of staging tag for run folders on sf-nfs nodes which have in fact already been deleted. See https://jira.sanger.ac.uk/browse/NPG-529"});
    # now find the DB records for /sf based runfolders with a staging tag
    my$rs=$s->resultset("Tag")->search({tag=>q(staging)})->related_resultset("tag_runs")->related_resultset("run")->search({folder_path_glob=>{like=>q(%/sf%)}});
    warn $rs->count;
    while (my$r=$rs->next()){
      my($rfg)=(map{s{\Q/{export,nfs}/\E}{/nfs/}; $_}$r->folder_path_glob);
      $rfg.=$r->folder_name();
      my($rf)=glob $rfg; # does the run folder exist on disk
      if(not $rf){
        print join "\t",$r->id_run,$rfg,$rf ;
        my$oRun=npg::model::run->new({util=>$u,id_run=>$r->id_run});
        $oRun->attach_annotation($oAnnotation);
        $r->unset_tag(q(staging));
        print join"\n",map{s/\n/ /smg;  $_}map{join"\t",$_->date,$_->id_user, $_->comment}grep{defined}(@{npg::model::run->new({util=>$u,id_run=>$r->id_run})->annotations()})[-2,-1] ;
        print;
      }
    }
    warn $rs->count;
    die "do not commit...";
  }); # end of transaction
')
```

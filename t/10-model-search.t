#########
# Author:        ajb
# Maintainer:    $Author: mg8 $
# Created:       2007-10
# Last Modified: $Date: 2012-11-26 09:53:48 +0000 (Mon, 26 Nov 2012) $
# Id:            $Id: 10-model-search.t 16269 2012-11-26 09:53:48Z mg8 $
# $HeadURL: svn+ssh://svn.internal.sanger.ac.uk/repos/svn/new-pipeline-dev/npg-tracking/trunk/t/10-model-search.t $
#
use strict;
use warnings;
use Test::More tests => 6;
use t::util;

use Readonly; Readonly::Scalar our $VERSION => do { my ($r) = q$Revision: 16269 $ =~ /(\d+)/mx; $r; };
use_ok('npg::model::search');

my $util = t::util->new({
       fixtures => 1,
      });

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('Lack of clusters');
  my $results = $search->results();
  is((scalar @{$results}), 1, 'exact run annotation');
}

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('networked');
  my $results = $search->results();
  is((scalar @{$results}), 6, 'exact instrument annotation');
}

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('1000Genomes-A2-TriosPilot');
  my $results = $search->results();
  is((scalar @{$results}), 2, '2 exact projects');
}

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('NA12878-WG');
  my $results = $search->results();
  is((scalar @{$results}), 2, '2 exact library');
}

{
  my $search = npg::model::search->new({
          util => $util,
               });

  $search->query('939');
  my $results = $search->results();
  is((scalar @{$results}), 1, 'exact batch id');
}

1;
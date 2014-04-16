#########
# Author:        rmp
# Created:       2008-01
#
package npg::model::search;
use strict;
use warnings;
use base qw(npg::model);
use Carp;
use List::MoreUtils;

our $VERSION = '0';

__PACKAGE__->mk_accessors(fields());

sub fields {
  my $search_for = search_for();
  my $search_conditions = search_conditions();
  my @fields = qw(dummy_pk query from to);
  foreach my $key (sort keys %{$search_for}) { push @fields, $key; };
  foreach my $key (sort keys %{$search_conditions}) { push @fields, $key; };
  return @fields;
}

sub results {
  my $self  = shift;
  my $util  = $self->util();
  my $term  = $self->query();
  my $queries = [];

  #########
  # search ids
  #
  if($term =~ /^\d+$/smx) {
    #########
    # search runs
    #
    push @{$queries}, [q(SELECT 'run'    AS type,
                                id_run   AS primary_key,
                                'run id' AS location,
                                ''       AS context
                         FROM run
                         WHERE id_run=?), $term];

    #########
    # search ST batches
    #
    push @{$queries}, [q(SELECT 'run'      AS type,
                                id_run     AS primary_key,
                                'batch id' AS location,
                                ''         AS context
                         FROM run
                         WHERE batch_id=?), $term];

  }

  #########
  # search ST libraries
  #
  push @{$queries}, [q(SELECT 'run'                AS type,
                              id_run               AS primary_key,
                              'library name'       AS location,
                              content              AS context
                       FROM   st_cache
                       WHERE  type    = 'library'
                       AND    content LIKE ?), "%$term%"];

  #########
  # search ST projects
  #
  push @{$queries}, [q(SELECT 'run'             AS type,
                              id_run            AS primary_key,
                              'project name'    AS location,
                              content           AS context
                       FROM   st_cache
                       WHERE  type    = 'project'
                       AND    content LIKE ?), "%$term%"];

  #########
  # search run annotations
  #
  push @{$queries}, [q(SELECT 'run'        AS type,
                              ra.id_run    AS primary_key,
                              'annotation' AS location,
                              a.comment    AS context
                       FROM   annotation     a,
                              run_annotation ra
                       WHERE  ra.id_annotation = a.id_annotation
                       AND    a.comment LIKE   ?
                       ORDER BY date DESC
                       LIMIT 100), "%$term%"];

  #########
  # search instrument annotations & statuses
  #
  push @{$queries}, [q(SELECT 'instrument'     AS type,
                              ia.id_instrument AS primary_key,
                              'annotation'     AS location,
                              CONCAT(a.comment,
                                     ' by ', u.username,
                                     ' on ', a.date) AS context
                       FROM   annotation            a,
                              instrument_annotation ia,
                              user                  u
                       WHERE  ia.id_annotation = a.id_annotation
                       AND    a.id_user        = u.id_user
                       AND    a.comment LIKE ?
                       ORDER BY a.date DESC
                       LIMIT 100), "%$term%"];

  push @{$queries}, [q(SELECT 'instrument'      AS type,
                              ins.id_instrument AS primary_key,
                              'status'          AS location,
                              CONCAT(ins.comment,
                                     ' by ', u.username,
                                     ' on ', ins.date) AS context
                       FROM   instrument_status ins,
                              user              u
                       WHERE  u.id_user = ins.id_user
                       AND    comment LIKE ?
                       ORDER BY date DESC
                       LIMIT 100), "%$term%"];


  #########
  # search tags
  #
  push @{$queries}, [q(SELECT 'run'       AS type,
                              tr.id_run   AS primary_key,
                              'tag'       AS location,
                              tag         AS context
                       FROM   tag         t,
                              tag_run     tr
                       WHERE  tr.id_tag = t.id_tag
                       AND    t.tag LIKE ?
                       ORDER  BY tr.date DESC
                       LIMIT 100), "%$term%"];
  push @{$queries}, [q(SELECT 'run_lane'      AS type,
                              trl.id_run_lane AS primary_key,
                              'tag'           AS location,
                              tag             AS context
                       FROM   tag          t,
                              tag_run_lane trl
                       WHERE  trl.id_tag = t.id_tag
                       AND    t.tag LIKE ?
                       ORDER  BY trl.date DESC
                       LIMIT 100), "%$term%"];

  my $results = [];
  for my $q (@{$queries}) {
      #warn join(q[ ], @{$q})."\n";
    push @{$results}, @{$util->dbh->selectall_arrayref($q->[0], {}, $q->[1])};
  }

  return $results;
}

sub advanced_search {
  my ($self) = @_;
  if(!$self->{'results'}) {
    my $cgi = $self->util->cgi();
    my (@from, @where, @select, %from_seen);
    push @select, 'run.id_run';
    push @from, 'run';
    $from_seen{run}++;
    $self->conditions(\@where, \@from, \%from_seen);
    $self->date_conditions(\@where, \@from, \%from_seen);
    $self->selects(\@select, \@from, \%from_seen, \@where);
    my $select = join ', ', @select;
    if (scalar @from > 1) {
      my @from_pairs = $self->join_conditions(\@where, \@from, \%from_seen);
    }
    my $from   = join ', ', @from;
    my $where  = join ' AND ', @where;
    my $query = qq{SELECT DISTINCT $select FROM $from};
    if ($where) {
      $query .= qq{ WHERE $where};
    }
    my $dbh = $self->util->dbh();
    my $sth = $dbh->prepare(qq{$query});
    $sth->execute();
    my $results = [];
    while (my $result = $sth->fetchrow_hashref()) {
      push @{$results}, $result;
    }
    push @{$self->{result_keys}}, 'id_run';
    foreach my $key (sort keys %{$results->[0]}) {
      if ($key ne 'id_run') { push @{$self->{'result_keys'}}, $key; };
    }
    foreach my $result (@{$results}) {
      my $temp = [];
      push @{$temp}, $result->{id_run};
      foreach my $key (sort keys %{$result}) {
        if ($key ne 'id_run') { push @{$temp}, $result->{$key}; };
      }
      $result = $temp;
    }
    if ($cgi->param('run_tags')) {
      push @{$self->{'result_keys'}}, 'tags';
      $self->select_tags($results);
    }
    $self->{'results'} = $results;
  }
  return $self->{'results'};
}

sub select_tags {
  my ($self, $results) = @_;
  my @id_runs;
  foreach my $row (@{$results}) {
    push @id_runs, $row->[0];
  }
  my $id_runs_for_query = join q{,}, @id_runs;
  my $query = qq(SELECT tr.id_run, t.tag FROM tag t, tag_run tr WHERE t.id_tag = tr.id_tag AND tr.id_run in ($id_runs_for_query) ORDER BY tr.id_run);
  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare(qq{$query});
  $sth->execute();
  my %run_tags_by_run;
  while (my $result = $sth->fetchrow_hashref()) {
    push @{$run_tags_by_run{$result->{id_run}}}, $result->{tag};
  }
  foreach my $row (@{$results}) {
    if ($run_tags_by_run{$row->[0]}) {
      push @{$row}, join q{ }, @{$run_tags_by_run{$row->[0]}};
    } else {
      push @{$row}, undef;
    }
  }
  return;
}

sub selects {
  my ($self, $select, $from_array, $from_seen, $where) = @_;
  my $cgi = $self->util->cgi();
  my $search_for = $self->search_for();
  foreach my $for (sort keys %{$search_for}) {
    my $wanted = $cgi->param($for);
    if ($wanted) {
      push @{$select}, $search_for->{$for}->{select};
      if ($search_for->{$for}->{where}) { push @{$where}, $search_for->{$for}->{where}; };
      foreach my $from (@{$search_for->{$for}->{from}}) {
        if (!$from_seen->{$from}) {
          push @{$from_array}, $from;
          $from_seen->{$from}++;
        }
      }
    }
  }
  return;
}

sub conditions {
  my ($self, $where, $from_array, $from_seen) = @_;
  my $cgi = $self->util->cgi();
  my $search_conditions = $self->search_conditions();
  foreach my $search_condition (sort keys %{$search_conditions}) {
    my $condition = $cgi->param($search_condition);
    if ($condition) {
      if ($search_condition eq 'tags') {
        $condition =~ s/\s/','/xms;
        $condition = lc qq{'$condition'};
      }
      $search_conditions->{$search_condition}->{where} =~ s/[?]/$condition/xms;
      push @{$where}, $search_conditions->{$search_condition}->{where};
      foreach my $from (@{$search_conditions->{$search_condition}->{from}}) {
        if (!$from_seen->{$from}) {
          push @{$from_array}, $from;
          $from_seen->{$from}++;
        }
      }
    }
  }
  return;
}

sub date_conditions {
  my ($self, $where, $from_array, $from_seen) = @_;
  my $cgi  = $self->util->cgi();
  my $from = $cgi->param('from');
  my $to   = $cgi->param('to');

  if ($from) {
    push @{$where}, qq{DATE(run_status.date) >= DATE('$from')};
  }

  if ($to) {
    push @{$where}, qq{DATE(run_status.date) <= DATE('$to')};
  }

  if ($from || $to) {
    if (!$from_seen->{run_status}) {
      push @{$from_array}, 'run_status',
      $from_seen->{run_status}++;
    }

    if (!$from_seen->{run_status_dict}) {
      push @{$from_array}, 'run_status_dict',
      $from_seen->{run_status_dict}++;
    }
  }
  return;
}

sub join_conditions {
  my ($self, $where, $from_array, $from_seen) = @_;
  my $foreign_keys = $self->foreign_keys();
  my (@joins, %seen);
  my @from_pairs = $self->create_pairs(@{$from_array});
  foreach my $table (sort keys %{$foreign_keys}) {
    foreach my $pair (@from_pairs) {
      if (( List::MoreUtils::any {$_ eq $pair->[0]} @{$foreign_keys->{$table}} ) && ( List::MoreUtils::any {$_ eq $pair->[1]} @{$foreign_keys->{$table}} )) {
        my $temp = $pair->[0] . '.id_' . $pair->[0] . ' = ' . $table . '.id_' . $pair->[0];
        if(!$seen{$temp}) {
          push @joins, $temp;
          $seen{$temp}++;
        }
        $temp = $pair->[1] . '.id_' . $pair->[1] . ' = ' . $table . '.id_' . $pair->[1];
        if(!$seen{$temp}) {
          push @joins, $temp;
          $seen{$temp}++;
        }
        if (!$from_seen->{$table}) {
          push @{$from_array}, $table;
          $from_seen->{$table}++;
        }
      }
    }
  }
  foreach my $from (@{$from_array}) {
    my $links = $foreign_keys->{$from};
    if ($links) {
      foreach my $link (@{$links}) {
        my $temp = $link . '.id_' . $link . ' = ' . $from . '.id_' . $link;
        if (!$seen{$temp}) {
          push @joins, $temp;
        }
      }
    }
  }
  foreach my $join (@joins) {
    my $count = 0;
    foreach my $from (@{$from_array}) {
      if ($join =~ /$from[.]/xms) {
        $count++;
      }
    }
    if ($count > 1) {
      push @{$where}, $join;
    }
  }
  return;
}

sub create_pairs {
  my ($self, @from) = @_;
  my @from_pairs;
  while (@from) {
    my $temp = shift @from;
    foreach my $remaining_from (@from) {
      push @from_pairs, [$temp, $remaining_from];
    }
  }
  return @from_pairs;
}

sub search_conditions {
  my $self = shift;
  return {
      run_lane      => { where => 'run_lane.position in (?)',
                         from  => ['run_lane']},
      id_run        => { where => 'run.id_run = ?',
                         from  => ['run']},
      batch_id      => { where => 'run.batch_id = ?',
                         from  => ['run'] },
      is_good       => { where => 'run_lane.is_good = 1',
                         from  => ['run_lane'] },
      loader        => { where => q{run_status_dict.description = 'run pending'
                                    AND user.username = '?'},
                         from  => ['run_status_dict','run_status','user'] },
      paired        => { where => 'run.is_paired = 1',
                         from  => ['run'] },
      non_paired    => { where => 'run.is_paired != 1',
                         from  => ['run'] },
      dev           => { where => q{run.team = 'RAD'},
                         from  => ['run'] },
      instrument    => { where => q{instrument.name = '?'},
                         from  => ['instrument'] },
      annotation    => { where => q{annotation.comment like '%?%'},
                         from  => ['annotation'] },
      status        => { where => q{run_status_dict.description = '?'},
                         from  => ['run_status_dict', 'run_status'] },
      libraryname   => { where => q{run.id_run in (SELECT id_run FROM st_cache WHERE type = 'library' AND content like '%?%')},
                         from  => ['run'] },
      projectname   => { where => q{run.id_run in (SELECT id_run FROM st_cache WHERE type = 'project' AND content like '%?%')},
                         from  => ['run'] },
      tags          => { where => q{tag.tag in (?)},
                         from  => ['tag'] },
    };
}

sub search_for {
  my $self = shift;
  return {
      projects    => { select => 'st_cache.content AS project', from => ['st_cache'], where => q{type = 'project'} },
      annotations => { select => 'annotation.id_annotation, annotation.comment', from => ['annotation'] },
      batches     => { select => 'run.batch_id', from => ['run'] },
      instruments => { select => 'instrument.id_instrument, instrument.name', from => ['instrument'] },
      run_lanes   => { select => 'run_lane.position', from => ['run_lane'] },
      status_date => { select => 'DATE(run_status.date) AS date', from => ['run_status'] },
      run_status  => { select => 'run_status_dict.description AS run_status', from => ['run_status_dict'] },
    };
}

sub foreign_keys {
  my $self = shift;
  return {
      annotation => ['user'],
      event => ['event_type', 'user'],
      event_type => ['entity_type'],
      event_type_subscriber => ['event_type','usergroup'],
      instrument => ['instrument_format'],
      instrument_format => ['manufacturer'],
      run => ['instrument','run_pair'],
      run_annotation => ['run','annotation'],
      run_lane => ['run','project'],
      run_status => ['run','user','run_status_dict'],
      st_cache => ['run'],
      tag_run => ['run', 'tag'],
      user2usergroup => ['user','usergroup'],
    };
}

1;

__END__

=head1 NAME

npg::model::search

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - basic handling for passing through the query term

=head2 results - run queries and aggregate results

=head2 advanced_search - overall controlling method to generate SQL statement and report back results, with given CGI parameters

  my $aAdvancedSearch = $oSearch->advanced_search();

=head2 selects - goes through CGI requests, creating select statements

=head2 conditions - goes through CGI search conditions, creating where statements

=head2 date_conditions - if CGI run status date conditions given, creates those where statements

=head2 join_conditions - creates where statements for needed table join conditions

=head2 create_pairs - creates an array of table pairs in order to be able to assess if join tables are needed to complete the SQL query

=head2 search_conditions - returns a hashref of where statements and from tables for conditional selections excluding dates

=head2 search_for - returns a hashref of select statements and from tables for requested items

=head2 foreign_keys - returns a hashref of the tables which contain foreign keys, and the tables which the foreign keys relate to

=head2 select_tags - new SQL query needed to obtain the tags for runs. this then concatenates all the tags for a run and puts them into their own column.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES
  strict
  warnings
  npg::model
  Carp
  List::MoreUtils

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett, E<lt>rmp@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 GRL, by Roger Pettett

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut

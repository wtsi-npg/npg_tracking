package npg::model::run;

use strict;
use warnings;
use base qw(npg::model Exporter);
use English qw(-no_match_vars);
use Scalar::Util qw(isweak weaken);
use Carp;
use POSIX qw(strftime);
use List::MoreUtils qw(none);
use List::Util qw(first);
use JSON;
use DateTime;
use DateTime::Format::Strptime;
use Readonly;

use npg::model::instrument;
use npg::model::instrument_format;
use npg::model::run_lane;
use npg::model::run_status;
use npg::model::annotation;
use npg::model::run_annotation;
use npg::model::event;
use npg::model::tag;
use npg::model::entity_type;
use npg::model::tag_frequency;
use npg::model::tag_run;
use npg::model::user;
use npg::model::run_read;

our $VERSION = '0';

Readonly::Scalar our $DEFAULT_SUMMARY_DAYS        => 14;
Readonly::Scalar my  $FOLDER_GLOB_INDEX           => 2;
Readonly::Scalar my  $PADDING                     => 4;
Readonly::Hash   our %TEAMS => ('2' => 'RAD', '1' => 'A',);
Readonly::Scalar our $DEFAULT_MANUFACTURER_NAME    => q{Illumina};
Readonly::Scalar our $SHOW_ALL_PARAM_VALUE         => q{all};

__PACKAGE__->mk_accessors(fields());
__PACKAGE__->has_a([qw(instrument instrument_format)]);
__PACKAGE__->has_many([qw(run_annotation)]);
__PACKAGE__->has_many_through([qw(annotation|run_annotation)]);

sub fields {
  return qw(id_run
            batch_id
            id_instrument
            expected_cycle_count
            actual_cycle_count
            priority
            id_run_pair
            is_paired
            team
            id_instrument_format
            flowcell_id
            folder_name
            folder_path_glob
           );
}

sub tags {
  my $self = shift;
  if(!$self->{tags}) {
    my $query = q{SELECT tf.frequency, t.tag, t.id_tag, tr.id_user, DATE(tr.date) AS date
                  FROM   tag_frequency tf, tag t, tag_run tr, entity_type e
                  WHERE  tr.id_run         = ?
                  AND    t.id_tag          = tr.id_tag
                  AND    tf.id_tag         = t.id_tag
                  AND    tf.id_entity_type = e.id_entity_type
                  AND    e.description     = ?
                  ORDER BY t.tag};
    $self->{tags} = $self->gen_getarray('npg::model::tag', $query, $self->id_run(), $self->model_type());
  }
  return $self->{tags};
}

sub init {
  my $self = shift;
  my $id   = $self->id_run() || q();

  if(!$id && $self->{'name'}) {
    $id = $self->{'name'};
  }

  if($id && $id =~ /^(IL|HS)\d+_\d+/smx ) {
    my ($id_match) = $id =~ /(\d+)$/smx;
    $self->id_run(0+$id_match);
  }
  return $self;
}

sub name {
  my $self     = shift;
  my $ins_name = $self->instrument->name() || q(unknown);
  my $id_run   = $self->id_run() || 0;
  my $id_run_format = length($id_run) < $PADDING ? q(%s_%04d) : q(%s_%d);
  return sprintf $id_run_format, (uc $ins_name), $id_run;
}

sub run_folder {
  my ($self) = @_;
  if (my $folder_name = $self->folder_name()) {
    return $folder_name;
  }
  my $loading_date = $self->loader_info->{'date'} || q{0000-00-00};
  my ($year, $month, $day) = $loading_date =~ /\d{2}(\d{2})-(\d{2})-(\d{2})/xms;
  $year  = sprintf '%02d', $year;
  $month = sprintf '%02d', $month;
  $day   = sprintf '%02d', $day;
  my $runfolder = $year.$month.$day.q{_}.$self->name();
  my $model = $self->instrument_format->model;
  if ($model eq 'HiSeq' || $model eq 'HiSeqX'){
    if ($self->hiseq_slot()) { $runfolder .= q(_) . $self->hiseq_slot(); }
    if ($self->flowcell_id()) { $runfolder .= q(_) . $self->flowcell_id(); }
  }elsif($model eq 'MiSeq'){
    if ($self->flowcell_id()) { $runfolder .= q(_A_) . $self->flowcell_id(); }
  }
  return $runfolder;
}

sub end {
  my $self        = shift;
  my $is_paired   = $self->is_paired();
  my $id_run_pair = $self->id_run_pair();

  if($is_paired && !$id_run_pair) {
    return 1;
  } elsif($is_paired && $id_run_pair) {
    return 2;
  }

  return q();
}

sub runs {
  my ( $self, $params ) = @_;
  # The run view might have cached the data.
  return $self->{runs} ? $self->{runs} : $self->list_runs($params);
}

sub list_runs {
  my ( $self, $params ) = @_;

  my $select_count = 0;
  my $query = $self->_create_query($select_count, $params);
  $query .= q[ ORDER BY r.id_run DESC];
  $query = $self->util->driver->bounded_select( $query,
                                                $params->{len},
                                                $params->{start});
  my $pkg   = ref $self;
  return $self->gen_getarray($pkg, $query);
}

sub count_runs {
  my ( $self, $params ) = @_;
  # The run view might have cached the data.
  return defined $self->{count_runs} ? $self->{count_runs} :
    $self->get_runs_count($params);
}

sub get_runs_count {
  my ( $self, $params ) = @_;

  $params ||= {};
  my $select_count = 1;
  my $query = $self->_create_query($select_count, $params);
  my $ref = $self->util->dbh->selectall_arrayref( $query );
  if ( defined $ref->[0] && defined $ref->[0]->[0] ) {
    return $ref->[0]->[0];
  }

  return;
}

sub _create_query {
  my ($self, $select_count, $params) = @_;

  my $id_instr_format = $params->{id_instrument_format};
  $id_instr_format ||= $SHOW_ALL_PARAM_VALUE;
  my $manufacturer_name = $params->{manufacturer};
  $manufacturer_name ||= $DEFAULT_MANUFACTURER_NAME;
  my $id_instr = $params->{id_instrument};
  my $id_status_dict = $params->{id_run_status_dict};

  my $pkg = ref $self;
  my $query = sprintf 'SELECT %s FROM %s AS r',
    $select_count ? q[COUNT(*)] : join(q[, ], map { q[r.] . $_ } $pkg->fields()),
    $pkg->table();

  my @where = ();
  # If run info for a particular instrument is requested, disregard the
  # instrument format and the manufacturer.
  if ( $id_instr && $id_instr =~ /\d+/xms ) {
    push @where, qq[r.id_instrument = $id_instr];
  } else {
    # If run info for a particular instrument format is requested, disregard
    # the manufacturer.
    if ( $id_instr_format =~ /\A\d+\z/xms ) {
      push @where, qq[r.id_instrument_format = $id_instr_format];
    }
    # If runs from a particular manufacturer are requested, select
    # on manufacturer name.
    if ( $manufacturer_name ne $SHOW_ALL_PARAM_VALUE ) {
      $query .= ' JOIN instrument_format AS inf' .
                ' ON r.id_instrument_format=inf.id_instrument_format' .
                ' JOIN manufacturer AS m' .
                ' ON inf.id_manufacturer=m.id_manufacturer';
      push @where, qq[m.name = '$manufacturer_name'];
    }
  }

  # Filter by current run status.
  if ( $id_status_dict && ($id_status_dict ne $SHOW_ALL_PARAM_VALUE) ) {
    $query .= ' JOIN run_status AS rs ON r.id_run=rs.id_run';
    push @where, qq[rs.id_run_status_dict=$id_status_dict AND rs.iscurrent=1];
  }

  if (@where) {
    $query .= ' WHERE ' . join ' AND ', @where;
  }

  return $query;
}

sub current_run_status {
  my $self = shift;

  if(!$self->{current_status}) {
    my $util  = $self->util();
    my $pkg   = 'npg::model::run_status';
    my $query = qq(SELECT @{[join q(, ), map { join q[.], q[rs], $_ } $pkg->fields()]},
                          rsd.description
                   FROM   @{[$pkg->table]} rs,
                          run_status_dict  rsd
                   WHERE  rs.id_run             = ?
                   AND    rs.id_run_status_dict = rsd.id_run_status_dict
                   AND    rs.iscurrent          = 1);
    my $ref = {};
    eval {
      my $dbh = $util->dbh();
      my $sth = $dbh->prepare($query);
      $sth->execute($self->id_run());
      $ref = $sth->fetchrow_hashref();
      1;

    } or do {
      carp $EVAL_ERROR;
      return;
    };

    $ref->{util} = $util;
    $self->{current_status} = $pkg->new($ref);
  }

  return $self->{current_status};
}

sub run_status_dict {
  my ( $self ) = @_;
  return $self->current_run_status()->run_status_dict();
}

sub run_statuses {
  my $self  = shift;

  if(!$self->{run_statuses}) {
    my $pkg   = 'npg::model::run_status';
    my $query = qq(SELECT @{[join q(, ), map { "rs.$_" } $pkg->fields()]},
                          rsd.description AS description
                   FROM   @{[$pkg->table()]} rs,
                          run_status_dict    rsd
                   WHERE  rs.id_run             = ?
                   AND    rs.id_run_status_dict = rsd.id_run_status_dict
                   ORDER BY date DESC);
    $self->{run_statuses} = $self->gen_getarray($pkg, $query, $self->id_run());
  }

  return $self->{run_statuses};
}

sub loader_info {
  my $self  = shift;

  if (!$self->{'loader_info'}) {
    my $dbh = $self->util->dbh();
    my $query = q{
      SELECT u.username    AS loader,
             DATE(rs.date) AS date
      FROM   user u,
             run_status rs,
             run_status_dict rsd
      WHERE  rs.id_run = ?
      AND    rs.id_run_status_dict = rsd.id_run_status_dict
      AND    rsd.description = 'run pending'
      AND    rs.id_user = u.id_user
    };
    my $sth = $dbh->prepare($query);
    $sth->execute($self->id_run());
    my $href = $sth->fetchrow_hashref();
    $self->{'loader_info'} = $href || {};
  }
  return $self->{'loader_info'};
}

sub attach_annotation {
  my ($self, $annotation) = @_;
  my $util     = $self->util();
  my $dbh      = $util->dbh();
  my $tr_state = $util->transactions();

  if(!$annotation) {
    croak q(No annotation to save);
  }

  my $run_annotation = npg::model::run_annotation->new({
                                                      'util'       => $util,
                                                      'id_run'     => $self->id_run(),
                                                      'annotation' => $annotation,
                                                      });
  if(!$self->id_run()) {
    push @{$self->{'annotations'}}, $annotation;
    return 1;
  }

  $util->transactions(0);
  eval {
    my $requestor = $util->requestor();
    $run_annotation->create();
    1;

  } or do {
    $util->transactions($tr_state);
    $dbh->rollback();
    croak $EVAL_ERROR;
  };

  $util->transactions($tr_state);

  eval {
    $tr_state and $dbh->commit();
    1;

  } or do {
    $dbh->rollback();
    croak $EVAL_ERROR;
  };

  return 1;
}

sub run_lanes {
  my $self  = shift;

  if(!$self->{run_lanes}) {
    $self->{run_lanes} = [];
    my $pkg   = 'npg::model::run_lane';
    my $query = qq(SELECT @{[join q(, ), $pkg->fields()]}
                   FROM   @{[$pkg->table()]}
                   WHERE  id_run = ?
                   ORDER BY position);
    my $rls = $self->gen_getarray($pkg, $query, $self->id_run());
    for my $rl (@{$rls}) {
      $rl->{run}    = isweak($self) ? $self : weaken($self);
      push @{$self->{run_lanes}}, $rl;
    }
  }

  return $self->{run_lanes};
}

sub runs_on_batch {
  my ($self, $batch_id) = @_;

  if (defined $batch_id) {
    my $temp = int $batch_id; # strings will be converted to zeros
    ($temp eq $batch_id) or croak "Invalid batch id '$batch_id'";
    ($batch_id > 0) or croak "Invalid negative or zero batch id '$batch_id'";
  } else {
    $batch_id = $self->batch_id();
  }

  my $ids = [];
  if ($batch_id) { # default batch id for a run is zero
    my $pkg   = 'npg::model::run';
    my $query = qq(SELECT @{[join q(, ), $pkg->fields()]}
                   FROM   @{[$pkg->table()]}
                   WHERE  batch_id = ?
                   ORDER BY id_run asc);
    $ids = $self->gen_getarray($pkg, $query, $batch_id);
  }

  return $ids;
}

sub is_batch_duplicate {
  my ($self, $batch_id) = @_;

  defined $batch_id or croak 'Batch id should be given';

  $batch_id or return 0; # if zero, then nothing to compare to

  my @runs = @{$self->runs_on_batch($batch_id)};
  my @run_statuses =
    grep { $_ }
    map  { $_->current_run_status->run_status_dict->description }
    @runs;

  (@runs == @run_statuses) or return 1;  # some runs might have no current status

  return scalar
         grep { $_ !~ /run[ ]cancelled|run[ ]stopped[ ]early/xms }
         @run_statuses;
}

sub run_finished_on_instrument {
  my ($self) = @_;
  my $query = q(SELECT rs.date
                FROM   run_status rs,
                       run        r,
                       run_status_dict rsd
                WHERE  r.id_run              = ?
                AND    r.id_run              = rs.id_run
                AND    rs.id_run_status_dict = rsd.id_run_status_dict
                AND    rsd.description       in ('run cancelled', 'run stopped early', 'run mirrored'));

  my $dbh = $self->util->dbh();
  my $sth = $dbh->prepare($query);
  $sth->execute($self->id_run());
  my $date;
  my $datenum;
  while (my @row = $sth->fetchrow_array()) {
    my ($y,$m,$d,$h,$min,$s) = $row[0] =~ /(\d{4})-(\d{2})-(\d{2})[ ](\d{2}):(\d{2}):(\d{2})/xms;
    my $temp_datenum = $y.$m.$d.$h.$min.$s;
    if (!$datenum || $datenum > $temp_datenum) {
      $datenum = $temp_datenum;
      $date = $row[0];
    }
  }

  $date ||= $self->dbh_datetime();

  return $date;
}

sub id_user {
  my ($self, $id_op) = @_;
  if(defined $id_op) {
    $self->{id_user} = $id_op;
  }

  if($self->{id_user}) {
    return $self->{id_user};
  }

  if($self->current_run_status()) {
    return $self->current_run_status->id_user();
  }

  return;
}

sub run_pair {
  my $self = shift;

  if(!$self->{run_pair}) {
    my $pkg   = ref $self;
    my $query = qq[SELECT @{[join q(, ), map { "r.$_" } $self->fields()]}
                   FROM   @{[$self->table()]} r,
                          run_status          rs,
                          run_status_dict     rsd
                   WHERE  (r.id_run         = ?
                           OR r.id_run_pair = ?)
                   AND    r.id_run              = rs.id_run
                   AND    rs.id_run_status_dict = rsd.id_run_status_dict
                   AND    rs.iscurrent          = 1
                   AND    rsd.description NOT IN ('run cancelled', 'data discarded')];

    $self->{run_pair} = $self->gen_getarray($pkg,
                                           $query,
                                           $self->id_run_pair(),
                                           $self->id_run())->[0];
  }

  return $self->{run_pair};
}

sub is_paired_read {
  my $self = shift;

  if(!exists $self->{is_paired_read}) {

    if($self->is_paired()){
      $self->{is_paired_read} = 1;
      return $self->{is_paired_read};
    }

    my $tags_ref = $self->tags();
    foreach my $tag (@{$tags_ref}){
      my $tag_value = $tag->tag();

      if($tag_value eq q{paired_read}){
        $self->{is_paired_read} = 1;
        last;
      }elsif($tag_value eq q{single_read}){
        $self->{is_paired_read} = 0;
        last;
      }
    }
    if(!exists $self->{is_paired_read}){

      $self->{is_paired_read} = undef;
    }
  }

  return $self->{is_paired_read};
}

sub create {
  my $self = shift;
  my $util = $self->util();
  my $dbh  = $util->dbh();

  #########
  # disable transactions (or rather start one big one...?)
  #
  my $tr_state = $util->transactions();
  $util->transactions(0);

  eval {
    if (!$self->validate_team($self->{team})) {
      croak 'Invalid team name ' . $self->{team};
    }
    $self->{batch_id} ||= 0;
    if ($self->is_batch_duplicate($self->{batch_id})) {
      croak sprintf
        'Batch %i might have been already used for an active run', $self->{batch_id};
    }
    $self->{is_paired}          ||= 0;
    $self->{actual_cycle_count} ||= 0;
    $self->{id_instrument_format} = $self->instrument->id_instrument_format();
    $self->calculate_expected_cycle_count_by_read_cycle();
    $self->SUPER::create();
    my $id = $self->id_run;
    $self->_create_lanes();

    #########
    # save any annotations
    #
    for my $annotation (@{$self->{annotations}||[]}) {
      $annotation->id_run($self->id_run());
      $annotation->create();
    }

    #########
    # create a new status
    #
    my $run_status_dict = npg::model::run_status_dict->new({
                                                          util        => $util,
                                                          description => 'run pending',
                                                          });
    my $run_status      = npg::model::run_status->new({
                                                      util               => $util,
                                                      id_run             => $id,
                                                      id_run_status_dict => $run_status_dict->id_run_status_dict(),
                                                      iscurrent          => 1,
                                                      id_user            => $self->id_user(),
                                                      });
    $run_status->create();

    #########
    # create tags
    #
    my $paired_read = $self->{paired_read};
    my $multiplex   = $self->{multiplex_run};
    my $fc_slot     = $self->{fc_slot};
    my @tags;
    if($paired_read){
      push @tags, q{paired_read};
    }else{
      push  @tags, q{single_read};
    }
    if($multiplex){
      push @tags, q{multiplex};
    }

    # radio button selection for flowcell slots (if any)
    if($fc_slot){
      push @tags, $fc_slot;
    }
    $self->save_tags(\@tags);

    #########
    # create run_reads
    #    
    $self->_create_run_reads();

    1;

  } or do {
    #########
    # re-enable transactions
    #
    $util->transactions($tr_state);

    if($tr_state) {
      $dbh->rollback();
    }
    croak $EVAL_ERROR;
  };

  $util->transactions($tr_state);
  eval {
    $tr_state and $dbh->commit();
    1;

  } or do {
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR;
  };

  return 1;
}

sub _create_run_reads{
  my $self = shift;

  my $num_reads = $self->num_reads();
  my $read_cycle_count = $self->{read_cycle_count};

  foreach my $read_order (1..$num_reads){
     my $run_read = npg::model::run_read->new({
                   util                 => $self->util,
                   id_run               => $self->id_run,
                         read_order           => $read_order,
                         expected_cycle_count => $read_cycle_count->{$read_order},
                         intervention         => 0,
                  });
    $run_read->create();
  }

  return;
}

sub num_reads {
  my $self = shift;

  if(!exists $self->{num_reads}){
      my $num_reads = 1;
      if($self->{paired_read}){
         $num_reads++;
      }

      if($self->{multiplex_run}){
         $num_reads++;
      }
      $self->{num_reads} = $num_reads;
  }
  return $self->{num_reads};
}

sub calculate_expected_cycle_count_by_read_cycle {
    my $self = shift;

    my $num_reads = $self->num_reads();
    my $read_cycle_count_href = $self->{read_cycle_count};
    my $expected_cycle_count = 0;
    foreach my $read_order (1..$num_reads){
      my $read_cycle_count = $read_cycle_count_href->{$read_order};
      if($read_cycle_count){
          $expected_cycle_count +=$read_cycle_count;
      }else{
         $self->expected_cycle_count(0);
         return $self->expected_cycle_count();
      }
    }
    $self->expected_cycle_count($expected_cycle_count);
    return $expected_cycle_count;
}

sub _create_lanes {
  my $self     = shift;
  my $util     = $self->util();
  my $dbh = $util->dbh();

  #########
  # save lane information
  #
  if($self->{'run_lanes'}) {
    my $library_names_json = $self->{library_names} || q{{}};
    my $study_names_json =  $self->{study_names} || q{{}};
    my $st_library_names  = from_json($library_names_json);
    my $st_study_names = from_json($study_names_json);

    for my $run_lane (@{$self->{'run_lanes'}}) {
      $run_lane->id_run($self->id_run());
      $run_lane->create();
    }

    #########
    # Cache library & study names from the sample-tracking database so we can search on them
    #
    for my $st_library_name (keys %{$st_library_names}) {
      $dbh->do(q(INSERT INTO st_cache(id_run,type,content) VALUES(?,'library',?)),
              {},
              $self->id_run(),
              $st_library_name);
    }

    for my $st_study_name (keys %{$st_study_names}) {
      $dbh->do(q(INSERT INTO st_cache(id_run,type,content) VALUES(?,'project',?)),
              {},
              $self->id_run(),
              $st_study_name);
    }
  }
  return 1;
}

sub save_tags {
  my ($self, $tags_to_save, $requestor) = @_;
  my $util        = $self->util();
  $requestor    ||= $util->requestor();
  my $dbh         = $util->dbh();
  my $entity_type = npg::model::entity_type->new({
                                                  description => $self->model_type(),
                                                  util => $util,
                                                });
  my $tr_state    = $util->transactions();
  $util->transactions(0);

  eval {
    my $date = strftime q(%Y-%m-%d %H:%M:%S), localtime;
    for my $tag (@{$tags_to_save}) {
      $tag = npg::model::tag->new({
                                  tag  => $tag,
                                  util => $util,
                                  });
      if (!$tag->id_tag()) {
        $tag->create();
      }

      my $tag_run = npg::model::tag_run->new({
                                            util    => $util,
                                            id_tag  => $tag->id_tag(),
                                            id_run  => $self->id_run(),
                                            date    => $date,
                                            id_user => $requestor->id_user(),
                                            });
      $tag_run->save();
      my $tag_freq = 'npg::model::tag_frequency'->new({
                                                      id_tag         => $tag->id_tag(),
                                                      id_entity_type => $entity_type->id_entity_type,
                                                      util           => $util,
                                                     });
      my $freq = $dbh->selectall_arrayref(q{SELECT COUNT(id_tag) FROM tag_run WHERE id_tag = ?}, {}, $tag->id_tag())->[0]->[0];
      $tag_freq->frequency($freq);
      $tag_freq->save();
    }
    1;

  } or do {
    $util->transactions($tr_state);
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR . q{<br />rolled back attempt to save info for the tags for run } . $self->id_run();
  };

  $util->transactions($tr_state);
  eval {
    $tr_state and $dbh->commit();
    1;

  } or do {
    croak $EVAL_ERROR;
  };

  return 1;
}

sub remove_tags {
  my ($self, $tags_to_remove, $requestor) = @_;
  my $util     = $self->util();
  $requestor ||= $util->requestor();
  my $dbh      = $util->dbh();
  my $tr_state = $util->transactions();
  $util->transactions(0);

  eval {
    my $entity_type = npg::model::entity_type->new({
                                                  description => $self->model_type(),
                                                  util        => $util,
                                                  });
    for my $tag (@{$tags_to_remove}) {
      $tag = npg::model::tag->new({
                                  tag  => $tag,
                                  util => $util,
                                  });
      my $tag_run = npg::model::tag_run->new({
                                            id_tag => $tag->id_tag(),
                                            id_run => $self->id_run(),
                                            util   => $util,
                                            });
      $tag_run->delete();

      my $tag_freq = npg::model::tag_frequency->new({
                                                    id_tag         => $tag->id_tag(),
                                                    id_entity_type => $entity_type->id_entity_type,
                                                    util           => $util,
                                                    });
      my $freq = $dbh->selectall_arrayref(q{SELECT COUNT(id_tag) FROM tag_run WHERE id_tag = ?}, {}, $tag->id_tag())->[0]->[0];
      $tag_freq->frequency($freq);
      $tag_freq->save();
    }
    1;

  } or do {
    $util->transactions($tr_state);
    $tr_state and $dbh->rollback();
    croak $EVAL_ERROR . q{Rolled back attempt to delete info for the tags for run } . $self->id_run();
  };

  $util->transactions($tr_state);
  eval {
    $tr_state and $dbh->commit();
    1;

  } or do {
    croak $EVAL_ERROR;
  };

  return 1;
}

sub is_in_staging {
  my ($self) = @_;
  return $self->has_tag_with_value(q{staging});
}

sub has_tag_with_value {
  my ($self,$value) = @_;
  my $tags = $self->tags();
  foreach my $tag (@{$tags}) {
    if ($tag->tag() eq $value) {
      return 1;
    }
  }
  return 0;
}

sub hiseq_slot {
  my ($self) = @_;

  if(! exists $self->{hiseq_slot}){

    my $hiseq_slot;
    if( $self->has_tag_with_value(q{fc_slotA}) ){
       $hiseq_slot = q{A};
    }elsif( $self->has_tag_with_value(q{fc_slotB}) ){
       $hiseq_slot = q{B};
    }
    $self->{hiseq_slot} = $hiseq_slot;
  }
  return $self->{hiseq_slot};
}

#############
# also if prelim complete for first end
sub has_analysis_complete {
  my ($self,$run_pair_check) = @_;
  my $statuses = $self->run_statuses();
  foreach my $status (@{$statuses}) {
    if ($status->{description} eq q{analysis prelim complete}) {
      return 1;
    }
    if ($status->{description} eq q{analysis complete}) {
      return 1;
    }
    if ($status->{description} eq q{secondary analysis in progress}) {
      return 1;
    }
  }
  if (!$run_pair_check && $self->id_run_pair() && $self->run_pair->has_analysis_complete(1)) {
    return 1;
  }
  return 0;
}

sub has_run_archived {
  my ($self) = @_;
  my $statuses = $self->run_statuses();
  foreach my $status (@{$statuses}) {
    if ($status->{description} eq q{run archived}) {
      return 1;
    }
  }
  return 0;
}

sub has_analysis_in_progress {
  my ($self) = @_;
  my $statuses = $self->run_statuses();
  foreach my $status (@{$statuses}) {
    if ($status->{description} eq q{analysis in progress}) {
      return 1;
    }
  }
  return 0;
}

sub potentially_stuck_runs {
  my ( $self ) = @_;
  if ( ! $self->{potentially_stuck_runs} ) {
    $self->{potentially_stuck_runs} = $self->runs()->[0]->current_run_status()->potentially_stuck_runs();
  }
  return $self->{potentially_stuck_runs};
}

sub teams {
  my $self = shift;
  return map {$TEAMS{$_}} (sort {$a <=> $b} keys %TEAMS);
}

sub validate_team {
  my ($self, $team) = @_;
  if(!$team || (none { $team eq $_ } $self->teams())) {
    return 0;
  }
  return 1;
}

sub is_dev {
  my $self= shift;
  return ($self->team() && $self->team() eq 'RAD') ? 1 : 0;
}

sub staging_server_name {
  my $self = shift;
  if ($self->folder_path_glob) {
    my @components = split m{/}smx, $self->folder_path_glob;
    return $components[$FOLDER_GLOB_INDEX];
  }
  return;
}

sub get_instruments {
  my ($self) = @_;

  if (!defined $self->{instruments}) {
    croak q(Instrument array is undefined);
  }

  return $self->{instruments};
}

sub sort_instruments {
  my ($self, $instruments)=@_;

  my @current_instruments = sort _compare_alphanumeric @{$instruments};

  my @sorted_instruments;
  my @nonnv;
  # move NV to the top
  foreach my $instrument (@current_instruments){
    if ($instrument->name =~ /^NV/xms){
      push @sorted_instruments, $instrument;
    }else {
      push @nonnv, $instrument;
    }
  }
  push @sorted_instruments, @nonnv;

  return \@sorted_instruments;
}

sub _compare_alphanumeric {
  # separate alphabetic part [0] and numeric part [1]
  my @a = $a->name =~ m/([a-z]*)([0-9]*)/gixms;
  my @b = $b->name =~ m/([a-z]*)([0-9]*)/gixms;

  my $return = 0;
  #compare alphabetic part
  if (uc $a[0] gt uc $b[0]){
    $return += 1;
  }elsif (uc $b[0] gt uc $a[0]){
    $return -= 1;
  # if alphabetic parts are identical, compare numeric part
  }elsif ($a[1] > $b[1]){
    $return += 1;
  }else{
    $return -= 1;
  }
  return $return;
}

1;
__END__

=head1 NAME

npg::model::run

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 fields - accessors for this table/class

  my @aFields = $oPkg->fields();
  my @aFields = npg::model::<pkg>->fields();

=head2 name - formatted name of this run

  my $name = $oRun->name();

=head2 end - which end / read (paired-end runs only)

 my $iEnd = $oRun->end();

 $iEnd = 1 if run is paired and has no paired run id
 $iEnd = 2 if run is paired and has a paired run id

=head2 instrument - npg::model::instrument used for this run

  my $oInstrument = $oRun->instrument();

=head2 hiseq_slot - return slot number of hiseq instrument either A or B, or no slot number

=head2 instrument_format - npg::model::instrument_format used for this run

  my $oInstrumentFormat = $oRun->instrument_format();

=head2 current_run_status - the most recent npg::model::run_status for this run

  my $oCurrentRunStatus = $oRun->current_run_status();

=head2 run_statuses - arrayref of npg::model::run_statuses for the history of this run

  my $arRunStatuses = $oRun->run_statuses();

=head2 annotations - arrayref of npg::model::annotations for this run

  my $arAnnotations = $oRun->annotations();

=head2 run_annotations - arrayref of npg::model::run_annotation links for this run

  my $arRunAnnotations = $oRun->run_annotations();
  my $arAnnotations    = [map { $_->annotation() } @{$oRunAnnotations}];

=head2 attach_annotation - add an annotation to this run

  my $oAnnotation = npg::model::annotation->new({
     'util'    => $oUtil,
     'comment' => q(My annotation text),
  });
  $oRun->attach_annotation($oAnnotation);

=head2 run_lanes - arrayref of npg::model::run_lanes for this run

  my $arRunLanes = $oRun->run_lanes();

=head2 runs - arrayref of all npg::model::runs

  my $arRuns = $oRun->runs($params);

  Returns a list of cached run models or retrieves a new list in accordance with
  the parameters of the query, see C<get_runs>. Bounds the retrieved list
  according to C<start> and C<len> parameters.

=head2 list_runs - arrayref of all npg::model::runs

  my $arRuns = $oRun->list_runs($params);

  Retrieves and returns a list or run models in accordance with the parameters
  of the query.

=head2 count_runs

  my $iRunCount = $oRun->count_runs($params);

  Returns a cached value or retrieves a new one in accordance with
  the parameters of the query, see C<get_runs_count>.

=head2 get_runs_count

  my $iRunCount = $oRun->count_runs($params);

  Returns the cout of runs according to the parameters of the query.

=head2 runs_on_batch

  Returns an array reference of npg::model::run objects associated with batch_id given as
  an argument or, if the argument is not defined or zero, with this object's batch id if known
  An empty array is returned if batch id to query on is not defined or if no runs are associated
  with the batch id.

  Error if batch id is not a positive integer.

  my $arRunsOnBatch = $oRun->runs_on_batch();
  my $arRunsOnBatch = $oRootRun->runs_on_batch($iBatchId);

  Effectively yields runs performed on the same flowcell

=head2 is_batch_duplicate

 Given batch id, checks whether an active run associated with this batch id already exists.
 Active run is defined as a run that has no current status or its current status is not
 either 'run cancelled' or 'run stopped early'.

=head2 id_user - holder for storing the id_user, particularly for creating new run_status on a new run

  $oRun->id_user($iIdUser);
  my $iIdUser = $oRun->id_user();

=head2 run_pair - an npg::model::run paired with this one

  my $oComplementRun = $oRun->run_pair();

  For unpaired runs this returns a unpopulated run object, testable for example by checking its id_run.
  
=head2 is_paired_read - If paired run, return 1. If single run, check paired_read or single_read tags available or not, then return 1 or 0. For single run without single_read or paired_read tags available, return undef 

=head2 create
  Creates a new database record for a run, corresponding database records for run lanes
  and run tags, assigns the current status of this run to 'run pending'.

  Error if an invalid team is given or if the new run is associated with a batch is that
  is already associated with an active run as defined in documentation for the
  is_batch_duplicate method. In case of en error all database changes are rolled back.

  $oRun->create();

=head2 init - support for loading runs by run_lane

  my $oRun = npg::model::run->new({
    'util' => $oUtil,
    'name' => 'IL3_0063',
  });

=head2 tags - returns an arrayref containing tag objects, that have been linked to this run, that also have 'date' the tag was saved for this run, 'id_user' of the person who gave this run this tag, and frequency this tag has been used on runs

  my $aTags = $oRun->tags();

=head2 save_tags - saves tags for run. Expects an arrayref of tags and then goes out to save the tag if not already in database, updates the frequency seen for run entity type, and saves in join table with id_user and date when saved

  eval { $oRun->save_tags(['tag1','tag2'], $oRequestor); };

=head2 remove_tags - removes tags for a run. Expects an arrayref of tags and then removes the tag_run entry and updates the frequency

  eval { $oRun->remove_tags(['tag1','tag2'], $oRequestor); };

=head2 run_finished_on_instrument
=head2 run_folder - returns a run folder name (no HTML formating),

  my $sRunFolder = $oRun->run_folder();

=head2 runfolder - returns a run folder name, with HTML font color=red tags if the run is at a status of 'run pending'

  my $sRunFolder = $oRun->runfolder();

=head2 is_in_staging - returns a boolean dependent on if there is a staging tag present

=head2 has_tag_with_value - returns a boolean dependent on whether the given tag is present

=head2 has_analysis_complete - returns a boolean dependent on if there is at least one analysis complete, analysis prelim complete, or secondary analysis in progress status

=head2 has_analysis_in_progress -  - returns true if one of the run statuses is 'analysis in progress'; otherwise returns false

=head2 has_run_archived - returns a boolean dependent on if there is at least one run archived status

=head2 calculate_expected_cycle_count_by_read_cycle - calculate expected cycle count for this run based on the cycle_count numbers for each read. If any of read cycle number not available, return 0

=head2 num_reads - calculate number of reads of this run based on multplex_run and paired read or not

=head2 potentially_stuck_runs

return runs which are potentially stuck due to the length of time at their current run status - see method in model::run_status

=head2 run_status_dict

provides a short cut method to the run status dict object providing the description for the current run status

=head2 teams ordered list of teams

=head2 validate_team

=head2 loader_info

returns a hash containing the date of the run pending status under the 'date' key
and loader user name under the 'loader' key

=head2 is_dev method returns true if the run belongs to R&D team, false otherwise

=head2 staging_server_name - from runfolder glob

=head2 get_instruments

returns an ArrayRef of instrument objects

  my $instruments = $oRun->get_instruments();

=head2 sort_instruments

returns ArrayRef $instruments sorted by name, with NovaSeq instruments displayed first, or throws an error if
$instruments is undefined

  my $sorted_instruments = $oRun->sort_instruments($instruments);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item strict

=item warnings

=item base

=item npg::model

=item English

=item Carp

=item npg::model::instrument

=item npg::model::instrument_format

=item npg::model::run_lane

=item npg::model::run_status

=item npg::model::annotation

=item npg::model::run_annotation

=item npg::model::event

=item npg::model::tag

=item npg::model::entity_type

=item npg::model::tag_frequency

=item npg::model::tag_run

=item npg::model::user

=item Readonly

=item JSON

=item List::MoreUtils

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=over

=item Roger Pettett

=item Marina Gourtovaia

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006-2012, 2013,2014,2015,2016,2017,2020,2021,2022,2025 Genome Research Ltd.

This file is part of NPG.

NPG is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .

=cut

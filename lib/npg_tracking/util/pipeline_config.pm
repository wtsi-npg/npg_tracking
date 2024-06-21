package npg_tracking::util::pipeline_config;

use Moose::Role;
use MooseX::Getopt::Meta::Attribute::Trait::NoGetopt;
use Carp;
use Config::Any;
use FindBin qw($Bin);
use File::Spec::Functions qw(catfile);
use Readonly;
use YAML::XS;

use npg_tracking::util::types;
use npg_tracking::util::abs_path qw(abs_path);
use npg_tracking::data::reference;

our $VERSION = '0';

Readonly::Scalar my $CONF_DIR            => q(data/config_files);
Readonly::Scalar my $PRODUCT_CONFIG_FILE => q(product_release.yml);
Readonly::Scalar my $CONFIG_DEFAULT      => q(default);
Readonly::Scalar my $CONFIG_TERTIARY     => q(tertiary);

=head1 NAME

npg_tracking::util::pipeline_config

=head1 SYNOPSIS

=head1 DESCRIPTION

A Moose role providing accessors for the pipeline's configuration files.

If the consuming object has methods for logging defined (see
WTSI::DNAP::Utilities::Loggable) or has an logger accessor,
these methods are used, via the logger if appropriate, in preference
to other ways of logging messages and raising errors.

=head1 SUBROUTINES/METHODS

=head2 local_bin

  Description: A read-only attribute, an absolute path of the directory
               containing the currently running script. Cannot be set
               via the constructor. Will be disregarded by the MooseX::Getopt
               framework for the purpose of using as a script argument.

  Returntype : Str

=cut

has 'local_bin' => (
  traits     => ['NoGetopt'],
  isa        => 'Str',
  is         => 'ro',
  lazy_build => 1,
  init_arg   => undef,
);
sub _build_local_bin {
  return abs_path($Bin);
}

=head2 conf_path

  Description: A read-only attribute, an absolute path of the directory
               with the pipeline's configuration files.
               Defaults to data/config_files relative to the bin directory
               of the current script.

  Returntype : Str

=cut

has 'conf_path' => (
  isa           => 'NpgTrackingDirectory',
  is            => 'ro',
  lazy_build    => 1,
  documentation => 'A full path of the directory containing config files',
);
sub _build_conf_path {
  my $self = shift;
  return abs_path($self->local_bin . "/../$CONF_DIR");
}

=head2 product_conf_file_path

  Description: A read-only attribute, an absolute path of the product release
               configuration file.
               Defaults to data/config_files/product_release.yml
               relative to the bin directory of the current script.

  Returntype : Str

=cut

has 'product_conf_file_path' => (
  isa           => 'NpgTrackingReadableFile',
  is            => 'ro',
  required      => 1,
  lazy_build    => 1,
  documentation => 'A full path of the product configuration file',
);
sub _build_product_conf_file_path {
  my ($self) = @_;
  return $self->conf_file_path($PRODUCT_CONFIG_FILE);
}

=head2 conf_file_path

  Arg [1]    : Str
               Configuration file name.

  Example    : $obj->conf_file_path('config.yml')

  Description: Given the pipeline configuration file name,
               returns an absolute path of the configuration
               file. Raises an error if the file does not exist.

  Returntype : Str

=cut

sub conf_file_path {
  my ($self, $conf_name) = @_;
  my $path = catfile($self->conf_path(), $conf_name);
  $path ||= q{};
  if (!$path || !-f $path) {
    $self->_log_message("File $path does not exist or is not readable", 'logcroak');
  }
  return $path;
}

=head2 read_config

  Arg [1]    : Str
               A path of the configuration file
 
  Example    : $obj->read_config('some/config.yml')
  Description: Reads and parses the file (Config::Any is used)
               and returns the content of the file as a hash.

  Returntype : Hash

=cut

sub read_config {
  my ($self, $path) = @_;
  my $config = Config::Any->load_files({files => [$path], use_ext => 1, });
  if ( scalar @{ $config } ) {
    $config = $config->[0]->{ $path };
  }
  return $config;
}

=head2 default_study_config

  Example    : $obj->study_config();
  Description: Returns a default config, which is normally used as a fall-back
               position when a study-specific config is not available. If the
               default section of the study configuration file is not present,
               an empty hash is returned.

  Returntype : Hash

=cut

sub default_study_config {
  my $self = shift;
  my $config = $self->_product_config->{$CONFIG_DEFAULT};
  return defined $config ? $config : {};
}

=head2 study_config

  Arg [1]    : st::api::lims
  Arg [2]    : An optional boolean flag, enforces a strict mode if true.
               If set to true, only the study section of the configuration
               file is parsed, ie the default section is disregarded.

  Example    : $obj->study_config($lims);
               $obj->study_config($lims, 1);
  Description: Returns a study-specific config or, unless the strict mode is enforced,
               a default config. Therefore, one cannot rely on study_id key being
               defined in the obtained data structure.
               No error if neither study nor default config is available, an empty
               hash is returned in this case.

  Returntype : Hash

=cut

sub study_config {
  my ($self, $lims, $strict) = @_;

  $lims or $self->_log_message(
    'st::api::lims object for a product is required', 'logcroak');

  my $with_spiked_control = 0;

  #####
  # If we were to process a pool as a single library, and all
  # libraries in a pool belonged to the same study, passing
  # false with_spiked_control flag will allow for retrieving
  # a correct single study identifier. 
  my @study_ids = $lims->study_ids($with_spiked_control);

  @study_ids or
    $self->_log_message('Failed to get a study_id for ' . $lims->to_string, 'logcroak');
  (@study_ids == 1) or
    $self->_log_message('Multiple study ids for ' . $lims->to_string, 'logcroak');
  my $study_id = $study_ids[0];

  my @study_configs = grep { $_->{study_id} eq $study_id }
                      @{$self->_product_config->{study}};
  my $study_config = {};

  if (@study_configs) {
    if (@study_configs > 1) {
      $self->_log_message("Multiple configurations for study $study_id", 'logcroak');
    }
    $study_config = $study_configs[0];
  } elsif (!$strict) {
    $study_config = $self->default_study_config();
    $self->_log_message("Using the default configuration for study $study_id", 'debug');
  }

  return $study_config;
}

=head2 find_study_config

  Arg [1]    : npg_pipeline::product

  Example    : $obj->find_study_config($product)
  Description: Returns a study-specific config or a default config. Therefore,
               one cannot rely on study_id key being defined in the obtained
               data structure. Error if neither study nor default config is
               available.

  Returntype : Hash

=cut

sub find_study_config {
  my ($self, $product) = @_;

  my $sc = $self->study_config($product->lims);
  if (! keys %{$sc}) {
    $self->_log_message(
      'No release configuration was defined for study for ' .
      $product->rpt_list() . ' and no default was defined', 'logcroak');
  }

  return $sc;
}

=head2 find_tertiary_config

  Arg [1]    : npg_pipeline::product

  Example    : $obj->find_tertiary_config($product)
  Description: Returns a study and reference specific tertiary analysis config
               or a default study tertiary config aslong as a reference is set
               for a product and a relevant config exists. Therefore one cannot
               rely on keys being defined in the obtained data structure.

  Returntype : Hash

=cut

sub find_tertiary_config {
  my ($self, $product) = @_;

  my $sc = $self->find_study_config($product);

  my $tc = {};
  if($sc->{$CONFIG_TERTIARY} && $sc->{study_id}) {
    my $ref_genome = $product->lims->reference_genome();

    my ($species,$ref);
    if ($ref_genome) {
      my $r = npg_tracking::data::reference->new();
      ($species, $ref) = $r->parse_reference_genome($ref_genome);

      if($species && $ref && $sc->{$CONFIG_TERTIARY}->{$species}->{$ref}) {
        $tc = $sc->{$CONFIG_TERTIARY}->{$species}->{$ref};
      } elsif ($sc->{$CONFIG_TERTIARY}->{$CONFIG_DEFAULT}) {
        $tc = $sc->{$CONFIG_TERTIARY}->{$CONFIG_DEFAULT};
      }
    }
  }

  return $tc;
}

has '_product_config' => (
  isa        => 'HashRef',
  is         => 'ro',
  init_arg   => undef,
  lazy_build => 1,
);
sub _build__product_config {
  my ($self) = @_;
  return $self->read_config($self->product_conf_file_path);
}

sub _log_message {
  my ($self, $message, $method) = @_;
  $method  ||= 'warn';
  $message ||= q[];
  $self->can($method) ? $self->$method($message) :
    ($self->can('logger') ? $self->logger()->$method($message) :
    ($method =~ /croak/xms ? croak $message : carp $message));
  return;
}

no Moose::Role;

1;

__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

This module load and parses any type of configuration files.
This functionality is provided by the Config::Any Perl module,
hence we have little control of the process. It is important
that parsing of YAML files is NOT done with YAML::Syck (we
do not want YAML false and true values converted to Perl
'false' and 'true' strings). If YAML::XS is present,
the parser seems to work correctly. Therefore, an explicit
YAML::XS import is used here.

=head1 DEPENDENCIES

=over

=item Moose::Role

=item MooseX::Getopt::Meta::Attribute::Trait::NoGetopt

=item Carp

=item Config::Any

=item File::Spec::Functions 

=item FindBin

=item Readonly

=item YAML::XS

=item npg_tracking::util::types

=item npg_tracking::util::abs_path

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia
Keith James

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2019, 2020 Genome Research Ltd.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

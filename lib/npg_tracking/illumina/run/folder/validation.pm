#########
# Author:        gq1
# Created:       2010-05-05
#

package npg_tracking::illumina::run::folder::validation;

use Moose;
use Carp;
use English qw{-no_match_vars};
use npg::api::run;

with qw{npg_tracking::illumina::run::short_info};

our $VERSION = '0';

has 'no_npg_check'=>  ( isa            => q{Bool},
                         is            => q{rw},
                         documentation => q{option to stop checking run_folder from npg},
                         default       => 0,
                       );

has 'npg_api_run' =>  ( isa => q{npg::api::run},
                        is => q{rw},
                        lazy_build => 1,
                        documentation => 'npg api run object',
                       );

sub _build_npg_api_run {
  my $self = shift;
  return npg::api::run->new({id_run => $self->id_run,});
}

sub check{
  my $self = shift;

  my $run_folder = $self->run_folder();
  if($self->no_npg_check){
    carp "Run folder $run_folder will not be checked by NPG";
    return 1;
  }

  my $run_folder_npg;
  eval{
    $run_folder_npg = $self->npg_api_run->run_folder();
    1;
  } or do {
    carp $EVAL_ERROR;
    return;
  };

  if(! ($run_folder eq $run_folder_npg )){
    carp "Run folder $run_folder does not match $run_folder_npg from NPG";
    return;
  }

  return 1;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

npg_tracking::illumina::run::folder::validation

=head1 VERSION

=head1 SYNOPSIS

$validation = npg_tracking::illumina::run::folder::validation->new( run_folder => $run_folder, );
$validation = npg_tracking::illumina::run::folder::validation->new( run_folder => $run_folder, no_npg_check => 1,);
$validation->check();

=head1 DESCRIPTION

Given a run_folder, and get the final digits of it to be the id_run, check this is genuine or not in NPG

=head1 SUBROUTINES/METHODS

=head2 check

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item Moose

=item Carp

=item English -no_match_vars

=item npg_tracking::illumina::run::folder::validation

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Guoying Qi

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Guoying Qi

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

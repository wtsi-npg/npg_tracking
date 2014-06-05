#########
# Author:        jo3
# Created:       2010-04-28

package Monitor::Instrument;

use Moose;
with 'Monitor::Roles::Schema';
with 'Monitor::Roles::Username';
with 'MooseX::Getopt';

use Carp;
use MooseX::StrictConstructor;
use POSIX qw(strftime);

use npg_tracking::illumina::run::folder::validation;

our $VERSION = '0';


has ident => (
    is         => 'ro',
    isa        => 'Str',
    required   => 1,
    documentation => 'Either the database id or name of the instrument',
);

has _instr_id => (
    reader     => 'instr_id',
    is         => 'ro',
    isa        => 'Maybe[Int]',
    lazy_build => 1,
);

has _instr_name => (
    reader     => 'instr_name',
    is         => 'ro',
    isa        => 'Maybe[Str]',
    lazy_build => 1,
);

has _db_entry => (
    reader     => 'db_entry',
    is         => 'ro',
    isa        => 'Maybe[npg_tracking::Schema::Result::Instrument]',
    lazy_build => 1,
);

has _label => (
    reader     => 'label',
    is         => 'ro',
    isa        => 'Str',
    lazy_build => 1,
);

sub _build__instr_id {
    my ($self) = @_;
    return ( $self->ident() =~ m/^ (\d+) $/msx ) ? ( $1 + 0 ) : undef;
}

#We only need this if instr_id cannot be set from the --ident argument
sub _build__instr_name {
    my ($self) = @_;
    return ( $self->instr_id() ? undef : $self->ident() );
}

sub _build__db_entry {
    my ($self) = @_;

    my $query;


    if ( $self->instr_id() ) {
        $query = { id_instrument => $self->instr_id() };
    }
    elsif ( $self->instr_name() ) {
        $query = { name => $self->instr_name() };
    }
    else {
        croak 'Instrument identifier not supplied';
    }


    my $instrument_rs =
        $self->schema->resultset('Instrument')->search($query);


    return ( $instrument_rs->count() == 1 ) ? $instrument_rs->next() : undef;
}

sub _build__label {
    my ($self) = @_;

    return sprintf '%s (ID: %d)', $self->db_entry->name(),
            $self->db_entry->id_instrument();
}

sub model {
    my $self = shift;
    return $self->db_entry->instrument_format->model();
}

sub mysql_time_stamp {
    return strftime( '%F %T', localtime );
}

no Moose;
__PACKAGE__->meta->make_immutable();
1;


__END__


=head1 NAME

Monitor::Instrument

=head1 VERSION

=head1 SYNOPSIS

    C<<use Monitor::Instrument;
       my $obj = Monitor::Instrument->new_with_options();
       warn $obj->model();>>

=head1 DESCRIPTION

Base class for modules that interrogate instruments for run
information.

This class is written to support various scripts that monitor instruments. The
scripts should be called with the argument --ident, and optionally, the
argument --dev


=head1 SUBROUTINES/METHODS

=head2 _build_db_entry

Return a npg_tracking::Schema::Result::Instrument row for an instrument.

=head2 model - instrument model

=head2 mysql_time_stamp

Return the current time in a format that can be inserted into a mysql table.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

John O'Brien, E<lt>jo3@sanger.ac.ukE<gt>

=head1 LICENCE AND COPYRIGHT

Copyright (C) 2010 GRL, by John O'Brien

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

=cut

package npg_testing::html;

use strict;
use warnings;
use Carp;
use English qw{-no_match_vars};
use Exporter;
use HTML::Tidy;

our $VERSION = '0';

=head1 NAME

npg_testing::html

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

A collection of test routines for html

=head1 SUBROUTINES/METHODS

=cut


## no critic (ProhibitExplicitISA)
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(html_tidy_ok);

=head2 html_tidy_ok

Test utilising HTML::Tidy

=cut
sub html_tidy_ok {
    my $html_string = shift;
    my $tidy = HTML::Tidy->new( {} );
    my $is_tidy = 1;
    $tidy->parse(q[], $html_string);
    if (scalar $tidy->messages() > 0) {
        $is_tidy = 0;
        carp (join qq[\n], q[HTML::Tidy messages:], $tidy->messages());
        ## no critic (ProhibitStringySplit)
        my @lines = split qq[\n], $html_string;
        ## use critic
        my $count = 0;
        my @counted_lines = ();
        foreach my $line (@lines) { $count++; push @counted_lines, "$count: $line"; }
        carp  (join qq[\n], @counted_lines);
    }
    $tidy->clear_messages();
    return $is_tidy;
}

1;
__END__

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item warnings

=item strict

=item Carp

=item English

=item Exporter

=item HTML::Tidy

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Marina Gourtovaia E<lt>mg8@sanger.ac.ukE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2010 GRL, by Marina Gourtovaia

This file is part of NPG.

NPG is free software: you can redistribute it and/or modify
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


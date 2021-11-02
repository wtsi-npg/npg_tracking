#!/usr/bin/env perl

use Getopt::Long;
use List::Util qw/any/;
use Pod::Usage;

use npg_tracking::Schema;

my $username = 'kt19';
my @new_roles;

GetOptions(
  "username=s" => \$username,
  "role=s" => \@new_roles
) or pod2usage(
    -verbose => 1, -message => '--username and at least one --role required'
);


my $schema = npg_tracking::Schema->connect();

# Validate requested roles
my %valid_roles = map { $_->groupname => $_ } $schema->resultset('Usergroup')->all();

foreach my $role (@new_roles) {
    if (!exists $valid_roles{$role}){
        die "Invalid role: $role. Valid roles are: ".join ',',keys %valid_roles;
    }
}

$schema->txn_do(
    sub {
        $user = $schema->resultset('User')->find({username => $username});
        if (!$user) {
            die "User $username does not exist in the DB";
        }
        my @groups = $user->usergroups()->all();
        my @group_names = join ',', map {$_->groupname} sort @groups;
        printf "Existing groups for user %s: %s\n", $username, @group_names;
        printf "Setting new groups: %s\n", join ',', @new_roles;
        foreach my $new_role (@new_roles) {
            if ( any { $new_role eq $_ } keys %valid_roles) {
                print "$new_role is redundant. Not adding\n";
            } else {
                $user->add_to_usergroups($valid_roles{$new_role});
                print "Assigned $new_role to user\n";
            }
        }
        die "You shall not pass!";
    }
);

__END__

=pod

=head1 NAME

change_user_roles.pl - for a valid GRL user, change their NPG tracking capabilities

=head1 OPTIONS

=over 8

=item B<--username>

A GRL username that is already present in the NPG tracking system

=item B<--role>

The role to assign to the user. Can be specified multiple times.

=back

=head1 SYNOPSIS

change_user_roles.pl --username bobtfish --role annotator --role analyst

=head1 DESCRIPTION

Used to add capabilities to individual users. This script cannot create a
new user, and it cannot remove a role from a user.

Invalid roles will result in an error, and users should not be given the same
role more than once.

=cut
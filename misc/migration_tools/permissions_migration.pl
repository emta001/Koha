#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;

use C4::Context;
use Koha::Patrons;
use Koha::Patron::Categories;

my $help=0;
my @categories;
my $add_bits = 5;

GetOptions(
    'h|help'      => \$help,
    'c|categories=s' => \@categories,
    'a|add=i' => \$add_bits
);

my $usage = << 'ENDUSAGE';

perl misc/migration_tools/permissions_migration.pl -c auto -c virkailija -a 10

Migrates K-S permissions into community permissions.
Generates textfile which contains SQL queries to use
after version update.

This script has the following parameters:
    -h --help: this message
    -c --categories: Which user categories with permissions are handled. 
                     If not specified all users with permissions are handled.
    -a --add: How much is added to K-S permissions bits value. This depends on value 
               of permissions bits column in table userflags. If K-S permissions are 
               set to e.g bits 32-37 this value should be 10. If not specified defaults to 5. 
ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

my $filename = 'misc/migration_tools/permissions';
open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";

my $dbh = C4::Context->dbh;

# Collect all permissions
my $query = "SELECT * FROM permission_modules 
             LEFT JOIN permissions ON (permission_modules.module = permissions.module)";
my $sth = $dbh->prepare($query);
$sth->execute();

my %all_permissions;
my $bit; #same as permission_module_id 
my $module; #permissions; circulate, catalogue etc.
my $code; #subpermissions; circulate_remaining_permissions, force_checkout etc.

while (my $data = $sth->fetchrow_hashref){

    $bit = $data->{permission_module_id};
    $module = $data->{module};
    $code = $data->{code};

    $all_permissions{$module}{bit} = $bit;
    push @{$all_permissions{$module}{subpermissions}}, $code;

}

# Get all user permissions
$query = "SELECT bp.borrowernumber, bp.permission_module_id, p.permission_id, p.module, p.code 
          FROM borrower_permissions bp 
          LEFT JOIN permissions p ON (bp.permission_id = p.permission_id)
          LEFT JOIN borrowers b ON (bp.borrowernumber = b.borrowernumber)";
    
if(@categories){
    $query .= "WHERE b.categorycode IN (" . join( ",", map { "?" } @categories ) . ")";
}

$sth = $dbh->prepare($query);
$sth->execute(@categories);

my %user_permissions; 
my $borrowernumber;
while (my $data = $sth->fetchrow_hashref){

    $borrowernumber = $data->{borrowernumber}; 
    $module = $data->{module};
    $code = $data->{code};

    push @{$user_permissions{$borrowernumber}{$module}}, $code; 
   
}

print "Found ".scalar %user_permissions." users.\n";

my $queries;
my $all_subpermissions;
my $count = 0;
while (my ($borrowernumber, $permissions) = each (%user_permissions)){
    my $flags = 0;
    while (my ($module, $subpermissions) = each (%{$permissions})){
        $all_subpermissions = $all_permissions{$module}->{subpermissions};
        $bit = $all_permissions{$module}->{bit};

        #First handle K-S permissions manually so we can count permission flags
        #Superlibrarian has bit 0 in community and lists and clubs have bits 20 and 21 
        #Bits 22-24 (auth, messages, labels) and 27 (privacy) are K-S specific
        $bit = 0 if $module eq "superlibrarian";
        $bit = 20 if $module eq 'lists';
        $bit = 21 if $module eq 'clubs';
        $bit = 25 if $module eq 'privacy';
        $bit += $add_bits if ($bit >= 22 && $bit <= 25); #maybe we should use $add_bits?

        if(scalar @{$all_subpermissions} == scalar @{$subpermissions}){ 
            $flags += 2**$bit;    
        }else{
            foreach my $subpermission (@{$subpermissions}){
                #Community has some differing subpermissions 
                #e.g self_checkout is self_checkout_module in self_check module :D
                if($subpermission eq 'self_checkout'){
                    $bit = 23;
                    $subpermission = 'self_checkout_module';
                }

                $queries .= "INSERT INTO user_permissions (borrowernumber, module_bit, code) VALUES (". $borrowernumber .", ". $bit .", ". $subpermission .");\n";   
            }    
        }  
                         
    }   
    
    $queries .= "UPDATE borrowers SET flags = ". $flags ." WHERE borrowernumber= ". $borrowernumber .";\n" if $flags;
    $count++;  
}
print "Wrote queries for ".$count." users.\n";

print $fh $queries;
close $fh;
print "Done.\n";
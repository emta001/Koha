#!/usr/bin/perl
#

use strict;
use warnings;

use Getopt::Long;

use C4::Context;
use Koha::MongoDB;
use Koha::DateUtils qw(dt_from_string);
use DateTime::Format::MySQL;
use Data::Dumper qw(Dumper);

my ($help, $confirm, $test);
my $months = 1;
my $limit;

GetOptions(
    'h|help'      => \$help,
    'c|confirm'   => \$confirm,
    't|test'      => \$test,
    'm|months=i'    => \$months,
);

my $usage = << 'ENDUSAGE';

NOTE! Currently this script goes through WHOLE collections.
Use with caution. Or actually don't use at all until we have solved smart way
to collect and calculate this data.

This script collects libraries collections data to MongoDB.

This script has the following parameters :
    -h | --help: This message.
    -c | --confirm: Run script.
    -t | --test: Print result to terminal, no changes are made to MongoDB.
    NOTE! Using --test drops whole collection from MongoBD and all data is lost. Do not use this in production!
    -d | --days: For how many days the loans are calculated. If not given defaults to 1 (last month).
    NOTE! It's highly recommended to use this only for testing purposes.

ENDUSAGE

if ($help or !$confirm) {
    print $usage;
    exit;
}

my $mongodb = Koha::MongoDB->new();
my $client = $mongodb->{client};
my $settings = $mongodb->{settings};
my $db = $client->get_database('reports');

my $from_date = DateTime::Format::MySQL->format_datetime(dt_from_string()->subtract(months => $months));
my $to_date = DateTime::Format::MySQL->format_datetime(dt_from_string());

my $collections = $client->ns($settings->{database}.'.collections');
$mongodb->push_collections($collections, $limit, $from_date, $to_date);

if($test){
    my $all_collections = $collections->find;
    while(my $i = $all_collections -> next){
        print Dumper $i;
    }
    $collections->drop();
}

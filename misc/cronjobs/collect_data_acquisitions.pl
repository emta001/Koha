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

This script collects libraries collections data to MongoDB.

This script has the following parameters :
    -h | --help: This message.
    -c | --confirm: Run script.
    -t | --test: Print result to terminal, no changes are made to MongoDB.
    NOTE! Using --test drops whole collection from MongoBD and all data is lost. Do not use this in production!
    -m | --months: For how many months the loans are calculated. If not given defaults to 1 (last month).
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

my $acquisitions = $client->ns($settings->{database}.'.acquisitions');
$mongodb->push_acquisitions($acquisitions, $limit, $from_date, $to_date);

if($test){
    my $all_acquisitions = $acquisitions->find;
    while(my $i = $all_acquisitions -> next){
        print Dumper $i;
    }
    $acquisitions->drop();
}

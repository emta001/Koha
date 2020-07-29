use strict;
use warnings;

use Getopt::Long;

use C4::Context;
use Koha::MongoDB;
use Koha::DateUtils qw(dt_from_string);
use DateTime::Format::MySQL;
use Data::Dumper qw(Dumper);

my ($help, $confirm, $test);
my $years = 1;
my $limit;

GetOptions(
    'h|help'      => \$help,
    'c|confirm'   => \$confirm,
    't|test'      => \$test,
    'y|years=i'    => \$years,
);

my $usage = << 'ENDUSAGE';

This script collects data to MongoDB of how many unique borrowers library has had.

This script has the following parameters :
    -h | --help: This message.
    -c | --confirm: Run script.
    -t |--test: Print result to terminal, no changes are made to MongoDB.
    NOTE! Using --test drops whole collection from MongoBD and all data is lost. Do not use this in production!
    -y | --years: For how many days the loans are calculated. If not given defaults to 1 (last year).
    NOTE! It's highly recommended to use this only for testing purposes.

Data collected has following structure (order may vary):

{
    '_id' => <automatically set by MongoDB>,
    'timestamp' => <0000-00-00 00:00:00>,
    'branches' => [
        {
            'total' => 0,
            'branch' => <branchcode>
        },
        {...}
    ]
}

NOTE! Although we use year as interval, single days

ENDUSAGE

if ($help or !$confirm) {
    print $usage;
    exit;
}

my $mongodb = Koha::MongoDB->new();
my $client = $mongodb->{client};
my $settings = $mongodb->{settings};
my $db = $client->get_database('reports');

my $from_date = DateTime::Format::MySQL->format_datetime(dt_from_string()->subtract(years => $years));
my $to_date = DateTime::Format::MySQL->format_datetime(dt_from_string());

my $borrowers = $client->ns($settings->{database}.'.borrowers');

$mongodb->push_borrowers($borrowers, $limit, $from_date, $to_date);

if($test){
    my $all_borrowers = $borrowers->find;
    while(my $i = $all_borrowers -> next){
        print Dumper $i;
    }
    $borrowers->drop();
}

use strict;
use warnings;

use Getopt::Long;

use C4::Context;
use Koha::MongoDB;
use Koha::DateUtils qw(dt_from_string);
use DateTime::Format::MySQL;
use Data::Dumper qw(Dumper);

my ($help, $confirm, $test);
my $days = 1;
my $limit = 1000;

GetOptions(
    'h|help'      => \$help,
    'c|confirm'   => \$confirm,
    't|test'      => \$test,
    'd|days=i'    => \$days,
    'l|limit=i'   => \$limit
);

my $usage = << 'ENDUSAGE';

This script collects libraries loan data to MongoDB.

This script has the following parameters:
    -h | --help: This message.
    -c | --confirm: Run script.
    -t | --test: Print result to terminal, no changes are made to MongoDB.
    NOTE! Using --test drops whole collection from MongoBD and all data is lost. Do not use this in production!
    -d | --days: For how many days the loans are calculated. If not given defaults to 1 (just yesterday).
    NOTE! It's highly recommended to use this only for testing purposes.
    -l | --limit: Limit SQL query

Data collected has following structure (order may vary):

{
    '_id' => <automatically set by MongoDB>,
    'timestamp' => <0000-00-00 00:00:00>,
    'branches' => [
                    {
                        'branch' => <branchcode>,
                        'loans' => {
                            'books_other_lan'   => 0,
                            'sheet_music'       => 0,
                            'recordings_music'  => 0,
                            'juveniles_fiction' => 0,
                            'dvds_brs'          => 0,
                            'books_fin'         => 0,
                            'cdroms'            => 0,
                            'videos'            => 0,
                            'others'            => 0,
                            'recordings_other'  => 0,
                            'total'             => 0,
                            'adults_fiction'    => 0,
                            'adults_fact'       => 0,
                            'books_swe'         => 0,
                            'juveniles_fact'    => 0,
                            'books_total'       => 0
                        }

                    },
                    {...}
                ]
}

ENDUSAGE

if ($help or !$confirm) {
    print $usage;
    exit;
}

my $mongodb = Koha::MongoDB->new();
my $client = $mongodb->{client};
my $settings = $mongodb->{settings};
my $db = $client->get_database('reports');

my $from_date = DateTime::Format::MySQL->format_datetime(dt_from_string()->subtract(days => $days));
my $to_date = DateTime::Format::MySQL->format_datetime(dt_from_string());

my $loans = $client->ns($settings->{database}.'.loans');

$mongodb->push_loans($loans, $limit, $from_date, $to_date);

if($test){
    my $all_loans = $loans->find;
    while(my $i = $all_loans -> next){
        print Dumper $i;
    }
    $loans->drop();
}

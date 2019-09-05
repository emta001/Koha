use strict;
use warnings;

use C4::Context;
use Koha::MongoDB;
use Koha::DateUtils qw(dt_from_string);
use DateTime::Format::MySQL;
use Data::Dumper qw(Dumper);

my $mongodb = Koha::MongoDB->new();
my $client = $mongodb->{client};
my $settings = $mongodb->{settings};
my $db = $client->get_database('reports');

my $from_date = DateTime::Format::MySQL->format_datetime(dt_from_string()->subtract(days => 1));
my $to_date = DateTime::Format::MySQL->format_datetime(dt_from_string());

my $limit = 10000;

my $loans = $client->ns($settings->{database}.'.loans');
$mongodb->push_loans($loans, $limit, '2018-01-01 00:00:01', '2018-12-31 23:59:01');

#test with these
#my $loans_info = $loans->find;
#while(my $i = $loans_info -> next){
    #print Dumper $i;
#}
#$loans->drop();
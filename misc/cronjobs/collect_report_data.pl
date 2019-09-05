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

my $last_year = DateTime::Format::MySQL->format_datetime(dt_from_string()->subtract(years => 1));
my $last_month = DateTime::Format::MySQL->format_datetime(dt_from_string()->subtract(months => 1));
my $yesterday = DateTime::Format::MySQL->format_datetime(dt_from_string()->subtract(days => 1));
my $today = DateTime::Format::MySQL->format_datetime(dt_from_string());

#'2014-05-26 00:00:00' '2014-05-27 23:59:59'
my $limit = 100;

warn Data::Dumper::Dumper "skripti käynnistyi: ", $today;
my $logs = $client->ns($settings->{database}.'.logs');
$logs->drop();

=hh
my $collections = $client->ns($settings->{database}.'.collections');
$mongodb->push_collections($collections, $limit, $last_month, $today);
$collections->drop();

my $deleted_items = $client->ns($settings->{database}.'.deleted_items');
$mongodb->push_deleted_items($deleted_items, $limit, $yesterday, $today);
$deleted_items->drop();

my $acquisitions = $client->ns($settings->{database}.'.acquisitions');
$mongodb->push_acquisitions($acquisitions, $limit, $last_month, $today);
$acquisitions->drop();

my $borrowers = $client->ns($settings->{database}.'.borrowers');
$mongodb->push_borrowers($borrowers, $logs, $limit, $last_year, $today);
$borrowers->drop();
=cut
my $loans = $client->ns($settings->{database}.'.loans');
$mongodb->push_loans($loans, $logs, $limit, $yesterday, $today);

my $loppui = DateTime::Format::MySQL->format_datetime( dt_from_string());
warn Data::Dumper::Dumper "mongoon lisäys onnistui: ", $loppui;

my $loans_info = $loans->find;
while(my $i = $loans_info -> next){
    #print Dumper $i;
}

$loans->drop();

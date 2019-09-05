use strict;
use warnings;

use C4::Context;
use Koha::MongoDB;
use Data::Dumper qw(Dumper);

my $mongodb = Koha::MongoDB->new();
my $client = $mongodb->{client};
my $settings = $mongodb->{settings};
my $db = $client->get_database('reports');
my $loans_collection = $client->ns($settings->{database}.'.loans');

$mongodb->push_loans($loans_collection);

my $loans_info = $loans_collection->find;

while(my $i = $loans_info -> next){
    print Dumper $i;
}

$loans_collection->drop();

=hh
=cut
=SEKALAVA

$loans_collection->insert_one({
        datetime => $statistic->{datetime},
        branch => $statistic->{branch},
        type => $statistic->{type},
        item => {
            itemnumber => $statistic->{itemnumber},
            itemtype => $statistic->{itemtype} }, #<-ehkä noin?
        borrowernumber => $statistic->{borrowernumber}
    });
=cut

use strict;
use warnings;

use C4::Context;
use Koha::MongoDB;
use Data::Dumper qw(Dumper);

use Koha::MongoDB::Reporting::Loans;

my $mongodb = Koha::MongoDB->new();
my $client = $mongodb->{client};
my $test_db = $client->get_database('testikanta');
my $test_collection = $test_db->get_collection('loans_test');

my $loans = Koha::MongoDB::Reporting::Loans->new(); 

print $loans->getLoans();

my $test_infos = $test_collection->find;

while(my $i = $test_infos -> next){
    print Dumper $i;
}

=SEKALAVA
#my $settings = $mongodb->{settings};
#$settings->{database}
my $yaml = C4::Context->preference('OKM');
    $yaml = Encode::encode('UTF-8', $yaml, Encode::FB_CROAK);
    $data->{conf} = YAML::XS::Load($yaml);

$test_collection->insert_one({
        datetime => $statistic->{datetime},
        branch => $statistic->{branch},
        type => $statistic->{type},
        item => {
            itemnumber => $statistic->{itemnumber},
            itemtype => $statistic->{itemtype} }, #<-ehkä noin?
        borrowernumber => $statistic->{borrowernumber}
    });
=cut

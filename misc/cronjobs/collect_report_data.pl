use strict;
use warnings;

use C4::Context;
use Koha::MongoDB;
use Data::Dumper qw(Dumper);

#MySQL:stä haku
my $dbh = C4::Context->dbh;
my $sth = $dbh->prepare($query);

$sth->execute();

my @statistics;
while(my $row = $sth->fetchrow_hashref){
    push @statistics, $row;
}

#MongoDB:hen kirjoitus
my $mongodb = Koha::MongoDB->new();
my $client = $mongodb->{client};
#my $settings = $mongodb->{settings};
#$settings->{database}

#alustava
my $test_db = $client->get_database('testikanta');
my $test_collection = $test_db->get_collection('testikokoelma');

=yy
my $query = "SELECT datetime, branch, type, itemnumber, itemtype, borrowernumber FROM statistics limit 1";
foreach my $statistic (@statistics){
    #my ($datetime, $branch, $type, $itemnumber, $itemtype, $borrowernumber) = @_;    

    $test_collection->insert_one({
        datetime => $statistic->{datetime},
        branch => $statistic->{branch},
        type => $statistic->{type},
        item => {
            itemnumber => $statistic->{itemnumber},
            itemtype => $statistic->{itemtype} }, #<-ehkä noin?
        borrowernumber => $statistic->{borrowernumber}
    });
}

my $test_infos = $test_collection->find;

while(my $i = $test_infos -> next){
    print Dumper $i;
}

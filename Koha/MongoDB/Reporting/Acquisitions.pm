package Koha::MongoDB::Reporting::Acquisitions;

use Moose;
use Try::Tiny;
use MongoDB;

use Koha::MongoDB::Config;
use Koha::Database;
use Koha::MongoDB::Reporting::Items;

has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    reader => 'getSchema',
    writer => 'setSchema'
);

has 'config' => (
    is => 'rw',
    isa => 'Koha::MongoDB::Config',
    reader => 'getConfig',
    writer => 'setConfig'
);

sub BUILD {
    my $self = shift;
    my $args = shift;
    my $schema = Koha::Database->new()->schema();
    $self->setSchema($schema);
    $self->setConfig(new Koha::MongoDB::Config);
    my $dbh;
    if ($args->{dbh}) {
        $dbh = $args->{dbh};
    } else {
        $dbh = $self->getConfig->mongoClient();
    }
    $self->{dbh} = $dbh;
}

sub getAcquisitions{
    my $self = shift;
    my ($params, $from_date, $to_date) = @_;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT homebranch as branch, itemnumber from items
    where dateaccessioned >= ?
    and dateaccessioned <= ?";
    if ($params->{order_by}) {
        $query .= " order by ".$params->{order_by};
    }
    if ($params->{limit}) {
        $query .= " limit ".$params->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute($from_date, $to_date);

    my @acquisitions;
    while(my $row = $sth->fetchrow_hashref){
        push @acquisitions, $row;
    }
    return \@acquisitions;
}

sub setAcquisitions{

    my $self = shift;
    my ($branch, $items_count, $acquisitions_total_price) = @_;

    my $result = {
        branch => $branch,
        acquisitions => $items_count,
        total_price => $acquisitions_total_price
    };

    return $result;
}

sub acquisitionsTotalPrice{
    my $self = shift;
    my ($itemnumbers) = @_;
    my $items = Koha::MongoDB::Reporting::Items->new();
    my $total_price = 0;

    foreach my $itemnumber (@{$itemnumbers}){
        my $item = $items->getItem($itemnumber);
        my $price = ($item->{price}) ? $item->{price} : 0;
        $total_price += $price;
    }

    return $total_price;
}

1;
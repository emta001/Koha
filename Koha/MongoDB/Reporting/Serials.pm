package Koha::MongoDB::Reporting::Serials;

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

sub getSerials{
    my $self = shift;
    my ($params, $serial_keys, $notforloan, $to_date) = @_;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT homebranch as branch, itemnumber from items
    where itype in (". join(",", map {"?"} @{$serial_keys}) .")
    and not notforloan in (" . join(",", map {"?"} @{$notforloan}).")
    and datereceived <= ?";
    if ($params->{order_by}) {
        $query .= " order by ".$params->{order_by};
    }
    if ($params->{limit}) {
        $query .= " limit ".$params->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute(@{$serial_keys},@{$notforloan}, $to_date);

    my @serials;
    while(my $row = $sth->fetchrow_hashref){
        push @serials, $row;
    }
    return \@serials;
}

sub countSerials{
    my $self = shift;
    my ($itemnumbers, $configs) = @_;

    my $items = Koha::MongoDB::Reporting::Items->new();
    my $serials_count;

    my $total = 0;
    my $magazines = 0;
    my $newspapers = 0;

    foreach my $itemnumber (@{$itemnumbers}){

        my $item = $items->getItem($itemnumber);
        my $biblionumber = $item->{biblionumber};

        my $biblio_records;
        if(defined $biblionumber){
            $biblio_records = $items->getBiblioRecords($biblionumber);
        }

        my $itemtype = $biblio_records->{itemtype};

        if(defined $itemtype){

            if($itemtype eq 'AL'){
                $magazines++;
            }elsif($itemtype eq 'SL'){
                $newspapers++;
            }

            $total++;
        }

        $serials_count = {
            total => $total,
            magazines => $magazines,
            newspapers => $newspapers
        };

    }

    return $serials_count;
}

sub setSerials{
    my $self = shift;
    my ($branch, $items_count) = @_;

    my $result = {
        branch => $branch,
        serials => {
            total => $items_count->{total},
            magazines => $items_count->{magazines},
            newspapers => $items_count->{newspapers}
        }
    };

    return $result;
}

1;
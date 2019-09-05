package Koha::MongoDB::Reporting::Loans;

use Moose;
use Try::Tiny;
use MongoDB;
use Koha::MongoDB::Config;

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

sub getLoans{

    my $self = shift;
    my ($params, $patron_categories, $from_date, $to_date) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT branch, itemnumber from statistics
    where (type='issue' or type='renew')
    and usercode in (" . join(",", map {"?"} @{$patron_categories}).")
    and datetime >= ?
    and datetime <= ?
    and not other = 'KONVERSIO'";

    if ($params->{limit}) {
        $query .= " limit ".$params->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute(@{$patron_categories}, $from_date, $to_date);

    my @loans;
    while(my $row = $sth->fetchrow_hashref){
        push @loans, $row;
    }
    return \@loans;

}

sub setLoans{
    my $self = shift;
    my ($branch, $items_count) = @_;

    my $result = {
        branch => $branch,
        loans => $items_count
    };

    return $result;
}

1;

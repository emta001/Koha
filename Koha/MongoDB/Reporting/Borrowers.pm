package Koha::MongoDB::Reporting::Borrowers;

use Moose;
use Try::Tiny;
use MongoDB;
use Time::Piece;
use Koha::DateUtils qw(dt_from_string output_pref);

use Koha::MongoDB::Config;
use Koha::Database;
use Koha::Patron;
use Koha::MongoDB::Reporting::General;

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

sub getBorrowers{
    my $self = shift;
    my ($params, $patron_categories, $from_date, $to_date) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT branch, borrowernumber, datetime from statistics
    where usercode in (" . join(",", map {"?"} @{$patron_categories}).")
    and not other = 'KONVERSIO'
    and datetime >= ?
    and datetime <= ?";
    if ($params->{limit}) {
        $query .= " limit ".$params->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute(@{$patron_categories}, $from_date, $to_date);

    my @borrowers;
    while(my $row = $sth->fetchrow_hashref){
        push @borrowers, $row;
    }
    return \@borrowers;

}

sub generateBorrowerGroups{
    my $self = shift;
    my ($result) = @_;

    my %borrower_branchgroups;
    my $datetime;
    my %seen;

    for my $row (@{$result}){
        $datetime = Time::Piece->strptime($row->{datetime}, '%Y-%m-%d %H:%M:%S');
        $datetime = $datetime->strftime('%Y-%m-%d');
        if($row->{branch}){
            next if $seen{ $row->{borrowernumber} }++;

            push @{$borrower_branchgroups{$datetime}{$row->{branch}}}, $row->{borrowernumber};
        }
    }

    return \%borrower_branchgroups;

}

sub setBorrowers{
    my $self = shift;
    my ($branch, $total) = @_;

    my $result = {
        branch => $branch,
        total => $total
    };

    return $result;
}
1;
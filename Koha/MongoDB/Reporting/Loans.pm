package Koha::MongoDB::Reporting::Loans;

use Moose;
use Try::Tiny;
use MongoDB;
use Koha::MongoDB::Config;

has 'config' => (
    is      => 'rw',
    isa => 'Koha::MongoDB::Config',
    reader => 'getConfig',
    writer => 'setConfig'
);

sub BUILD {
    my $self = shift;
    my $args = shift;
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
    my ($params) = @_;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT branch, itemnumber from statistics where (type='issue' or type='renew') and not (other = 'KONVERSIO' or branch = 'NULL')"; 
    if ($params->{order_by}) {
        $query .= " order by ".$params->{order_by};
    }
    if ($params->{limit}) {
        $query .= " limit ".$params->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute();

    my @loans;
    while(my $row = $sth->fetchrow_hashref){
        push @loans, $row;
    }
    return \@loans;

}

sub setLoans{
    my $self = shift;
    my ($branch, $loans_info) = @_;
    
    my $result = {
        branch => $branch,
        loans => $loans_info      
    };
        
    return $result;
}

=nn

=cut

1;

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
    my $query = "SELECT branch, itemnumber from statistics where type = 'issue'"; # and not other = 'KONVERSIO'
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


        if($biblio_records->{itemtype} eq 'KI'){
            $books_total++; 

            if($biblio_records->{language} eq 'fin'){
                $books_fin++;
            }elsif($biblio_records->{language} eq 'swe'){
                $books_swe++;
            }else{
                $books_other_lan++;
            }   
        };
    my $adults_fiction = 0;
    my $adults_fact = 0;
    my $juveniles_fiction = 0;
    my $juveniles_fact = 0;

, 
    adults_fiction => $adults_fiction,
    adults_fact => $adults_fact,
    juveniles_fiction => $juveniles_fiction,
    juveniles_fact => $juveniles_fact 

        if($biblio_records->{cn_class} >= 80 && $biblio_records->{cn_class} <= 85){

        }elsif(($biblio_records->{cn_class} >= 0 && $biblio_records->{cn_class} <= 79) || ($biblio_records->{cn_class} >= 86 && $biblio_records->{cn_class} <= 99)){
  
        }
    my $findbranch = $self->checkBranch($branch);

    unless($findbranch){}

sub checkBranch {
    my $self = shift;
    my ($branch) = @_;
    my $client = $self->{dbh};
    my $settings = $self->getConfig->getSettings();

    my $loans = $client->ns($settings->{database}.'.loans');
    my $findbranch = $loans->find_one({branch => $branch});

    return $findbranch;
}



=cut

1;

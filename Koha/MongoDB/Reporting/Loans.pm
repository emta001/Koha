package Koha::MongoDB::Reporting::Loans;

use Moose;
use Try::Tiny;
use MongoDB;

sub getLoans{
    my $self = shift;
    my $dbh = C4::Context->dbh;
    my $query = "SELECT branch, type from statistics where type = 'issue' limit 2";
    my $sth = $dbh->prepare($query);
    $sth->execute();

    my @loans;
    while(my $row = $sth->fetchrow_hashref){
        push @loans, $row;
    }

    return \@loans;
}

sub pushLoans{
    my $self = shift;
    my ($params) = @_;
    
    #foreach my $loan (@loans){    

     #   $test_collection->insert_one({
     #           id : <id>,
      #  timestamp: <timestamp>
       # branches: [
        #    {
         #       branchcode: <code>,
          #      issues: <sum_issues>
           # },

        #]
     #   });
    #}
}

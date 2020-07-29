package Koha::MongoDB::Reporting::General;

use Moose;
use Try::Tiny;

use List::MoreUtils qw/uniq/;
use MARC::Record;
use Koha::MongoDB::Config;
use DateTime::Format::ISO8601;

has 'config' => (
    is => 'rw',
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

sub generateBranchGroups{
    my $self = shift;
    my ($result) = @_;

    my %branchgroups;
    for my $row (@{$result}){
        if($row->{branch}){
            push @{$branchgroups{$row->{branch}}}, $row->{itemnumber};
        }
    }

    return \%branchgroups;
}

sub loadConfigs{
    my $self = shift;
    my ($data) = @_;
    my $yaml = C4::Context->preference('OKM');
    $yaml = Encode::encode('UTF-8', $yaml, Encode::FB_CROAK);
    $data->{conf} = YAML::XS::Load($yaml);

    return $data->{conf};
}

sub pushToMongo{
    my $self = shift;
    my ($mongocol, $from_date, $branches) = @_;

    my $result;
    #my $date = DateTime::Format::ISO8601->parse_datetime($from_date, time_zone=>'UTC');

    $result = $mongocol->insert_one({
        timestamp => $from_date,
        branches => $branches
    });

    return $result;
}

=head3
    check if collection with same timestamp is already pushed to MongoDB
=cut

sub checkCollection{
    my $self = shift;
    my ($mongocol, $from_date) = @_;
    my $date = Time::Piece->strptime($from_date, '%Y-%m-%d %H:%M:%S');
    $date = $date->strftime('%Y-%m-%d');

    my $find_branch = $mongocol->find_one({
        "timestamp" => qr/^$date/
    });

    if($find_branch){
        print "Collection " .uc($mongocol->name). " already collected on $date.\n";
        return 1;
    }

    return 0;
}

1;
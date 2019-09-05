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

sub writeLog{
    my $self = shift;
    my ($logs, $date, $collection, $message) = @_;

    my $result = $logs->insert_one({
        timestamp => $date,
        collection => $collection,
        message => $message
    });

    return $result;
}

=head3
    check if collection with same timestamp is already pushed to MongoDB
=cut

sub checkCollection{
    my $self = shift;
    my ($mongocol, $logs, $from_date, $to_date) = @_;
    my $date = Time::Piece->strptime($from_date, '%Y-%m-%d %H:%M:%S');
    $date = $date->strftime('%Y-%m-%d');
    $date = DateTime::Format::ISO8601->parse_datetime($date, time_zone=>'UTC');

    my $find_branch = $mongocol->find_one({
        "timestamp" => $date
    });

    if($find_branch){
        $self->writeLog($logs, $to_date, $mongocol->{name}, "Timestamp already in collection");
        return 1;
    }

    return 0;
}

1;
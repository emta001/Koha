package Koha::MongoDB::Reporting::Abstract;

use Moose;
use Try::Tiny;

use MARC::Record;

sub loadConfigs{
    my $self = shift;
    my $data = $_[0];
    my $yaml = C4::Context->preference('OKM');
    $yaml = Encode::encode('UTF-8', $yaml, Encode::FB_CROAK);
    $data->{conf} = YAML::XS::Load($yaml);
    
    return $data;
}

sub getShelvingType{
    my $self = shift;
    my ($config) = @_;

    my $result = {
        adultshelving => $config->{adultShelvingLocations},
        juvenileshelving => $config->{juvenileShelvingLocations}   
    };
    
    return $result;
}

1;
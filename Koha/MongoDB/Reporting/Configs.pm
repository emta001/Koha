package Koha::MongoDB::Reporting::Configs;

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

1;
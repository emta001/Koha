package Koha::MongoDB::Reporting::Items;

use Moose;
use Try::Tiny;
use MongoDB;

use C4::Biblio;

use Koha::Items;
use Koha::Database;
use Koha::BiblioUtils;

sub getItem{
    my $self = shift;
    my ($itemnumber) = @_;
    
    my $item = Koha::Items->find($itemnumber);
    if($item){
        $item = $item->unblessed;
    } else {
        my $schema  = Koha::Database->new->schema;
        my $del = $schema->resultset('Deleteditem')->find({itemnumber => $itemnumber});

        if($del){
            $item = { $del->get_columns } if $del;
        } else {
            $item = { biblionumber => 0 }; #Mock-up?
        }
    }
    
    return $item;
}

sub getBiblioRecords{
    my $self = shift;
    my ($biblionumber) = @_;
    
    my $marcs = GetMarcBiblio($biblionumber); 

    my $result;
    if(blessed $marcs && $marcs->isa('MARC::Record')){
        $result->{itemtype} = $marcs->subfield('942', 'c'); 
        $result->{language} = $marcs->subfield('041', 'a');
        
        my $cn_class = $self->cnClass($marcs->subfield('084', 'a'));
        
        $result->{cn_class} = $cn_class;  
    }

    return $result;   
}

sub cnClass{
    my $self = shift;
    my ($cn_class) = @_;

    #palauta myös loppuosa jos tarpeen
    my ($cn_primary, $cn_decimal) = split /\./, $cn_class;

    return $cn_primary;
}

1;
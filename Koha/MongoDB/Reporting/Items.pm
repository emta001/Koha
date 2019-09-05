package Koha::MongoDB::Reporting::Items;

use Moose;
use Try::Tiny;
use MongoDB;

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
            $item = { biblionumber => '0' }; #Mock-up?
        }
    }
    
    return $item;
}

sub getBiblioRecords{
    my $self = shift;
    my ($biblionumber) = @_;
    
    my $marcs = Koha::BiblioUtils->get_from_biblionumber($biblionumber);
    
    my $record = $marcs->{record};
    my $result;

    if(blessed $record && $record->isa('MARC::Record')){
        $result->{itemtype} = $record->subfield('942', 'c'); 
        $result->{language} = $record->subfield('041', 'a'); 
        $result->{cn_class} = $record->subfield('084', 'a');  
    }

    return $result;   
}

sub cnClass{
    my $self = shift;
    my ($cn_class) = @_;

    my $result = $cn_class;

    return $result;
}

1;
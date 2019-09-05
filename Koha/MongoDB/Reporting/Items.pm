package Koha::MongoDB::Reporting::Items;

use Moose;
use Try::Tiny;
use MongoDB;

use C4::Biblio;

use Koha::MongoDB::Config;
use Koha::Database;
use Koha::Items;
use Koha::BiblioUtils;

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

=head3
    collect collection data from database
=cut

sub getItems{
    my $self = shift;
    my ($params, $itemtypes, $notforloan, $to_date) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT homebranch as branch, itemnumber from items
    where itype in (". join(",", map {"?"} @{$itemtypes}) .")
    and not notforloan in (" . join(",", map {"?"} @{$notforloan}).")
    and dateaccessioned <= ?";
    if ($params->{limit}) {
        $query .= " limit ".$params->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute(@{$itemtypes}, @{$notforloan}, $to_date);

    my @items;
    while(my $row = $sth->fetchrow_hashref){
        push @items, $row;
    }
    return \@items;
}

=head3
    sets collection data into MongoDB
=cut

sub setItems{

    my $self = shift;
    my ($branch, $items_count) = @_;

    my $result = {
        branch => $branch,
        items => $items_count
    };

    return $result;
}

sub getDeletedItems{
    my $self = shift;
    my ($params, $itemtypes, $from_date, $to_date) = @_;

    my $dbh = C4::Context->dbh;
    my $query = "SELECT homebranch as branch, itemnumber from deleteditems
    where itype in (". join(",", map {"?"} @{$itemtypes}) .")
    and timestamp >= ?
    and timestamp <= ?";

    if ($params->{limit}) {
        $query .= " limit ".$params->{limit};
    }
    my $sth = $dbh->prepare($query);
    $sth->execute(@{$itemtypes}, $from_date, $to_date);

    my @deleted_items;
    while(my $row = $sth->fetchrow_hashref){
        push @deleted_items, $row;
    }
    return \@deleted_items;
}

sub setDeletedItems{
    my $self = shift;
    my ($branch, $total) = @_;

    my $result = {
        branch => $branch,
        total => $total
    };

    return $result;
}

sub getItem{
    my $self = shift;
    my ($itemnumber) = @_;

    my $item = Koha::Items->find($itemnumber);
    if($item){
        $item = $item->unblessed;
    } else {
        my $schema = Koha::Database->new->schema;
        my $del = $schema->resultset('Deleteditem')->find({itemnumber => $itemnumber});

        if($del){
            $item = { $del->get_columns } if $del;
        } else {
            $item = { biblionumber => 0 };
        }
    }

    return $item;
}

=head3
Count items for loans, collections and acquisitions
=cut

sub countItems{
    my $self = shift;
    my ($itemnumbers, $itemtypes, $adults_locations, $juveniles_locations) = @_;

    my $items_count;

    my $total = 0;
    my $books_total = 0;
    my $books_fin = 0;
    my $books_swe = 0;

    my $books_other_lan = 0;
    my $adults_fiction = 0;
    my $adults_fact = 0;
    my $juveniles_fiction = 0;
    my $juveniles_fact = 0;
    my $sheet_music = 0;
    my $recordings_music = 0;
    my $recordings_other = 0;
    my $videos = 0;
    my $cdroms = 0;
    my $dvds_brs = 0;
    my $others = 0;

    foreach my $itemnumber (@{$itemnumbers}){

        my $item = $self->getItem($itemnumber);
        my $permanent_location = $item->{permanent_location};
        my $biblionumber = $item->{biblionumber};

        my $biblio_records = $self->getBiblioRecords($biblionumber) if defined $biblionumber;
        my $itemtype = $biblio_records->{itemtype};
        my $language = $biblio_records->{language};
        my $cn_class = $biblio_records->{cn_class};

        if(%{$biblio_records}){

            my $category = $itemtypes->{$itemtype} if defined $itemtype;

            if($category && $category eq 'Books'){

                $books_total++;

                if(defined $language && $language eq 'fin'){
                    $books_fin++;
                }elsif(defined $language && $language eq 'swe'){
                    $books_swe++;
                }else{
                    $books_other_lan++;
                }

                if(defined $permanent_location && grep(/^($permanent_location)$/, @{$adults_locations})){
                    if(defined $cn_class && $cn_class >= 80 && $cn_class <= 85){
                        $adults_fiction++;
                    }elsif(defined $cn_class && ($cn_class >= 0 && $cn_class <= 79) || ($cn_class >= 86 && $cn_class <= 99)){
                        $adults_fact++;
                    }
                }elsif(defined $permanent_location && grep(/^($permanent_location)$/, @{$juveniles_locations})){
                    if(defined $cn_class && $cn_class >= 80 && $cn_class <= 85){
                        $juveniles_fiction++;
                    }
                    if(defined $cn_class && ($cn_class >= 0 && $cn_class <= 79) || ($cn_class >= 86 && $cn_class <= 99)){
                        $juveniles_fact++;
                    }
                }

            }elsif($category && $category eq 'SheetMusicAndScores'){
                $sheet_music++;
            }elsif($category &&  $category eq 'Recordings'){
                if(defined $cn_class && $cn_class == 78){
                    $recordings_music++;
                }elsif(defined $cn_class && $cn_class != 78){
                    $recordings_other++;
                }
            }elsif($category && $category eq 'Videos'){
                $videos++;
            }elsif($category && $category eq 'CDROMs'){
                $cdroms++;
            }elsif($category && $category eq 'DVDsAndBluRays'){
                $dvds_brs++;
            }elsif($category && $category eq 'Other'){
                $others++;
            }

            $total++;

        }

        $items_count = {
            total => $total,
            books_total => $books_total,
            books_fin => $books_fin,
            books_swe => $books_swe,
            books_other_lan => $books_other_lan,
            books_other_lan => $books_other_lan,
            books_other_lan => $books_other_lan,
            adults_fiction => $adults_fiction,
            adults_fact => $adults_fact,
            juveniles_fiction => $juveniles_fiction,
            juveniles_fact => $juveniles_fact,
            sheet_music => $sheet_music,
            recordings_music => $recordings_music,
            recordings_other => $recordings_other,
            videos => $videos,
            cdroms => $cdroms,
            dvds_brs => $dvds_brs,
            others => $others
        };
    }

    return $items_count;
}

sub getBiblioRecords{
    my $self = shift;
    my ($biblionumber) = @_;

    my $marcs = GetMarcBiblio($biblionumber);

    #if biblio is deleted, get xml and parse it
    if(!$marcs){
        my $xml = C4::Biblio::GetDeletedXmlBiblio(undef, $biblionumber);
        if($xml){
            $marcs = MARC::Record::new_from_xml($xml, 'UTF-8');
        } else {
            $marcs = undef;
        }
    }

    my $result;
    if(defined $marcs && blessed $marcs && $marcs->isa('MARC::Record')){
        $result->{itemtype} = $marcs->subfield('942', 'c');
        $result->{language} = $marcs->subfield('041', 'a' || '041', 'd');

        my $cn_class = $self->cnClass($marcs->subfield('084', 'a')) if $marcs->subfield('084', 'a');

        $result->{cn_class} = $cn_class // -1;
    }

    return $result;
}

sub cnClass{
    my $self = shift;
    my ($cn_class) = @_;

    my ($cn_primary, $cn_decimal) = split /\./, $cn_class;
    $cn_primary =~ s/\D//g;

    return $cn_primary;
}

1;
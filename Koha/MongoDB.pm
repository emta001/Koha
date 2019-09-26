package Koha::MongoDB;

# Copyright Koha-Suomi Oy 2018
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Koha::MongoDB::Logs;
use Koha::MongoDB::Users;
use Koha::MongoDB::Config;

use Koha::MongoDB::Reporting::Configs;
use Koha::MongoDB::Reporting::Loans;
use Koha::MongoDB::Reporting::Items;

use Try::Tiny; 

sub new {
    my ($class, $params) = @_;

    my $config = new Koha::MongoDB::Config;
    my $dbh    = $config->mongoClient();
    my $self = {
        'logs' => Koha::MongoDB::Logs->new({ dbh => $dbh }),
        'users' => Koha::MongoDB::Users->new({ dbh => $dbh }),
        'loans' => Koha::MongoDB::Reporting::Loans->new(),
        'xml_config' => Koha::MongoDB::Reporting::Configs->new(),
        'items' => Koha::MongoDB::Reporting::Items->new(),
        'config' => $config,
        'client' => $dbh,
        'settings' => $config->getSettings(),
    };

    bless $self, $class;

    return $self;
}

=head3 push_action_logs

    $mongo->push_action_logs();

copies data from table action_logs_cache to mongodb

=cut

sub push_action_logs {
    my $self = shift;
    my ($mongologs, $limit, $limit_unreached_sleep) = @_;

    my $retval=0;
    my $logs = $self->{logs};
    my $users = $self->{users};

    $limit //= 0;
    $limit_unreached_sleep //= 60;

    try {
        # all rows from table
        my $actionlogs = $logs->getActionCacheLogs({
            limit => $limit,
            order_by => 'user, object'
        });
        if (@{$actionlogs} == 0 || defined $limit && @{$actionlogs} < $limit) {
            sleep($limit_unreached_sleep);
            $retval = 1;
            return;
        }
        my @actions;
        my @actionIds;

        my $prev_koha_user;
        my $prev_koha_object;
        foreach my $actionlog (@{$actionlogs}) {
            my $borrowernumber = $actionlog->{object};
            my $action_id = $actionlog->{action_id};

            if($actionlog->{object}) {
                my $objectuser = $prev_koha_object;
                if (!defined $prev_koha_object ||
                    $prev_koha_object->{borrowernumber} != $actionlog->{object})
                {
                    $objectuser = $users->getUser($actionlog->{object});
                    $prev_koha_object = $objectuser; # store it for next iteration
                }
                my $objectuserId = $users->setUser($objectuser);
                my $sourceuser;
                my $sourceuserId;

                if($actionlog->{user}) {
                    $sourceuser = $prev_koha_user;
                    if (!defined $prev_koha_user ||
                        $prev_koha_user->{borrowernumber} != $actionlog->{user})
                    {
                        $sourceuser = $users->getUser($actionlog->{user});
                        $prev_koha_user = $sourceuser; # store it for next iteration
                    }
                    $sourceuserId = $users->setUser($sourceuser);
                }

                my $result = $logs->setUserLogs($actionlog, $sourceuserId, $objectuserId, $objectuser->{cardnumber}, $objectuser->{borrowernumber});
                push @actions, $result;
            }

            #remove row from table
            push @actionIds, $action_id;
        }
        my $return = $mongologs->insert_many(\@actions);
        if ($return->acknowledged) {
            $self->_remove_logs_cache(@actionIds);
        }

        $retval = 1;
        #sleep(1);
    }
    catch {
        warn "caught error: $_";
    };

    return($retval);
}

=head3 _remove_logs_cache

    $mongo->_remove_logs_cache();

removes rows from table action_logs_cache

=cut

sub _remove_logs_cache {
    my $self = shift;
    my @actionIds = @_;
    my $dbh = C4::Context->dbh();
    my $sqlstring = "delete from action_logs_cache where action_id = ?";
    my $query = $dbh->prepare($sqlstring);
    foreach my $action_id (@actionIds) {
        $query->execute($action_id) or die;
    }
}

sub push_loans {
    my $self = shift;
    my ($mongocol) = @_;
    my $loans = $self->{loans};
    my $items = $self->{items};
    my $config = $self->{xml_config};
    my $loans_config = $config->loadConfigs()->{conf}; #<-!!!

    my $itemTypes = $loans_config->{itemTypeToStatisticalCategory}; 

    my $adults_locations = $loans_config->{adultShelvingLocations};
    my $juveniles_locations = $loans_config->{juvenileShelvingLocations}; 

    try {  
        my $loans_sql = $loans->getLoans({
            order_by => 'branch',
            limit => 50
        });

        #collect branches and their loans itemnumbers
        my %branchgroups;
        my $key;
        for my $loan (@{$loans_sql}){   
            $key = $loan->{branch};  
            push @{$branchgroups{$key}}, $loan->{itemnumber};      
        }

        my $result;
        my $prev_branch;
        my @loans_mongo;
        my $loans_info;
        
        while (my($branch_key, $itemnumbers) = each %branchgroups){
            
            my $loans_total = 0;

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
                
                my $item = $items->getItem($itemnumber);
                my $permanent_location = $item->{permanent_location};
                my $biblionumber = $item->{biblionumber};
                
                my $biblio_records;
                if(defined $biblionumber){
                    $biblio_records = $items->getBiblioRecords($biblionumber);    
                }

                #!!!
                if(defined $biblio_records){

                    my $category = $itemTypes->{$biblio_records->{itemtype}};

                    if($category eq 'Books'){
                        $books_total++;
                         
                        if($biblio_records->{language} eq 'fin'){
                            $books_fin++;
                        }elsif($biblio_records->{language} eq 'swe'){
                            $books_swe++;
                        }else{
                            $books_other_lan++;
                        } 

                        if(grep(/^($permanent_location)$/, @{$adults_locations})){
                            if($biblio_records->{cn_class} >= 80 && $biblio_records->{cn_class} <= 85){
                                $adults_fiction++;
                            }elsif(($biblio_records->{cn_class} >= 0 && $biblio_records->{cn_class} <= 79) || ($biblio_records->{cn_class} >= 86 && $biblio_records->{cn_class} <= 99)){
                                $adults_fact++;
                            }
                        }elsif(grep(/^($permanent_location)$/, @{$juveniles_locations})){
                            if($biblio_records->{cn_class} >= 80 && $biblio_records->{cn_class} <= 85){
                                $juveniles_fiction++;
                            }elsif(($biblio_records->{cn_class} >= 0 && $biblio_records->{cn_class} <= 79) || ($biblio_records->{cn_class} >= 86 && $biblio_records->{cn_class} <= 99)){
                                $juveniles_fact++;
                            }
                        }

                    }elsif($category eq 'SheetMusicAndScores'){
                        $sheet_music++;
                    }elsif($biblio_records->{cn_class} eq 78 && $category eq 'Recordings'){
                        $recordings_music++;
                    }elsif($biblio_records->{cn_class} ne 78 && $category eq 'Recordings'){
                        $recordings_other++;
                    }elsif($category eq 'Videos'){
                        $videos++;
                    }elsif($category eq 'CDROMs'){
                        $cdroms++;
                    }elsif($category eq 'DVDsAndBluRays'){
                        $dvds_brs++;
                    }elsif($category eq 'Other'){
                        $others++;
                    }

                }

                $loans_total++;

                #!!!!
                $loans_info = [{
                    loans_total => $loans_total,
                    books => [{
                        books_total => $books_total,
                        books_fin => $books_fin,
                        books_swe => $books_swe ,
                        books_other_lan => $books_other_lan, 
                        adults_fiction => $adults_fiction,
                        adults_fact => $adults_fact,
                        juveniles_fiction => $juveniles_fiction,
                        juveniles_fact => $juveniles_fact
                    }],
                    sheet_music => $sheet_music,
                    recordings_music => $recordings_music,
                    recordings_other => $recordings_other,
                    videos => $videos,
                    cdroms => $cdroms,
                    dvds_brs => $dvds_brs,
                    others => $others
                
                }];
            
                $result = $loans->setLoans($branch_key, $loans_info);    
            }
                
            push @loans_mongo, $result;
      
        }

        my $return = $mongocol->insert_one({
            timestamp => "nyt",
            branches=> \@loans_mongo 
            });

    } catch {
        warn "error: $_";
    }
  
}
=uu
=cut
1;

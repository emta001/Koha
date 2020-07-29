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
use Koha::DateUtils qw(dt_from_string);
use DateTime::Format::MySQL;
use Koha::MongoDB::Reporting::General;
use Koha::MongoDB::Reporting::Loans;
use Koha::MongoDB::Reporting::Items;
use Koha::MongoDB::Reporting::Serials;
use Koha::MongoDB::Reporting::Acquisitions;
use Koha::MongoDB::Reporting::Borrowers;

use Try::Tiny;

sub new {
    my ($class, $params) = @_;

    my $config = new Koha::MongoDB::Config;
    my $dbh    = $config->mongoClient();
    my $self = {
        'logs' => Koha::MongoDB::Logs->new({ dbh => $dbh }),
        'users' => Koha::MongoDB::Users->new({ dbh => $dbh }),
        'general' => Koha::MongoDB::Reporting::General->new(),
        'loans' => Koha::MongoDB::Reporting::Loans->new(),
        'items' => Koha::MongoDB::Reporting::Items->new(),
        'serials' => Koha::MongoDB::Reporting::Serials->new(),
        'acquisitions' => Koha::MongoDB::Reporting::Acquisitions->new(),
        'borrowers' => Koha::MongoDB::Reporting::Borrowers->new(),
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
    my ($mongocol, $limit, $from_date, $to_date) = @_;
    my $loans = $self->{loans};
    my $items = $self->{items};
    my $generals = $self->{general};

    try {

        my $check_collection = $generals->checkCollection($mongocol, $from_date);
        return if $check_collection;

        my $configs = $generals->loadConfigs();
        my $itemtypes = $configs->{itemTypeToStatisticalCategory};
        my $adults_locations = $configs->{adultShelvingLocations};
        my $juveniles_locations = $configs->{juvenileShelvingLocations};
        my $patron_categories = $configs->{patronCategories};

        my $loans_sql = $loans->getLoans({
            limit => $limit
        },$patron_categories, $from_date, $to_date);

        my $branchgroups = $generals->generateBranchGroups($loans_sql);
        my $result;
        my $items_count;
        my @loans_mongo;

        while (my($branch_key, $itemnumbers) = each %{$branchgroups}){

            $items_count = $items->countItems($itemnumbers, $itemtypes, $adults_locations, $juveniles_locations);

            $result = {
                branch => $branch_key,
                loans => $items_count
            };

            push @loans_mongo, $result;

        }

        my $return = $generals->pushToMongo($mongocol, $from_date, \@loans_mongo);

    } catch {
        warn "error: $_";
    }

}

sub push_collections {
    my $self = shift;
    my ($mongocol, $limit, $from_date, $to_date) = @_;
    my $items = $self->{items};
    my $generals = $self->{general};

    try {

        my $check_collection = $generals->checkCollection($mongocol, $from_date);
        return if $check_collection;

        my $configs = $generals->loadConfigs();

        my $itemtypes = $configs->{itemTypeToStatisticalCategory};
        my @itemtypes = grep { %{$itemtypes}{$_} ne 'Serials' } keys %{$itemtypes};
        my $adults_locations = $configs->{adultShelvingLocations};
        my $juveniles_locations = $configs->{juvenileShelvingLocations};
        my $notforloan = $configs->{notForLoanStatuses};

        my $items_sql = $items->getItems({
            limit => $limit
        }, \@itemtypes, $notforloan, $to_date);

        my $branchgroups = $generals->generateBranchGroups($items_sql);

        my $result;
        my $items_count;
        my @collections_mongo;

        while (my($branch_key, $itemnumbers) = each %{$branchgroups}){

            $items_count = $items->countItems($itemnumbers, $itemtypes, $adults_locations, $juveniles_locations);
            $result = $items->setItems($branch_key, $items_count);

            push @collections_mongo, $result;

        }

        my $return = $generals->pushToMongo($mongocol, $from_date, \@collections_mongo);

    } catch {
        warn "error: $_";
    }

}

sub push_acquisitions {
    my $self = shift;
    my ($mongocol, $limit, $from_date, $to_date) = @_;
    my $acquisitions = $self->{acquisitions};
    my $items = $self->{items};
    my $generals = $self->{general};

    try {

        my $check_collection = $generals->checkCollection($mongocol, $from_date);
        return if $check_collection;

        my $configs = $generals->loadConfigs();
        my $itemtypes = $configs->{itemTypeToStatisticalCategory};
        my $adults_locations = $configs->{adultShelvingLocations};
        my $juveniles_locations = $configs->{juvenileShelvingLocations};

        my $acquisitions_sql = $acquisitions->getAcquisitions({
            limit => $limit
        }, $from_date, $to_date);

        my $branchgroups = $generals->generateBranchGroups($acquisitions_sql);
        my $result;
        my $items_count;
        my $acquisitions_total_price;
        my @acquisitions_mongo;

        while (my($branch_key, $itemnumbers) = each %{$branchgroups}){

            $items_count = $items->countItems($itemnumbers, $itemtypes, $adults_locations, $juveniles_locations);
            $acquisitions_total_price = $acquisitions->acquisitionsTotalPrice($itemnumbers);
            $result = $acquisitions->setAcquisitions($branch_key, $items_count, $acquisitions_total_price);
            push @acquisitions_mongo, $result;

        }

        my $return = $generals->pushToMongo($mongocol, $from_date, \@acquisitions_mongo);

    } catch {
        warn "error: $_";
    }
}

sub push_deleted_items {
    my $self = shift;
    my ($mongocol, $limit, $from_date, $to_date) = @_;
    my $items = $self->{items};
    my $generals = $self->{general};

    try {

        my $check_collection = $generals->checkCollection($mongocol, $from_date);
        return if $check_collection;

        my $configs = $generals->loadConfigs();
        my $itemtypes = $configs->{itemTypeToStatisticalCategory};
        my @itemtypes = grep { %{$itemtypes}{$_} ne 'Serials' } keys %{$itemtypes};

        my $deleted_sql = $items->getDeletedItems({
            limit => $limit
        }, \@itemtypes, $from_date, $to_date);

        my $branchgroups = $generals->generateBranchGroups($deleted_sql);
        my $result;
        my @deleted_mongo;

        while (my($branch_key, $itemnumbers) = each %{$branchgroups}){
            my $total = 0;
            foreach my $itemnumber (@{$itemnumbers}){
                $total++;
            }

            $result = $items->setDeletedItems($branch_key, $total);

            push @deleted_mongo, $result;
        }

        my $return = $generals->pushToMongo($mongocol, $from_date, \@deleted_mongo);

    } catch {
        warn "error: $_";
    }

}

sub push_borrowers {
    my $self = shift;
    my ($mongocol, $limit, $from_date, $to_date) = @_;
    my $borrowers = $self->{borrowers};
    my $generals = $self->{general};
    my $log;

    try {

        my $check_collection = $generals->checkCollection($mongocol, $from_date);
        return if $check_collection;

        my $configs = $generals->loadConfigs();
        my $patron_categories = $configs->{patronCategories};
        my $borrowers_sql = $borrowers->getBorrowers({
            limit => $limit
        },$patron_categories, $from_date, $to_date);

        my $borrowers_branchgroups = $borrowers->generateBorrowerGroups($borrowers_sql);
        my $result;

        while (my($date, $branch_keys) = each %{$borrowers_branchgroups}){
            my @borrowers_mongo;
            while (my($branch_key, $borrowernumbers) = each %{$branch_keys}){
                my $total = 0;
                foreach my $borrowernumber (@{$borrowernumbers}){
                    $total++;
                }

                $result = $borrowers->setBorrowers($branch_key, $total);

                push @borrowers_mongo, $result;

            }
            my $return = $generals->pushToMongo($mongocol, $date, \@borrowers_mongo);

        }

    } catch {
        warn "error: $_";
    }
}

=serials
#not in use until there's a way to collect serials the way they should be
sub push_serials {

    my $self = shift;
    my ($mongocol, $limit, $to_date) = @_;
    my $serials = $self->{serials};
    my $generals = $self->{general};

    try {
        my $itemtypes = $generals->loadConfigs()->{itemTypeToStatisticalCategory};
        my @serial_keys = grep { %{$itemtypes}{$_} eq 'Serials' } keys %{$itemtypes};
        my $notforloan = $generals->loadConfigs()->{notForLoanStatuses};
        my $serials_sql = $serials->getSerials({
            limit => $limit
        }, \@serial_keys, $notforloan, $to_date);

        my $branchgroups = $generals->generateBranchGroups($serials_sql);
        my $result;
        my $serials_count;
        my @serials_mongo;

        while (my($branch_key, $itemnumbers) = each %{$branchgroups}){

            $serials_count = $serials->countSerials($itemnumbers, $generals->loadConfigs());
            $result = $serials->setSerials($branch_key, $serials_count);

            push @serials_mongo, $result;
        }

        my $return = $generals->pushToMongo($mongocol, $to_date, \@serials_mongo);


    } catch {
        warn "error: $_";
    }
}

=cut
1;

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

use Try::Tiny;

sub new {
    my ($class, $params) = @_;

    my $config = new Koha::MongoDB::Config;
    my $dbh    = $config->mongoClient();
    my $self = {
        'logs' => Koha::MongoDB::Logs->new({ dbh => $dbh }),
        'users' => Koha::MongoDB::Users->new({ dbh => $dbh }),
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

1;

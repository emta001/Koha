#!/usr/bin/perl
#

use strict;
use warnings;

use C4::Context;
use Koha::MongoDB;
use Koha::DateUtils qw(dt_from_string);
use DateTime::Format::MySQL;
use Data::Dumper qw(Dumper);

my $mongodb = Koha::MongoDB->new();
my $client = $mongodb->{client};
my $settings = $mongodb->{settings};
my $db = $client->get_database('reports');

my $from_date = DateTime::Format::MySQL->format_datetime(dt_from_string()->subtract(months => 1));
my $to_date = DateTime::Format::MySQL->format_datetime(dt_from_string());

my $limit = 100;

my $collections = $client->ns($settings->{database}.'.collections');
$mongodb->push_collections($collections, $limit, $from_date, $to_date);
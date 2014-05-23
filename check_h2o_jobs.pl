#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date: 2014-04-05 22:03:20 +0100 (Sat, 05 Apr 2014)
#
#  http://github.com/harisekhon
#
#  License: see accompanying LICENSE file
#

$DESCRIPTION = "Nagios Plugin to check for failed jobs on a 0xdata H20 machine learning cluster via REST API";

$VERSION = "0.1";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use POSIX 'ceil';

our $ua = LWP::UserAgent->new;

$ua->agent("Hari Sekhon $progname version $main::VERSION");

set_port_default(54321);

env_creds("H2O");

my $cloud_name;
my $instances = 0;
my $locked    = 0;
my $uptime    = 0;
my $h2o_version;

%options = (
    %hostoptions,
);
@usage_order = qw/host port/;

get_options();

$host        = validate_host($host);
$port        = validate_port($port);

vlog2;
set_timeout();

$status = "OK";

my $url_prefix = "http://$host:$port";
my $url = "$url_prefix/Jobs.json";

my $content = curl $url;

my $json;
try{
    $json = decode_json $content;
};
catch{
    quit "invalid json returned by H2O at '$url_prefix'";
};
vlog3(Dumper($json));

defined($json->{"jobs"}) or quit "UNKNOWN", "'jobs' field not returned by H2O at '$url_prefix'. $nagios_plugins_support_msg_api";

isArray($json->{"jobs"}) or quit "UNKNOWN", "'jobs' field is not an array as expected. $nagios_plugins_support_msg_api";

my %failed_jobs;
foreach my $job (@{$json->{"jobs"}}){
    defined($job->{"description"})     or quit "UNKNOWN", "'description' field not found. $nagios_plugins_support_msg_api";
    defined($job->{"result"}->{"val"}) or quit "UNKNOWN", "job result not found for job '" . $job->{"description"} . "'. $nagios_plugins_support_msg_api";
    $job->{"result"}->{"val"} eq "OK"  or $failed_jobs{$job->{"description"}} = 1;
}

if(%failed_jobs){
    critical;
    $msg .= "failed jobs: ";
    foreach(sort keys %failed_jobs){
        $msg .= "$_, ";
    }
    $msg =~ s/, $//;
} else {
    $msg .= "no failed jobs detected in H2O cluster";
    $msg .= " at '$url_prefix'" if $verbose;
}

vlog2;
quit $status, $msg;

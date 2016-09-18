#!/usr/local/bin/perl

use strict;
use warnings;

use IO::Socket::INET;
use Sys::Hostname;

my %settings = (
	'influxdb' => {
		'address'	=> '192.168.20.4',
		'port'		=> 8089,
	},
);

main(\%settings);
exit;

sub main {

	my $settings_ref = shift;

	my $cpuinfo_ref = get_cpuinfo();
	(my $result, my $message_ref) = send_data($settings_ref, $cpuinfo_ref);

	print join(", ", @{$message_ref}) . "\n";

	return($result);
}

sub get_cpuinfo {

	my %data;

	my $number_of_cpus = `/sbin/sysctl -n hw.ncpu`;

	for ( my $cpu_id = 0; $cpu_id < $number_of_cpus; $cpu_id++ ) {

		# Sample output
		#   58.0C
		my $temp = `/sbin/sysctl -n dev.cpu.$cpu_id.temperature`;

		# Format the output
		chomp($temp);
		$temp =~ s/[FC]$//;

		$data{$cpu_id}->{'temp'} = $temp;
	}

	return(\%data);
}

sub create_lineprotocol {

	my $data_ref = shift;

	my $hostname = hostname();

	my $line_protocol;
	my $timestamp = (int( time /10 ) * 10 ) * 1000000000;

	foreach my $cpu_id ( sort keys %{$data_ref} ) {

		my @data;
		my @tags = (
			'cpu_temp',
			"cpu_id=$cpu_id",
			"host_name=$hostname",
		);

		push(@data, join(',', @tags));
		push(@data, "value=$data_ref->{$cpu_id}->{'temp'}");
		push(@data, $timestamp);

		$line_protocol .= sprintf("%s %s %d\n", @data);
	}

	return($line_protocol);
}

sub send_data {

	my $settings_ref = shift;
	my $data_ref = shift;

	my $socket = new IO::Socket::INET (
		PeerAddr	=> $settings_ref->{"influxdb"}->{"address"},
		PeerPort	=> $settings_ref->{"influxdb"}->{"port"},
		Proto		=> 'udp',
	) or return(1, [ "cannot create socket: $@" ]);

	my $lineprotocol = create_lineprotocol($data_ref);

	$socket->send($lineprotocol);
	$socket->close;

	return(0, []);
}

__END__

=head1 NAME

monitor_bsd_cputemp.pl - Monitor CPU temperatures on FreeBSD systems

=head1 SYNOPSYS

	monitor_bsd_cputemp.pl

=head1 DESCRIPTION

This script gathers CPU temperature information and sends it via UDP to an
Influx time-series database. The data in the InfluxDB can be visualized in
different ways like Grafana and Influx' own Chronograf.

The data is formatted specifically for the IndluxDB in the line protocol format.
The line protocol supports tags to add information to the values. The hostname
and the CPU (or core) ID are added as tags.

The address and port of the InfluxDB server is configured in the hash for the
settings at the top of the script. The influxDB database should be configured to
accept data over UDP. See the InfluxDB documentation on how to do this.

=head1 NOTES

This software has been tested on FreeNAS 9.10. It should work with other FreeBSD
versions and maybe even on other BSD versions supporting sysctl and temperature
monitoring (also depends on CPU).

=head1 AUTHOR

Jurriaan Saathof <jurriaan@xenophobia.nl>

=head1 COPYRIGHT

Copyright 2016 Jurriaan Saathof

=head1 SEE ALSO

IO::Socket::INET(3pm), Sys::Hostname{3pm}
https://www.influxdata.com/time-series-platform/
http://grafana.org
http://www.freenas.org

=cut


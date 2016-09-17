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
	send_data($settings_ref, $cpuinfo_ref);

	return;
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
		PeerAddr    => $settings_ref->{"influxdb"}->{"address"},
		PeerPort	=> $settings_ref->{"influxdb"}->{"port"},
		Proto       => 'udp',
	) or return(1, [ "cannot create socket: $@" ], undef);

	my $lineprotocol = create_lineprotocol($data_ref);

	$socket->send($lineprotocol);
	$socket->close;

	return(0, [], undef);
}

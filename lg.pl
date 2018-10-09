#!/usr/bin/perl
use warnings;
use strict;
use CGI qw(param);

my $VERSION = '0.1';

our $proto_validation = '^[a-zA-Z0-9-._]+$';
our $bird_client = '/usr/sbin/birdc';



sub exec_cmd {
	my $cmd = shift;
	open my $bird, '-|', $bird_client, '-r', $cmd;
	print "CMD: $bird_client -r <b>$cmd</b><br />\n";
	while (my $line = <$bird>) {
		print "$line<br />\n";
	}
	close $bird;
}

sub print_tmpl {
	my $template = shift;
	open my $f, '<', 'templates/' . $template . '.tmpl';
	while (my $line = <$f>) {
		print $line;
	}
	close $f;
}

sub routes {
	my $line = shift;
	my $name = shift;
	my $imported = -1;
	my $filtered = -1;
	my $exported = -1;
	my $preferred = -1;
	my @routes = ();
	# 26 imported, 738894 exported, 18 preferred
	# 738796 imported, 135 filtered, 1 exported, 29220 preferred
	@routes = split /\s+/, $line;

	# imported / best / exported
	if ($line =~ /filtered/) {
		return "
<td><a href='?a=route&q=$name&t=1'>$routes[2]</a></td>
<td><a href='?a=route&q=$name&t=2'>$routes[0]</a></td>
<td><a href='?a=route&q=$name&t=3'>$routes[6]</a></td>
<td><a href='?a=route&q=$name&t=4'>$routes[4]</a></td>\n";
	} else {
		return "<td></td>
<td><a href='?a=route&q=$name&t=2'>$routes[0]</a></td>
<td><a href='?a=route&q=$name&t=3'>$routes[4]</a></td>
<td><a href='?a=route&q=$name&t=4'>$routes[2]</a></td>\n";
	}
}

sub asn {
	my $asn = shift;
	if ($asn eq '0') {
		return '';
	} else {
		return "<a href=\"https://apps.db.ripe.net/search/lookup.html?source=ripe&key=AS$asn&type=aut-num\">$asn</a></td>\n";
	}
	
}

sub nip {
	my $ip = shift;
	if ($ip eq '0') {
		return '';
	} else {
		return $ip;
	}
}

sub show_proto {
	my $proto;

	if (!defined(param('p'))) {
		print "p(protocol name) is required parameter)\n";
		return;
	}
	$proto = param('p');

	if ($proto !~ /$proto_validation/i) {
		print "Invalid protocol name\n";
		return;
	}
	print "<pre>\n";
	exec_cmd('show protocols all ' .  $proto);
}

sub bgp_summary {
	open my $cmd, '-|', $bird_client,  '-r', 'show', 'protocols';
	print "<table>\n";
	while (my $line = <$cmd>) {
		my $neighboor_ip = '';
		my $neighboor_asn = '';
		my $routes_line = '';
		my @arr = split /\s+/, $line;
		print "<tr>\n";
		if ($arr[0] eq 'BIRD' || $arr[0] eq 'Access') {
			next;
		}
		if ($arr[0] eq 'name') {
			print "<td>Name</td>\n";
			print "<td>State</td>\n";
			print "<td>Since</td>\n";
			print "<td>Info</td>\n";
			print "<td>Neighboor</td>\n";
			print "<td>ASN</td>\n";
			print "<td>Filtered</td>\n";
			print "<td>IMPORTED</td>\n";
			print "<td>BEST</td>\n";
			print "<td>EXPORTED</td>\n";
			next;
		}
	
		# Print the basic information
		print "<td><a href='?a=proto&p=$arr[0]'>$arr[0]</a></td>\n";
		print "<td>$arr[3]</td>\n";
		$arr[4] =~ s/^[0-9]{4}-//;
		print "<td>$arr[4] $arr[5]</td>\n";
		print "<td>$arr[6]</td>\n";
	
		# Get the neighboor and routes data
		open my $bgp_info, '-|', $bird_client, '-r', 'show', 'protocols', 'all', $arr[0];
		while (my $bline = <$bgp_info>) {
			if ($bline =~ /Neighbor\s+AS:\s+([0-9]+)/) {
				$neighboor_asn = asn($1);
			}
			if ($bline =~ /Neighbor\s+address:\s+([0-9.]+)/) {
				$neighboor_ip = nip($1);
			}
			if ($bline =~ /\s+Routes:\s+(.*)/) {
				$routes_line = routes($1, $arr[0]);
			}
		}
		close $bgp_info;
	
		# Print the neighboor and Routes
		print "<td><a href='https://stat.ripe.net/$neighboor_ip'>$neighboor_ip</a></td>\n";
		print "<td>$neighboor_asn</td>\n";
		print $routes_line;
		print "</tr>\n";
	}
}

sub show_route {
	if (defined(param('q')) && defined(param('t'))) {
		my $cmd = '';
		my $all = '';
		if (param('q') !~ /$proto_validation/) {
			print "Invalid name\n";
			return;
		}
		if (defined(param('a')) && param('a') eq 'all') {
			$all = 'all';
		}
		if (param('t') eq 1) {
			# filtered
			$cmd = "show route $all filtered protocol " . param('q');
		}
		if (param('t') eq 2) {
			# imported
			$cmd = "show route $all protocol " . param('q');
		}
		if (param('t') eq 3) {
			# preferred
			$cmd = "show route $all primary protocol " . param('q');
		}
		if (param('t') eq 4) {
			# exported
			$cmd = "show route $all export " . param('q');
		}
		exec_cmd($cmd);
	} else {
		print "q(protocol name) and t(type 1- filtered, 2- imported, 3- preferred, 4- exported) are required parameters\n";
		return;
	}
}

print "Content-type: text/html\r\n\r\n";
print_tmpl('header');

my $action = '';
if (defined(param('a'))) {
	$action = param('a');
}

if ($action eq 'route') {
	show_route();
} elsif ($action eq 'proto') {
	show_proto();
} else {
	bgp_summary();
}

print_tmpl('footer');

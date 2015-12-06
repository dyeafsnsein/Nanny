package KKrcon;

# KKrcon Perl Module - execute commands on a remote Half-Life server using Rcon.
# http://kkrcon.sourceforge.net
#
# Synopsis:
#
#   use KKrcon;
#   $rcon = new KKrcon(Password=>PASSWORD, [Host=>HOST], [Port=>PORT], [Type=>"new"|"old"]);
#   $result  = $rcon->execute(COMMAND);
#
# Copyright (C) 2000, 2001  Rod May
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

use Socket;
use Sys::Hostname;

# Main

sub new {
	my $class_name = shift;
	my %params     = @_;
	my $self       = {};
	bless($self, $class_name);
	my %server_types = (new => 1, old => 2);

	# Check parameters
	$params{"Host"} = "127.0.0.1" unless ($params{"Host"});
	$params{"Port"} = "28960"     unless ($params{"Port"});
	$params{"Type"} = "new"       unless ($params{"Type"});

	# Initialise properties
	$self->{"rcon_password"} = $params{"Password"} or die("KKrcon: a Password is required\n");
	$self->{"server_host"}   = $params{"Host"};
	$self->{"server_port"}   = int($params{"Port"}) or die("KKrcon: invalid Port \"" . $params{"Port"} . "\"\n");
	$self->{"server_type"}   = ($server_types{$params{"Type"}} || 1);
	$self->{"error"}         = "";

	# Set up socket parameters
	$self->{"_proto"} = getprotobyname('udp');
	$self->{"_ipaddr"} = gethostbyname($self->{"server_host"}) or die("KKrcon: could not resolve Host \"" . $self->{"server_host"} . "\"\n");

	# Return values
	return $self;
}

# Execute an Rcon command and return the response

sub execute {
	my ($self, $command) = @_;
	my $msg;
	my $ans;

	# BEGIN: say hack to match unicode characters
	if ($command =~ /^say\s(.*)/) { $command = "say " . '"' . "$1" . '"'; }

	# END: say hack
	if ($self->{"server_type"} == 1) {

		# version x.1.0.6+ HL server
		$msg = "\xFF\xFF\xFF\xFFchallenge rcon\n\0";
		$ans = $self->sendrecv($msg);

		if ($ans =~ /challenge +rcon +(\d+)/) {
			$msg = "\xFF\xFF\xFF\xFFrcon $1 \"" . $self->{"rcon_password"} . "\" $command\0";
			$ans = $self->sendrecv($msg);
		}
		elsif (!$self->error) {
			$ans = "";
			$self->{"error"} = "No challenge response";
		}
	}
	else {
		# QW/Q2/Q3 or old HL server
		$msg = "\xFF\xFF\xFF\xFFrcon " . $self->{"rcon_password"} . " $command\n\0";
		$ans = $self->sendrecv($msg);
	}

	if ($ans =~ /bad rcon_password/i) { $self->{"error"} = "Bad Password"; }

	return $ans;
}

sub sendrecv {
	my ($self, $msg) = @_;
	my $host   = $self->{"server_host"};
	my $port   = $self->{"server_port"};
	my $ipaddr = $self->{"_ipaddr"};
	my $proto  = $self->{"_proto"};

	# Open socket
	socket(RCON, PF_INET, SOCK_DGRAM, $proto) or die("KKrcon: socket: $!\n");

	# bind causes problems if hostname gets wrong interface...
	# and it doesn't seem to be necessary
	# my $iaddr = gethostbyname(hostname);
	# my $paddr = sockaddr_in(0, $iaddr);
	# bind(RCON, $paddr) or die("KKrcon: bind: $!\n");
	my $hispaddr = sockaddr_in($port, $ipaddr);
	unless (defined(send(RCON, $msg, 0, $hispaddr))) { print("KKrcon: send $ipaddr:$port : $!"); }

	my $rin = "";
	vec($rin, fileno(RCON), 1) = 1;
	my $ans = "TIMEOUT";

	if (select($rin, undef, undef, 10.0)) {
		$ans = "";
		$hispaddr = recv(RCON, $ans, 8192, 0);
		$ans =~ s/\x00+$//;                    # trailing crap
		$ans =~ s/^\xFF\xFF\xFF\xFFl//;        # HL response
		$ans =~ s/^\xFF\xFF\xFF\xFFn//;        # QW response
		$ans =~ s/^\xFF\xFF\xFF\xFF//;         # Q2/Q3 response
		$ans =~ s/^\xFE\xFF\xFF\xFF.....//;    # old HL bug/feature

		# my ugly hack for long responses.
		#  - smug
		my $lol;
		my @explode;
		while (select($rin, undef, undef, 0.05)) {

			# this really sucks.  We're missing a byte and I can't find it
			# BECAUSE ITS NOT THERE.
			# fuckers.  This seems to be a bug in the game.
			# Even the in-game /rcon command has the missing-byte bug.
			# Now that we know we can't fix it now we mark it as corrupt.
			# First, we mark the begining of the last line of what we've received
			# so far as being corrupt.
			@explode = split(/\n/, $ans);
			$explode[$#explode] =~ s/^ //;
			$explode[$#explode] = 'X' . $explode[$#explode];
			$ans = join("\n", @explode);

			# now we receive, strip again, and append.
			$lol = '';
			$hispaddr = recv(RCON, $lol, 8192, 0);
			$lol =~ s/\x00+$//;                    # trailing crap
			$lol =~ s/^\xFF\xFF\xFF\xFFl//;        # HL response
			$lol =~ s/^\xFF\xFF\xFF\xFFn//;        # QW response
			$lol =~ s/^\xFF\xFF\xFF\xFF//;         # Q2/Q3 response
			$lol =~ s/^\xFE\xFF\xFF\xFF.....//;    # old HL bug/feature
			$lol = substr($lol, 6, 8192);
			$ans .= $lol;
		}

		# End of the llama / platypus ugly hack for long responses.
	}

	# Close socket
	close(RCON);

	if ($ans eq "TIMEOUT") {
		$ans = "";
		$self->{"error"} = "Rcon timeout";
	}

	return $ans;
}

# Get error message

sub error {
	my ($self) = @_;
	return $self->{"error"};
}

# End

1;

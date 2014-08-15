#! /bin/perl -w
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

use Getopt::Long;
use Pod::Usage;
use WWW::Mechanize;
use RRD::Simple;

sub collect
{
  my $login = shift;
  my $password = shift;

  my $rrdfile = "modem.rrd";

  my $triaUrl = "http://192.168.100.1/?page=triaStatusData";
  my $modemUrl = "http://192.168.100.1/?page=modemStatusData";

  my $mech = WWW::Mechanize->new(autocheck => 1);
  # Get Tria Info
  $mech->get($triaUrl);
  @values = split(/\#\#/, $mech->content);
  my $triaTxIFPower = $values[7];
  my $triaRFPower = $values[17];
  my $triaTemperature = $values[19];

  #print "Tria TX IF Power ", $triaTxIFPower, "\n";
  #print "Tria RX Power: ", $triaRFPower, "\n";
  #print "Tria Temperature: ", $triaTemperature, "\n";


  # Get modem info
  $mech->get($modemUrl);
  @values = split(/\#\#/, $mech->content);
  my $modemStatus = $values[4];
  my $modemTxPackets = $values[5];
  my $modemTxBytes = $values[6];
  my $modemRxPackets = $values[7];
  my $modemRxBytes = $values[8];
  my $modemOnlineTime = $values[9];
  my $modemLossSyncCount = $values[10];
  my $modemRxSNR = $values[11];
  my $modemRxPower = $values[14];
  my $modemCableResistance = $values[16];
  my $modemODUTelemetryStatus = $values[18];
  my $modemCableAttenuation = $values[19];
  my $modemPageLoadTime = $values[30];

  #print "Status: ", $modemStatus, "\n";
  #print "Tx Packets: ", $modemTxPackets, "\n";
  #print "Tx Bytes: ", $modemTxBytes, "\n";
  #print "Rx Packets ", $modemRxPackets, "\n";
  #print "Rx Bytes: ", $modemRxBytes, "\n";
  #print "Online time: ", $modemOnlineTime, "\n";
  #print "Loss Sync Count: ", $modemLossSyncCount, "\n";
  #print "Rx SNR: ", $modemRxSNR, "\n";
  #print "Rx Power: ", $modemRxPower, "\n";
  #print "Cable Resistance: ", $modemCableResistance, "\n";
  #print "ODU Telemetry Status: ", $modemODUTelemetryStatus, "\n";
  #print "Cable Attenuation ", $modemCableAttenuation, "\n";
  #print "modemPageLoadTime ", $modemPageLoadTime, "\n";

  # normalize by removing commas on these
  $modemTxPackets =~ s/,//g;
  $modemRxPackets =~ s/,//g;
  $modemTxBytes =~ s/,//g;
  $modemRxBytes =~ s/,//g;

  # if RRD file doesn't exist, create it
  my $rrd = RRD::Simple->new(file => $rrdfile);
  unless (-e $rrdfile)
  {
  $rrd->create
    (
      # data that comes from SurfBeam 2 modem
      triaTxIFPower => "GAUGE",
      triaRFPower => "GAUGE",
      triaTemperature => "GAUGE",
      TxPackets => "COUNTER",
      RxPackets => "COUNTER",
      TxBytes => "COUNTER",
      RxBytes => "COUNTER",
      LossSyncCount => "GAUGE",
      RxSNR => "GAUGE",
      RxPower => "GAUGE",
      CableResistance => "GAUGE",
      CableAttenuation => "GAUGE",
    );
  }

  # update RRD
  $rrd->update
  (
    triaTxIFPower => $triaTxIFPower,
    triaRFPower => $triaRFPower,
    triaTemperature => $triaTemperature,
    TxPackets => $modemTxPackets,
    RxPackets => $modemRxPackets,
    TxBytes => $modemTxBytes,
    RxBytes => $modemRxBytes,
    LossSyncCount => $modemLossSyncCount,
    RxSNR => $modemRxSNR,
    RxPower => $modemRxPower,
    CableResistance => $modemCableResistance,
    CableAttenuation => $modemCableAttenuation,
  );

  # Only collect account usage information every 15 minutes
  my (undef, $minutes, undef) = localtime();
  if (($minutes % 15) eq 0) { getDataUsage($login, $password); }

  return;
}

sub getDataUsage
{
  my $login = shift;
  my $password = shift;

  my $baseurl = "https://myaccount.exede.net/wbisp/exede.com/";
  my $loginpage = "index.jsp";
  my $usagepage = "usage_bm.jsp";
  my $rrdfile = "usage.rrd";

  my $mech = WWW::Mechanize->new(autocheck => 1);
  $mech->get($baseurl);

  $mech->form_name("thisForm");
  $mech->field("uid", $login);
  $mech->field("userPassword", $password);

  $mech->submit_form(form_number => 1);

  # now that we're logged in, retrieve usage page
  $mech->get($baseurl.$usagepage);

  # This HTML stripping will not work in all cases - YMMV
  (my $text = $mech->content) =~ s/<.*?>/ /g;

  # extract data cap and current usage
  my ($cap) = $text =~ m/Your monthly data allowance\s+(.*?)\s+GB/s;
  my ($usage) = $text =~ m/Total usage:\s+(.*?)\s+GB/s;

  my $dt = localtime();
  print $dt, ",", time(), ",", $usage, ",", $cap, "\n";

  # if RRD file doesn't exist, create it
  my $rrd = RRD::Simple->new(file => $rrdfile);
  unless (-e $rrdfile)
  {
    $rrd->create
    (
      # data that comes from Exede web portal
      usage => "GAUGE",
      cap => "GAUGE",
    );

    # heartbeat for exget can be pretty irregulary due to website faults
    $rrd->heartbeat("usage", 1800);
    $rrd->heartbeat("cap", 1800);
  }

  # only update if we actually have data
  if ($usage ne "" and $cap ne "")
  {
    $rrd->update
    (
      usage => $usage,
      cap => $cap
    );
  }

  return;
}

sub graph
{
  $webdir = shift;

  my $rrd = RRD::Simple->new(file => "usage.rrd");
  my $rtn = $rrd->graph
  (
    sources => [ "usage", "cap" ],
    destination => $webdir,
    basename => "exede",
    title => "Excede Data Usage",
    vertical_label => "Gigabytes",
    timestamp => "rrd",
    interlaced => "",
    source_colors => { usage => "00ff00", cap => "ff0000" },
    source_labels => { usage => "Data Used", cap => "Data Cap" },
  );

  $rrd = RRD::Simple->new(file => "modem.rrd");
  $rtn = $rrd->graph
  (
    sources => [ "triaTxIFPower", "triaRFPower" ],
    destination => $webdir,
    basename => "tria-power",
    title => "Exede Tria Power",
    timestamp => "rrd",
    interlaced => "",
    vertical_label => "dBm",
    source_labels => { triaTxIFPower => "Tx IF Power",
                       triaRFPower => "RF Power" },
  );

  $rtn = $rrd->graph
  (
    sources => [ "triaTemperature" ],
    destination => $webdir,
    basename => "tria-temperature",
    title => "Exede Tria Temperature",
    timestamp => "rrd",
    interlaced => "",
    vertical_label => "degrees Celcius",
    source_labels => { triaTemperature => "Tria Temperature" },
  );

  $rtn = $rrd->graph
  (
    sources => [ "TxPackets", "RxPackets" ],
    destination => $webdir,
    basename => "surfbeam2-packets",
    title => "Exede Surfbeam 2 Packets",
    timestamp => "rrd",
    interlaced => "",
    vertical_label => "Packets/s",
    source_labels => { TxPackets => "Tx Packets", RxPackets => "Rx Packets" },
  );

  $rtn = $rrd->graph
  (
    sources => [ "TxBytes", "RxBytes" ],
    destination => $webdir,
    basename => "surfbeam2-bytes",
    title => "Exede Surfbeam 2 Bytes",
    timestamp => "rrd",
    interlaced => "",
    vertical_label => "Bytes/s",
    source_labels => { TxBytes => "Tx Bytes", RxBytes => "Rx Bytes" },
  );

  $rtn = $rrd->graph
  (
    sources => [ "LossSyncCount" ],
    destination => $webdir,
    basename => "surfbeam2-losssync",
    title => "Exede Surfbeam 2 Loss Sync",
    timestamp => "rrd",
    interlaced => "",
    vertical_label => "Count",
    source_labels => { LossSyncCount => "Loss of Sync" },
  );

  $rtn = $rrd->graph
  (
    sources => [ "RxSNR", "RxPower" ],
    destination => $webdir,
    basename => "surfbeam2-quality",
    title => "Exede Surfbeam 2 Signal Quality",
    timestamp => "rrd",
    interlaced => "",
    vertical_label => "dBm/dB",
    source_labels => { RxSNR => "Rx SNR", RxPower => "Rx Power" },
  );

  $rtn = $rrd->graph
  (
    sources => [ "CableResistance", "CableAttenuation" ],
    destination => $webdir,
    basename => "surfbeam2-cable",
    title => "Exede Surfbeam 2 Cable",
    timestamp => "rrd",
    interlaced => "",
    vertical_label => "Ohm/dB",
    source_labels => { CableResistance => "Resistance",
                       CableAttenuation => "Attenuation" },
  );

  return;
}

my ($webdir) = ("");

GetOptions
  (
    "help" => \$help,
    "login=s", => \$login,
    "password=s", => \$password,
    "collect", => \$collect,
    "graph", => \$graph,
    "web-dir=s", => \$web_dir,
  ) or pod2usage(2);

pod2usage(1) if $help;

if ($collect)
{
  if (!defined($login) or !defined($password))
    {
      print "ERROR: login and password is required for data collection.\n";
      pod2usage(1);
    }
  collect($login, $password)
}
graph($web_dir) if $graph;

exit 0;

__END__
=head1 exstats

sample - Using exstats

=head1 SYNOPSIS

exstats.pl [options]

 Options:
   --help                       brief help message
   --login <username>           username for login to Exede web portal
   --password <password>        password for login to Exede web portal
   --collect                    collect statistics
   --graph                      create graphs
   --web-dir                    location for graph output

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--user username>

Username to be used for login to Exede web portal.

=item B<--password password>

Password to be used for login to Exede web portal.

=item B<--collect>

Collect statistics from Surfbeam 2 modem / Tria and from Exede web portal.

=item B<--graph>

Graph collected statistics.

=back

=head1 DESCRIPTION

B<exstats.pl> will read collect data from Surfbeam 2 modems (including Tria
information), and data usage from the Exede website.  It stores this
information in a set of RRD files for later graphing.

Data usage is stored in 15 min increments.  All other data is stored in 5
min increments.

The script must be run frequently enough (from cron or another scheduler) to
generate a data point every hour for data usage or every two minutes for all
other data.  The recommended interval is one minute.  The script specifically
checks whether it's a fifteen minute interval before attempting to collect
data usage information from the web portal

=cut

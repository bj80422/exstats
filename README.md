exstats
=======

Exede modem, tria, and data usage statistics collector and visualizer

Collected elements:
  - Gigabytes of data used and data cap
  - Tria Power: Tx IF Power and RF Power
  - Tria Temperature
  - Data Sent/Received: Tx Packets, Tx Bytes, Rx Packets, Rx Bytes
  - Signal Quality: Rx SNR and Rx Power
  - Loss Sync Count
  - Cable Properties: Resistance and Attenuation


NOTE: Data usage and data cap collection is based on an Exede Evolution plan.
If you are not using Exede Evolution and wish to capture your SurfBeam 2
modem statistics anyway, you can comment out (hash signs at the beginning of
line) these two lines to skip data usage collection:
  # my (undef, $minutes, undef) = localtime();
  # if (($minutes % 15) eq 0) { getDataUsage($login, $password); }


Output
======

Some data usage information is output when the script collects information from
the Exede web portal.  This is in a CSV format and can be captured on STDOUT
for later import into Excel or another tool for manipulation.  The format is:
  Date,seconds since Epoch,data used, data cap


Web Page
=======

The web page uses basic javascript to update the graphs every 60 seconds.  This
should work either as a local file:/// URI or as a http:// https:// URL so long
as your javascript is enabled.

Dailey, weekly, monthly, and Annual graphs are available.


Scheduling
==========

The script is meant to be run every 1 minute.  An example cron entry might look
like (one shot, collect and update graphs):

* * * * * cd $HOME/exstats && $HOME/exstats/exstats.pl --collect --login MYLOGIN --password MYPASS --graph --web-dir=$HOME/exstats/web >> $HOME/exstats/exstats.log

If you wish to run the collection and graphing separete, you might run collection every minute and graphing every 15 minutes:
* * * * * cd $HOME/exstats && $HOME/exstats/exstats.pl --collect --login MYLOGIN --password MYPASS >> $HOME/exstats/exstats.log
*/15 * * * * cd $HOME/exstats && $HOME/exstats/exstats.pl --graph --web-dir=$HOME/exstats/web >> $HOME/exstats/exstats.log

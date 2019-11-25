#!/bin/bash

# Make sure curl is installed
clear
echo "Preparing background tools..."
apt-get -qq update
clear
echo "Preparing background tools... ... "
apt -qqy install curl jq > /dev/null 2>&1
clear

# Make sure dig and systemctl are installed
echo "Preparing background tools... ... ..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1
clear

# Make sure dig and systemctl are installed
echo "Preparing background tools... ... ... ..."

# CHARS is used for the loading animation further down.
CHARS="/-\|"
clear

MNID=""

echo "
 ___T_
| o o |
|__-__|
/| []|\\
()/|___|\()
|_|_|
/_|_\  ----------- MASTERNODE REFRESH v1 ----------------+
|                                                        |
|    This script will refresh the MN of your choice.     |
|                                                        |
| You must specify the ID# of the MN you wish to refresh |
|   E.g. If you want to refresh your initial MN, which   |
|        would have an ID# of '1', you enter '1',        |
|    but if you want to refresh your 3rd MN, which you   |
| have assigned a ID# of '3', you would enter '3' below. |
|                                                        |
|  If you used an a different naming convention than the |
|    sequential one described above, then follow that.   |
|                                                        |
| It's assumed that your MN(s) were installed under root |
|                                                        |::
+--------------------------------------------------------+::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::
"
sleep 3
echo ""
read -rp "Press Ctrl-C to abort or any other key to continue. " -n1 -s
clear

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi


while ! [ "$MNID" -eq "$MNID" ] 2> /dev/null
do
  MNarray[0]=0 #not used
  MNarray[1]=1 #MN1 (the original MN)
  echo "Enter the single digit Masternode ID# for the MN you want to refresh."
  echo "MNIDs for active masternodes detected on this VPS are:"
  #it is assumed that at least the initial masternode is installed
  echo "1"
  for (( i = 2; i < 10; i++ )); do
      FILE=/etc/systemd/system/guapcoin$i.service
      if test -f "$FILE"; then
          MNarray[$i]=1
          echo "$i"
      fi
  done
  echo ""
  read -e -p "(Please choose an ID# from the above list of detected MNs) : " MNID

  # Make sure that $MNID is a number
  if ! [ "$MNID" -eq "$MNID" ] 2> /dev/null
  then
      echo ""
      echo "Sorry, the ID# must be a single digit integer corresponding to the MNID you want to refresh."
      echo ""
      read -rp "Press any key to continue. " -n1 -s
      clear
      continue
  fi

echo ""
echo "Your chosen MNID is: $MNID"
#echo test printing MNarray[\$MIND]: ${MNarray["$MNID"]}
  # Make sure that the masternode ID chosen corresponds to a MN installed on this VPS. Check for a corresponding guapcoin directory
if ! [ "${MNarray["$MNID"]}" == "1" ] 2> /dev/null
then
  #statements
  echo "Sorry, the ID# you've chosen does not correspond to a MNID detected on this VPS."
  echo ""
  read -rp "Press any key to continue and chose another. " -n1 -s
  echo ""
  echo ""
  MNID=""
  clear
  continue
fi

done

if [[ "$MNID" == "1" ]]; then
  #statements
  MNID=""
  #echo " test guapcoin$MNID"
fi

USER=root
USERHOME=`eval echo "~$USER"`

echo "Stopping service for MNID #$MNID"

sudo systemctl stop guapcoin$MNID.service


clear
echo "Refreshing node, please wait."

sleep 5

rm -rf "$USERHOME/.guapcoin$MNID/blocks"
rm -rf "$USERHOME/.guapcoin$MNID/database"
rm -rf "$USERHOME/.guapcoin$MNID/chainstate"
rm -rf "$USERHOME/.guapcoin$MNID/peers.dat"

#backup the conf file just in case
cp "$USERHOME/.guapcoin$MNID/guapcoin.conf" "$USERHOME/.guapcoin$MNID/guapcoin.conf.backup"


sudo systemctl start guapcoin$MNID.service

TimeToWait=40
echo "Starting guapcoin$MNID.service, will check status in $TimeToWait seconds..."

for (( i = $TimeToWait; i > 0; i-- )); do
  clear
  echo "Starting guapcoin$MNID.service, will check status in $i seconds..."
  sleep 1
done

clear

if ! systemctl status guapcoin$MNID | grep -q "active (running)"; then
  echo "ERROR: Failed to start guapcoin$MNID.service. Please contact support."
  exit
fi

echo "Waiting for wallet to load..."
until su -c "/usr/local/bin/guapcoin-cli -conf=/root/.guapcoin$MNID/guapcoin.conf -datadir=/root/.guapcoin$MNID getinfo 2>/dev/null | grep -q \"version\"" "$USER"; do
  sleep 1;
done

clear

echo "Your masternode MN$MNID is syncing. Please wait for this process to finish."
echo "This can take a while. Do not close this window."
echo ""

until [ -n "$(/usr/local/bin/guapcoin-cli -conf=/root/.guapcoin$MNID/guapcoin.conf -datadir=/root/.guapcoin$MNID getconnectioncount 2>/dev/null)"  ]; do
  sleep 1
done

until su -c "/usr/local/bin/guapcoin-cli -conf=/root/.guapcoin$MNID/guapcoin.conf -datadir=/root/.guapcoin$MNID mnsync status 2>/dev/null | grep '\"IsBlockchainSynced\": true' > /dev/null" "$USER"; do
  echo -ne "Current block: $(su -c "/usr/local/bin/guapcoin-cli -conf=/root/.guapcoin$MNID/guapcoin.conf -datadir=/root/.guapcoin$MNID getblockcount" "$USER")\\r"
  sleep 1
done

clear

cat << EOL

Now, you need to start your masternode. Follow the steps below:
1) Please go to your desktop wallet
2) Click the Masternodes tab
3) Click 'Start all' at the bottom or select your newly refreshed node and click 'Start Alias'.
EOL

read -p "Press Enter to continue after you've done that. " -n1 -s

clear

sleep 1

echo "" && echo "Masternode$MNID refresh completed." && echo ""
echo "" && echo "Please see details for the refreshed Masternode$MNID below:"
echo -ne "$(su -c "/usr/local/bin/guapcoin-cli -conf=/root/.guapcoin$MNID/guapcoin.conf -datadir=/root/.guapcoin$MNID masternode status" "$USER")\\r"

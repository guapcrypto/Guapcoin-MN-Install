#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -a|--advanced)
    ADVANCED="y"
    shift
    ;;
    -n|--normal)
    ADVANCED="n"
    FAIL2BAN="y"
    UFW="y"
    BOOTSTRAP="y"
    shift
    ;;
    -i|--externalip)
    EXTERNALIP="$2"
    ARGUMENTIP="y"
    shift
    shift
    ;;
    -k|--privatekey)
    KEY="$2"
    shift
    shift
    ;;
    -f|--fail2ban)
    FAIL2BAN="y"
    shift
    ;;
    --no-fail2ban)
    FAIL2BAN="n"
    shift
    ;;
    -u|--ufw)
    UFW="y"
    shift
    ;;
    --no-ufw)
    UFW="n"
    shift
    ;;
    -b|--bootstrap)
    BOOTSTRAP="y"
    shift
    ;;
    --no-bootstrap)
    BOOTSTRAP="n"
    shift
    ;;
    -h|--help)
    cat << EOL

GUAP Masternode installer arguments:

    -n --normal               : Run installer in normal mode
    -a --advanced             : Run installer in advanced mode
    -i --externalip <address> : Public IP address of VPS
    -k --privatekey <key>     : Private key to use
    -f --fail2ban             : Install Fail2Ban
    --no-fail2ban             : Don't install Fail2Ban
    -u --ufw                  : Install UFW
    --no-ufw                  : Don't install UFW
    -b --bootstrap            : Sync node using Bootstrap
    --no-bootstrap            : Don't use Bootstrap
    -h --help                 : Display this help text.

EOL
    exit
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

clear

# Set these to change the version of guapcoin to install
TARBALLURL="https://github.com/guapcrypto/Guapcoin/releases/download/1.0.1/Guapcoin-1.0.1-Daemon-Ubuntu_16.04.tar.gz"
TARBALLNAME="Guapcoin-1.0.1-Daemon-Ubuntu_16.04.tar.gz"
BOOTSTRAPURL=""
BOOTSTRAPARCHIVE=""
BWKVERSION="1.0.1"

#!/bin/bash

# Check if we are root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

# Install tools for dig and systemctl
echo "Preparing installation..."
apt-get install git dnsutils systemd -y > /dev/null 2>&1

# Check for systemd
systemctl --version >/dev/null 2>&1 || { echo "systemd is required. Are you using Ubuntu 16.04?"  >&2; exit 1; }

# CHARS is used for the loading animation further down.
CHARS="/-\|"
if [ -z "$EXTERNALIP" ]; then
EXTERNALIP=`dig +short myip.opendns.com @resolver1.opendns.com`
fi
clear

if [ -z "$ADVANCED" ]; then
echo "

    ___T_
   | o o |
   |__-__|
   /| []|\\
 ()/|___|\()
    |_|_|
    /_|_\  ------- MASTERNODE INSTALLER v2 -------+
 |                                                  |
 | You can choose between two installation options: |::
 |              default and advanced.               |::
 |                                                  |::
 |  The advanced installation will install and run  |::
 |   the masternode under a non-root user. If you   |::
 |   don't know what that means, use the default    |::
 |               installation method.               |::
 |                                                  |::
 |  Otherwise, your masternode will not work, and   |::
 | the GUAP Team CANNOT assist you in repairing  |::
 |         it. You will have to start over.         |::
 |                                                  |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::

"

sleep 5
fi

if [ -z "$ADVANCED" ]; then
read -e -p "Use the Advanced Installation? [N/y] : " ADVANCED
fi

if [[ ("$ADVANCED" == "y" || "$ADVANCED" == "Y") ]]; then

USER=guapcoin

adduser $USER --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password > /dev/null

INSTALLERUSED="#Used Advanced Install"

echo "" && echo 'Added user "guapcoin"' && echo ""
sleep 1

else

USER=root
FAIL2BAN="y"
UFW="y"
BOOTSTRAP="n"
INSTALLERUSED="#Used Basic Install"
fi

USERHOME=`eval echo "~$USER"`

if [ -z "$ARGUMENTIP" ]; then
read -e -p "Server IP Address: " -i $EXTERNALIP -e IP
fi

if [ -z "$KEY" ]; then
read -e -p "Masternode Private Key (e.g. 7edfjLCUzGczZi3JQw8GHp434R9kNY33eFyMGeKRymkB56G4324h # THE KEY YOU GENERATED EARLIER) : " KEY
fi

if [ -z "$FAIL2BAN" ]; then
read -e -p "Install Fail2ban? [Y/n] : " FAIL2BAN
fi

if [ -z "$UFW" ]; then
read -e -p "Install UFW and configure ports? [Y/n] : " UFW
fi

if [ -z "$BOOTSTRAP" ]; then
read -e -p "Do you want to use our bootstrap file to speed the syncing process? [Y/n] : " BOOTSTRAP
fi

clear

# Generate random passwords
RPCUSER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
RPCPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

# update packages and upgrade Ubuntu
echo "Installing dependencies..."
apt-get -qq update
apt-get -qq upgrade
apt-get -qq autoremove
apt-get -qq install wget htop unzip
apt-get -qq install build-essential && apt-get -qq install libtool autotools-dev autoconf libevent-pthreads-2.0-5 automake && apt-get -qq install libssl-dev && apt-get -qq install libboost-all-dev && apt-get -qq install software-properties-common && add-apt-repository -y ppa:bitcoin/bitcoin && apt update && apt-get -qq install libdb4.8-dev && apt-get -qq install libdb4.8++-dev && apt-get -qq install libminiupnpc-dev && apt-get -qq install libqt4-dev libprotobuf-dev protobuf-compiler && apt-get -qq install libqrencode-dev && apt-get -qq install git && apt-get -qq install pkg-config && apt-get -qq install libzmq3-dev
apt-get -qq install aptitude
apt-get -qq install libevent-dev

# Install Fail2Ban
if [[ ("$FAIL2BAN" == "y" || "$FAIL2BAN" == "Y" || "$FAIL2BAN" == "") ]]; then
  aptitude -y -q install fail2ban
  service fail2ban restart
fi

# Install UFW
if [[ ("$UFW" == "y" || "$UFW" == "Y" || "$UFW" == "") ]]; then
  apt-get -qq install ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow ssh
  ufw allow 9633/tcp
  yes | ufw enable
fi

# Install GUAP daemon
wget $TARBALLURL
tar -xzvf $TARBALLNAME 
rm $TARBALLNAME
mv ./guapcoind /usr/local/bin
mv ./guapcoin-cli /usr/local/bin
mv ./guapcoin-tx /usr/local/bin
rm -rf $TARBALLNAME

# Create .guapcoin directory
mkdir $USERHOME/.guapcoin

# Install bootstrap file
if [[ ("$BOOTSTRAP" == "y" || "$BOOTSTRAP" == "Y" || "$BOOTSTRAP" == "") ]]; then
  echo "skipping"
fi

# Create guapcoin.conf
touch $USERHOME/.guapcoin/guapcoin.conf
cat > $USERHOME/.guapcoin/guapcoin.conf << EOL
${INSTALLERUSED}
rpcuser=${RPCUSER}
rpcpassword=${RPCPASSWORD}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
staking=1
logtimestamps=1
maxconnections=256
externalip=${IP}
bind=${IP}:9633
masternodeaddr=${IP}
masternodeprivkey=${KEY}
masternode=1
addnode=159.65.221.180
addnode=165.227.192.223
addnode=159.65.217.114
addnode=165.227.83.244
addnode=45.63.25.141
addnode=45.76.199.11
addnode=155.138.140.38
addnode=78.141.203.208
addnode=199.247.20.128
addnode=136.244.112.117
addnode=209.250.250.121
addnode=108.61.252.179
addnode=155.138.219.187
addnode=66.42.93.170
EOL
chmod 0600 $USERHOME/.guapcoin/guapcoin.conf
chown -R $USER:$USER $USERHOME/.guapcoin

sleep 1

cat > /etc/systemd/system/guapcoin.service << EOL
[Unit]
Description=guapcoind
After=network.target
[Service]
Type=forking
User=${USER}
WorkingDirectory=${USERHOME}
ExecStart=/usr/local/bin/guapcoind -conf=${USERHOME}/.guapcoin/guapcoin.conf -datadir=${USERHOME}/.guapcoin
ExecStop=/usr/local/bin/guapcoin-cli -conf=${USERHOME}/.guapcoin/guapcoin.conf -datadir=${USERHOME}/.guapcoin stop
Restart=on-abort
[Install]
WantedBy=multi-user.target
EOL
sudo systemctl enable guapcoin.service
sudo systemctl start guapcoin.service

clear

cat << EOL

Now, you need to start your masternode. Please go to your desktop wallet
Click the Masternodes tab
Click Start all at the bottom 
EOL

read -p "Press Enter to continue after you've done that. " -n1 -s

clear

echo "" && echo "Masternode setup completed." && echo ""
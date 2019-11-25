#!/bin/bash

#This script should be called with text file as an argument:
# e.g sudo /root/ChkGuapHoldingsv3.sh /root/file.text

#The text file should have the GUAP addresses you want to check the amounts for and a corresponding label for each address
#Format for the text should be:
#     Label1<space>GUAP Address1
#     Label2<space>GUAP Address2

#Make all variable available as environment variables
set -a

echo ""
echo "                   [GUAP Holdings Snaphot]                       "
echo "-----------------------------------------------------------------"

#Print timestamp in Day Date(MM-DD-YYYY) Time(HH:MMam) Timezone format
d=$(TZ=":US/Eastern" date +'%a %m-%d-%Y %I:%M%P EST')
echo "Timestamp : $d"
echo ""

#Create arrays to hold GUAP addresses and address labels from file
declare -a MNArray
declare -a MNLabelArray

#capture the external file
filename=$1

#Clean up the file, remove bash comments and empty lines (creates a backup before removal)
sed -i".bkup" 's/^#.*$//' $filename #remove comments
sed -i '/^$/d' $filename #remove empty lines

#While loop to read in each GUAP address and corresponding label
n=0
while read label address; do
# reading each line
MNLabelArray[$n]=$label
MNArray[$n]=$address
n=$((n+1))
done < $filename

echo ""


echo "[Label]      [Address]                                [Subtotal] "
echo "-----------------------------------------------------------------"

echo ""

#For loop to get the current amount of GUAP in each saved GUAP address and print out each address, with its label and its GUAP amount
n=0
for i in "${MNArray[@]}"
do

  parm="http://159.65.221.180:3001/ext/getbalance/$i"
  Addr[$n]=$(curl -s -X GET $parm)
  tempVar=${Addr[$n]}
  tempLabel=${MNLabelArray[$n]}
  echo "  $tempLabel        $i : $(python -c 'import os; print "{0:>14,.3f}".format(float(os.environ["tempVar"]))')"
  echo ""

  ((++n))
done

#Var to hold the total amount of GUAP from all saved GUAP addresses, and For loop to iterate through MNArray and calculate the total of all the addresses
MN_Total=0
n=0
#Add everything up
for i in "${Addr[@]}"
do
  tempVar=${Addr[$n]}

  MN_Total=$(python -c 'import os; print "{:>14.3f}".format((float(os.environ["MN_Total"]) + float(os.environ["tempVar"])))')

  ((++n))
done


#Get total current GUAP chain money supply
parm7="http://159.65.221.180:3001/ext/getmoneysupply"

GUAPTotal=$(curl -s -X GET $parm7)

#Get percentage of total GUAP money suppy held by the addressed evaluated
Perc=$(python -c 'import os; print "{:>13,.2f}".format((float(os.environ["MN_Total"]) / float(os.environ["GUAPTotal"]) * 100))')

#Print out total holding and total GUAP money supply
echo "-----------------------------------------------------------------"
echo "  Total GUAP Holdings                           : $(python -c 'import os; print "{0:>14,.3f}".format(float(os.environ["MN_Total"]))')"

echo "-----------------------------------------------------------------"
echo "-----------------------------------------------------------------"
echo ""
echo "Total GUAP Money Supply                         : $(python -c 'import os; print "{0:>14,.3f}".format(float(os.environ["GUAPTotal"]))')"

echo ""
#Get total number of GUAP masternodes and do some formating
parm8="http://159.65.221.180:3001/ext/getmasternodecount"
MNCount=$(curl -s -X GET $parm8)

#Removes random whitespace from beginning of MNCount
shopt -s extglob
MNCount=${MNCount##*( )}
shopt -u extglob
#right justify
MNCount=$(printf '%14s' $MNCount)

#Get percentage of total GUAP voting power
n=$((n-2))
#Perc2=$(python -c 'import os; print "{:>13,.0f}".format((float(os.environ["MN_Total"]) / float(os.environ["MNCount"]) * 100))')


#Get current block count/height
parm9="http://159.65.221.180:3001/api/getblockcount"
BlockHeight=$(curl -s -X GET $parm9)
BlockHeight=$(printf '%14s' $BlockHeight)

#Print out percentage of GUAP money supply, Masternode count, and GUAP chain block count/height
echo "Percentage of total GUAP Money Supply           : $Perc%"
echo ""
echo "Total number of GUAP masternodes                : $MNCount"
MNCount=$(python -c 'import os; print "{0:>14,.0f}".format(float(os.environ["MNCount"]))')
n=$(python -c 'import os; print "{0:>14,.0f}".format(float(os.environ["n"]))')
echo ""
Perc2=$(python -c 'import os; print "{:>13,.2f}".format((float(os.environ["n"]) / float(os.environ["MNCount"]) * 100))')

echo "Percentage of total GUAP Voting Power           : $Perc2%"
echo ""
echo "GUAP Chain Block Count                          : $BlockHeight"
echo ""

#Turn off environment variables
set +a

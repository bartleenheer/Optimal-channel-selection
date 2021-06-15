#!/bin/bash

usage() {
  echo "--Router: Usage: change-channel.sh -c CHANNEL -b BANDWIDTH [-t TIMEOUT]"
}

if [[ $# -lt 2 ]]; then
  echo "--Router: Invalid number of arguments"
  usage
  exit
fi

TIMEOUT=90

channel=44
bandwidth=20

while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
  case $1 in
  -t)
    shift
    TIMEOUT=$1
    ;;
  -h)
    usage
    exit
    ;;
  -c)
    shift
    channel=$1
    ;;
  -b)
    shift
    bandwidth=$1
    ;;
  esac
  shift
done
if [[ "$1" == '--' ]]; then shift; fi

echo "--Router: Changing to channel $channel and bandwidth $bandwidth"

(
  echo "$channel + $bandwidth (timeout $TIMEOUT):" >>test.txt
  echo "1" >>test.txt

  ip link set wlan0 down
  echo "2" >>test.txt
  iw dev wlan0 set channel "$channel" "HT$bandwidth"
  echo "3" >>test.txt
  ip link set wlan0 up
  echo "4" >>test.txt

  starttime=$(date +%s)
  while [[ -z $(iw dev wlan0 station dump) ]]; do
    if [[ $(date +%s) -gt $(($starttime + $TIMEOUT)) ]]; then
      echo "Timed out -> going back to 44 20">>test.txt
      ip link set wlan0 down
      iw dev wlan0 set channel "44" "HT20"
      ip link set wlan0 up
      echo "Successfully went back to 44 20">>test.txt
      exit
    fi
    sleep 0.5
  done
  echo "Device successfully reconnected">>test.txt

) &
disown %1

echo "--Router: when the user doesn't reconnect within $TIMEOUT s old settings will be reverted"

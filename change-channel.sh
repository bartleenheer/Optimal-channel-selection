#!/bin/bash

usage() {
    echo "Usage: change-channel.sh -c CHANNEL -b BANDWIDTH [-t TIMEOUT]"
}

if [[ $# -lt 2 ]]; then
    echo "Invalid number of arguments"
    usage
    exit
fi

TIMEOUT=60

channel=44
bandwidth=20

while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -t )
    shift;
    TIMEOUT=$1
    ;;
  -h )
    usage
    exit
    ;;
  -c )
    shift;
    channel=$1
    ;;
  -b )
    shift;
    bandwidth=$1
    ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

ip link set wlan0 down
iw dev wlan0 set channel "$channel" "HT$bandwidth"
ip link set wlan0 up

starttime=$(date +%s)
while [[ -z $(iw dev wlan0 station dump) ]]; do
    if [[ $(date +%s) -gt $(($starttime + $TIMEOUT)) ]]; then
        echo "Timeout reached, reverting back to channel 44 at 20MHz"
        ip link set wlan0 down
        iw dev wlan0 set channel "44" "HT20"
        ip link set wlan0 up
        exit
    fi
    sleep 0.1
done
echo "Device successfully reconnected"
#!/bin/bash

usage() {
  echo "--Router: Usage: change-channel.sh [-c CHANNEL] [-b BANDWIDTH] [-t TIMEOUT]"
}

TIMEOUT=90
DEFAULTCHANNEL=44
DEFAULTBANDWIDTH=20

channel=$DEFAULTCHANNEL
bandwidth=$DEFAULTBANDWIDTH

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

  ip link set wlan0 down
  iw dev wlan0 set channel "$channel" "HT$bandwidth"
  ip link set wlan0 up

  starttime=$(date +%s)
  while [[ -z $(iw dev wlan0 station dump) ]]; do
    if [[ $(date +%s) -gt $(($starttime + $TIMEOUT)) ]]; then
      ip link set wlan0 down
      iw dev wlan0 set channel "$DEFAULTCHANNEL" "HT$DEFAULTBANDWIDTH"
      ip link set wlan0 up
      exit
    fi
    sleep 0.5
  done

) &
disown %1

echo "--Router: when the user doesn't reconnect within $TIMEOUT s old settings will be reverted"

#!/bin/bash

CHANNELS=(34 36 38 40 42 44 46 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144 149 153 157 161 165)
BANDWIDTH=(20 40- 40+)
# CHANNELS=(112)
# BANDWIDTH=(20)

help() {
  echo "Usage: ./run.sh [-i IP] [-u USER] [-l LOGFILE] [-r RESULTFILE] [-v] [--keyfile KEYFILE] [-t TIMEOUT] [--skip-search] [--skip-optimize]"
}

IP="192.168.1.3"
USER="root"
LOGFILE="log.txt"
RESULTFILE="result.txt"
VERBOSE=false
KEYFILE=""
APNAME=$(nmcli -t -f active,ssid dev wifi | egrep '^yes' | cut -d\' -f2 | sed 's/yes://')
TIMEOUT=90
SEARCH=true
OPTIMIZE=true

# Checks optional arguments
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
  case $1 in
  -u)
    shift
    USER=$1
    ;;
  -i)
    shift
    IP=$1
    ;;
  -h)
    help
    exit
    ;;
  -v)
    VERBOSE=true
    ;;
  -l)
    shift
    LOGFILE=$1
    ;;
  -r)
    shift
    RESULTFILE=$1
    ;;
  --keyfile)
    shift
    KEYFILE=$1
    ;;
  -t)
    shift
    TIMEOUT=$1
    ;;
  --skip-search)
    SEARCH=false
    ;;
  --skip-optimize)
    OPTIMIZE=false
    ;;
  esac
  shift
done
if [[ "$1" == '--' ]]; then shift; fi

get_current_settings() {
  echo $(ssh -i "$KEYFILE" "$USER@$IP" "iw wlan0 info | grep channel | sed 's/channel //' | sed 's/(.*), width: //'")
}

send_packets() {
  local interval=$1
  local size=$(($2 - 8))
  echo "$interval $size" >>"$LOGFILE"
  local result=$(sudo ping -i "$interval" -c 100 -s "$size" "$IP" | sed -n '/--- .* ping statistics ---/,$p' | sed '1d' | sed 's/packets transmitted, //' | sed 's/received, //' | sed 's/packet loss, //' | sed 's/time //' | sed ':a;N;$!ba;s/\n/,/g' | sed 's%ms,rtt min/avg/max/mdev = % %' | sed 's/ ms//' | sed -r 's%/% %g')
  echo "$result" >>"$LOGFILE"
  echo "$result"
}

reconnect() {
  local starttime=$(date +%s)
  while [[ -n $(nmcli c up "$APNAME" 2>&1 | grep "Error") || $(nmcli -t -f active,ssid dev wifi | egrep '^yes' | cut -d\' -f2 | sed 's/yes://') -ne "$APNAME" ]]; do
    sleep 0.1
  done
  if [[ $(date +%s) -gt $(($starttime + $TIMEOUT)) ]]; then
    $VERBOSE && echo "Surpassed timeout ($TIMEOUT s), resetting to old settings" &>/dev/null
  fi
  echo "$(date +%s) - $starttime" | bc
  sleep 0.5
}

change_settings() {
  local channel=$1
  local bandwidth=$2
  $VERBOSE && echo "Ch:$channel bw:$bandwidth"
  local return=$(ssh -i "$KEYFILE" "$USER@$IP" "/root/change-channel.sh -c \"$channel\" -b \"$bandwidth\" -t \"$TIMEOUT\"")
  $VERBOSE && echo $return
  sleep 5
}

check_speed() {
  local channel=$1
  local bandwidth=$2
  echo "$channel $bandwidth" >>"$LOGFILE"
  echo "Now trying channel+bandwidth: $channel+$bandwidth"
  change_settings $channel $bandwidth
  $VERBOSE && echo "Trying to reconnect"
  local timetaken=$(reconnect)
  echo "$timetaken" >>"$LOGFILE"
  $VERBOSE && echo "Time taken to reconnect: $timetaken s"
  local result=$(get_current_settings)
  if [[ "$(echo "$result" | awk '{print $1}')" -eq "$channel" && "$(echo "$result" | awk '{print $2}')" -eq "$(echo "$bandwidth" | sed 's/+//' | sed 's/-//')" ]]; then
    local health=0.0
    for interval in 0.1 0.01 0.001; do
      for size in 10000 30000 60000; do
        $VERBOSE &&echo "Now pinging $interval $size"
        local result=$(send_packets $interval $size)
        $VERBOSE && echo "Ping results (transmitted, received, packet loss, time (ms), rtt min/avg/max/mdev): $result"
        local rtt=$(echo $result | awk '{print$7}')                                                                   # Obtain the average rtt from the results
        local packetLoss=$(echo $result | awk '{print$3}' | sed "s/%//" | awk '{print "scale=2; " $0 " / 100"}' | bc) # Convert percentage into floating point
        newhealth=$(echo "scale=5; $health + ($rtt * (1 + $packetLoss))" | bc)                                           # Calculate health with 4 decimals
        $VERBOSE && echo "The new health score is: $newhealth, by calculating $health (old health) + ($rtt (round trip time) * (1 + $packetLoss (packetloss))) = $newhealth"
        health=$newhealth
      done
    done
    echo "$health $channel $bandwidth ($timetaken)" >>"$RESULTFILE"
    echo "health: $health" >>"$LOGFILE"
  else
    $VERBOSE && echo "Channel and bandwidth do not match: local: $channel $bandwidth, router: $(echo "$result" | awk '{print $1}') $(echo "$result" | awk '{print $2}')"
  fi

  echo "" >>"$LOGFILE"
}

if $SEARCH; then
  echo "Started searching optimal channel and bandwidth combination"
  $VERBOSE && echo "Removing old logfile and resultfile"
  touch $LOGFILE
  touch $RESULTFILE
  rm $LOGFILE
  rm $RESULTFILE
  for bandwidth in "${BANDWIDTH[@]}"; do
    for channel in "${CHANNELS[@]}"; do
      check_speed $channel $bandwidth
    done
  done
  echo "Started searching optimal channel and bandwidth combination (results can be found in $RESULTFILE)"
fi

if $OPTIMIZE; then
  echo "Started optimizing"
  BEST=""
  while read line; do
    if [[ -z "$BEST" ]] || (( $(echo "$(echo "$line" | awk '{print $1}') < $(echo "$BEST" | awk '{print $1}')" | bc -l) )); then
      $VERBOSE && echo "Changing best from $BEST to $line"
      BEST="$line"
    fi
  done <"$RESULTFILE"
  $VERBOSE && echo "The final best is $BEST"
  channel=$(echo "$BEST" | awk '{print $2}')
  bandwidth=$(echo "$BEST" | awk '{print $3}')
  change_settings $channel $bandwidth
  timetaken=$(reconnect)
  $VERBOSE && current_settings=$(get_current_settings)
  $VERBOSE && echo "Time taken to reconnect: $timetaken s, new settings: channel: $(echo $current_settings | awk '{print $1}'), bandwidth: $(echo $current_settings | awk '{print $2}')"
  echo "Done optimizing"
fi
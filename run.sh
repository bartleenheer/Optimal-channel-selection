#!/bin/bash

CHANNELS=(34 36 38 40 42 44 46 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 144 149 153 157 161 165)
BANDWIDTH=(20 40- 40+)

help() {
    echo "Usage: ./run.sh [-i IP] [-u USER] [-l LOGFILE] [-r RESULTFILE] [-v] [--keyfile KEYFILE] [-t TIMEOUT]"
}

IP="192.168.1.3"
USER="root"
LOGFILE="log.txt"
RESULTFILE="result.txt"
VERBOSE=0
KEYFILE=""
APNAME=$(nmcli -t -f active,ssid dev wifi | egrep '^yes' | cut -d\' -f2 | sed 's/yes://')
TIMEOUT=60

# Checks optional arguments 
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do case $1 in
  -u )
    shift;
    USER=$1
    ;;
  -i )
    shift;
    IP=$1
    ;;
  -h )
    help
    exit
    ;;
  -v )
    VERBOSE=1
    ;;
  -l )
    shift;
    LOGFILE=$1
    ;;
  -r )
    shift;
    RESULTFILE=$1
    ;;
  --keyfile ) 
    shift;
    KEYFILE=$1
    ;;
  -t )
    shift;
    TIMEOUT=$1
    ;;
esac; shift; done
if [[ "$1" == '--' ]]; then shift; fi

# Sends ping commands
send_packets() {
    local interval=$1
    local size=$(($2-8))
    echo "$interval $size" >> "$LOGFILE"
    local result=$(sudo ping -i "$interval" -c 100 -s "$size" "$IP" | sed -n '/--- .* ping statistics ---/,$p' | sed '1d' | sed 's/packets transmitted, //' | sed 's/received, //' | sed 's/packet loss, //' | sed 's/time //' | sed ':a;N;$!ba;s/\n/,/g' | sed 's%ms,rtt min/avg/max/mdev = % %' | sed 's/ ms//' | sed -r 's%/% %g')
    echo "$result" >> "$LOGFILE"
    echo "$result"
}

reconnect() {
    local starttime=$(date +%s)
    while [[ $(nmcli c up "$APNAME") | grep "Error" ]]; do
        sleep 0.1
    done
    if [[ $(date +%s) -gt $(($starttime + $TIMEOUT)) ]]; then
        echo "error"
    fi
}

check_speed() {
    local channel=$1
    local bandwidth=$2
    echo "$channel $bandwidth" >> "$LOGFILE"
    echo "Now channel+bandwidth: $channel+$bandwidth"
    if [[ $(ssh -i "$KEYFILE" "$USER@$IP" "/root/change-channel.sh -c \"$channel\" -b \"HT$bandwidth\" -t \"$TIMEOUT\"" ) ]]; then
        echo "$channel $bandwidth doesn't work"
    else
        echo "Trying to reconnect"
        if [[ -z $(reconnect) ]]; then # Only when able to reconnect we try pinging
            local health=0.0
            for interval in 0.1 0.01 0.001; do
                for size in 10000 30000 60000; do
                    echo "Now pinging $interval $size"
                    local result=$(send_packets $interval $size)
                    local rtt=$(echo $result | awk '{print$7}') # Obtain the average rtt from the results
                    local packetLoss=$(echo $result | awk '{print$3}' | sed "s/%//" | awk '{print "scale=2; " $0 " / 100"}' | bc) # Convert percentage into floating point
                    health=$(echo "scale=5; $health + ($rtt * (1 + $packetLoss))" | bc) # Calculate health with 4 decimals
                    echo "$health"
                done
            done
            echo "$health $channel $bandwidth" >> "$RESULTFILE"
        else
            echo "Could not reconnect, trying different bandwidth + channel"
        fi
    fi

    echo "" >> "$LOGFILE"
}

rm log.txt
for channel in "${CHANNELS[@]}"; do
    for bandwidth in "${BANDWIDTH[@]}"; do
        check_speed $channel $bandwidth
    done
done
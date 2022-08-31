#!/bin/bash

if [[ $# -eq 0 ]]; then
    echo 'No arguments provided! Use -h for help.'
    exit 1
fi

# Define ISP gateways
gw_1=255.255.255.255
iface_1=eth0
gw_2=$(/sbin/ip route show | grep "ppp0 proto" | cut -d ' ' -f1)
iface_2=ppp0

company=BANANA

Help() {
    echo "Script to monitor and switch primary gateway. Use -s for Sana+ and -t for Tenet."
}

# Get the options
while getopts "hstane" option; do
    case $option in
    h) # display Help
        Help
        exit
        ;;
    s) # Set primary gateway to Sana
        primary_gw=$gw_1
        secondary_gw=$gw_2
        primary_iface=$iface_1
        secondary_iface=$iface_2
        primary_isp_name=Sana
        secondary_isp_name=TeNet
        ;;
    t) # Set primary gateway to TeNet
        primary_gw=$gw_2
        secondary_gw=$gw_1
        primary_iface=$iface_2
        secondary_iface=$iface_1
        primary_isp_name=TeNet
        secondary_isp_name=Sana
        ;;
    a) # systemd service hack
        /bin/true
        ;;
    n) # systemd service hack
        /bin/true
        ;;
    e) # systemd service hack
        /bin/true
        ;;
    \?)
        echo "Invalid option"
        exit 1
        ;;
    esac
done

sendstatus() {
    echo "$1" | mail -s "$2" test@example.com
}

add_nameservers() {
    echo "nameserver 8.8.8.8" >/etc/resolv.conf
    echo "nameserver 8.8.4.4" >>/etc/resolv.conf
}

# Clean up dangling route in case script is killed or fails
testhost=8.8.8.8
if [ "$(/sbin/ip route show | grep -c $testhost)" != 0 ]; then
    /sbin/ip route del $testhost
fi

# Switch default route to primary ISP immediately upon call so we don't have to wait
if /sbin/ip route add $testhost via "$primary_gw" dev $primary_iface; then
    if ping $testhost -c 1 -q -W 1; then
        /sbin/ip route delete default && /sbin/ip route add default via "$primary_gw" dev $primary_iface
        add_nameservers
    fi
    /sbin/ip route del $testhost via "$primary_gw" dev $primary_iface
fi

while true; do

    # check for 'route add' return code
    if /sbin/ip route add $testhost via "$primary_gw" dev $primary_iface; then
        # pinging test-host
        isalive=$(ping -c 40 -q $testhost | grep -oP '\d+(?=% packet loss)')
    else
        isalive=100
    fi

    # getting current default route
    curdef=$(/sbin/ip route show | grep default | awk '{ print $3 }')

    if [ "$curdef" = "$primary_gw" ]; then
        echo -n "Using primary ISP "
        if [ "$isalive" -le 20 ]; then
            echo "and it's OK! Do nothing..."
        else
            echo "and it's DEAD!"
            echo "Switching to backup"
            /sbin/ip route delete default &&
                /sbin/ip route add default via "$secondary_gw" dev $secondary_iface
            add_nameservers
            sendstatus "Switching to $secondary_isp_name" "$company - ISP switching to $secondary_isp_name, packet loss is $isalive percent"
        fi
    else
        echo -n "We are on $secondary_isp_name now "
        if [ "$isalive" -le 20 ]; then
            echo "and $primary_isp_name is OK!"
            echo "Switching back to $primary_isp_name."
            #/sbin/ifdown $primary_iface &&
            #/sbin/ifup $primary_iface &&
            /sbin/ip route delete default &&
                /sbin/ip route add default via "$primary_gw" dev $primary_iface
            add_nameservers
            sendstatus "Switching back to $primary_isp_name" "$company - ISP switching to $primary_isp_name"
        else
            echo "and $primary_isp_name is still DEAD! Preventive adding default route to $secondary_isp_name..."
            /sbin/ip route add default via "$primary_gw" dev $primary_iface >/dev/null 2>&1
        fi
    fi

    # Remove test-route
    /sbin/ip route del $testhost via "$primary_gw" dev $primary_iface

    # Good night
    sleep 120

done

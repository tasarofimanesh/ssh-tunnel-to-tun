#!/bin/bash

#------------------------------------------------
#Mark outgoing packets of ssh connection with an fwmark of 2

shh_ports=`cat /etc/ssh/sshd_config | grep Port | tr -d [:alpha:] | tr -d "#"`

function set_fwmark()
{
    cnt=$(iptables -t mangle -nvL OUTPUT | grep "tcp spt:$1 MARK set 0x2" | wc -l)
    if [ $cnt -eq 0 ]
    then
        iptables -t mangle -A OUTPUT -p tcp  --sport $1 -j MARK --set-mark 2
    fi
}

for p in $shh_ports 
do
    set_fwmark $p
done

#--------------------------------------------------
#Create a new table named ovpn2 in rt_tables

ovpn2_count=$(cat /etc/iproute2/rt_tables | grep ovpn2 | wc -l)
if [ $ovpn2_count -eq 0 ]
then
    echo "10 ovpn" >> /etc/iproute2/rt_tables
fi

#--------------------------------------------------
#route all packets with firewall mark of 2 to this table

ovpn2_lookup_count=$(ip rule show | grep "from all fwmark 0x2 lookup ovpn2" | wc -l)
if [ $ovpn2_lookup_count -eq 0 ]
then
    ip rule add from all fwmark 2 lookup ovpn2 > dev/null
fi

#---------------------------------------------------
#change default gateway of table ovpn2 so response packets of ssh connection 
# wont go through openvpn tunnel we create later

ovpn2_def_route_count=$(ip route show table ovpn2 2> /dev/null | grep "default via" | wc -l)
if [ $ovpn2_def_route_count -eq 0 ]
then
    ip route add default via $(ip route | grep "default via" | cut -d " " -f3) table ovpn2
fi 

#----------------------------------------------------
#install openvpn

openvpn_service_desc_linecount=$(service openvpn status 2> /dev/null | wc -l)
if [ $openvpn_service_desc_linecount -eq 0 ]
then
    apt install openvpn -y
fi

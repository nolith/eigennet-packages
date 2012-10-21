#!/bin/sh /etc/rc.common

<<COPYRIGHT

Copyright (C) 2010-2012 Gioacchino Mazzurco <gmazzurco89@gmail.com>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this file.  If not, see <http://www.gnu.org/licenses/>.

COPYRIGHT

START=95
STOP=10

CONF_DIR="/etc/config/"

config_load eigennet

config_get debugLevel general "debugLevel" 0

#[Doc]
#[Doc] Print mystring if mydebuglevel is greater or equal then debulLevel 
#[Doc]
#[Doc] usage: eigenDebug mydebuglevel mystring 
#[Doc]
#[Doc] example: eigenDebug 2 "setting autorized keys"
#[Doc]

eigenDebug()
{
	[ $1 -ge $debugLevel ] &&
	{
		echo "Debug: $@" >> /tmp/eigenlog
	}
}

#[Doc]
#[Doc] Reboot safely ( sync non volatile memory before reboot )
#[Doc]
#[Doc] usage: safe_reboot
#[Doc]
safe_reboot()
{
		sleep 1s
		sync
		sleep 2s
		reboot
}

#[Doc]
#[Doc] Del given uci interface from network file 
#[Doc]
#[Doc] usage:
#[Doc] del_interface uci_interface_name
#[Doc]
#[Doc] example:
#[Doc] del_interface lan0
#[Doc]

del_interface()
{
	uci del network.$1
}

#[Doc]
#[Doc] Del given uci wifi-iface interface from wireless file 
#[Doc]
#[Doc] usage:
#[Doc] del_wifi_iface uci_wifi-iface
#[Doc]
#[Doc] example:
#[Doc] del_wifi_iface wifiap0
#[Doc]

del_wifi_iface()
{
	uci del wireless.$1
}

#[Doc]
#[Doc] Return MAC of given interface
#[Doc]
#[Doc] usage:
#[Doc] get_mac ifname
#[Doc]
#[Doc] example:
#[Doc] get_mac eth0
#[Doc]

get_mac()
{
        ifname=${1}
        ifbase=$(echo $ifname | sed -e 's/[0-9]*$//')

        if [ $ifbase == "wifi" ]
                then
                        mac=$(ifconfig $ifname | sed -n 1p | awk '{print $5}' | cut -c-17 | sed -e 's/-/:/g')
                elif [ $ifbase == "radio" ] ; then
                                mac=$(cat /sys/class/ieee80211/$(echo ${ifname} | sed 's/radio/phy/g')/addresses)
                elif [ $ifbase == "phy" ] ; then
                                mac=$(cat /sys/class/ieee80211/${ifname}/addresses)
                else
                        mac=$(ifconfig $ifname | sed -n 1p | awk '{print $5}')
        fi

        echo $mac | tr '[a-z]' ['A-Z']
}

#[Doc]
#[Doc] Return given mac in ipv6 like format
#[Doc]
#[Doc] usage:
#[Doc] mac6ize mac_address
#[Doc]
#[Doc] example:
#[Doc] mac6ize ff:ff:ff:ff:ff:ff
#[Doc]

mac6ize()
{
        echo $1 | awk -F: '{print $1$2":"$3$4":"$5$6}' | tr '[a-z]' ['A-Z']
}

#[Doc]
#[Doc] Return physical interface list
#[Doc]
#[Doc] usage:
#[Doc] scan_devices
#[Doc]

scan_devices()
{
	eth=""
	radio=""
	wifi=""
	
	# Getting wired interfaces
	eth=$(cat /proc/net/dev | sed -n -e 's/:.*//' -e 's/[ /t]*//' -e '/^eth[0-9]$/p')

	# Getting ath9k interfaces
	if [ -e /lib/wifi/mac80211.sh ] && [ -e /sys/class/ieee80211/ ]
		then
			radio=$(ls /sys/class/ieee80211/ | sed -n -e '/^phy[0-9]$/p' | sed -e 's/^phy/radio/')
	fi

	# Getting madwifi interfaces
	if [ -e /lib/wifi/madwifi.sh ]
		then
			cd /proc/sys/dev/
			wifi=$(ls | grep wifi)
	else
		wifi=$(ls /sys/class/net/ | sed -n -e '/^wlan[0-9]/p')
	fi

	echo "${eth} ${radio} ${wifi}" | sed 's/ /\n/g' | sed '/^$/d'
}

configureNetwork()
{
	local ip4addr_lan	; config_get		ip4addr_lan		network		"ip4addr_lan"		"192.168.1.21"
	local netmask_lan	; config_get		netmask_lan		network		"netmask_lan"		"255.255.255.0"
	local ip6addr_lan	; config_get		ip6addr_lan		network		"ip6addr_lan"		"2001:4c00:893b:cab::123/64"
	local ip4addr_mesh	; config_get		ip4addr_mesh	network		"ip4addr_mesh"		"172.16.0.1"
	local netmask_mesh	; config_get		netmask_mesh	network		"netmask_mesh"		"255.255.0.0"
	local ip6addr_mesh	; config_get		ip6addr_mesh	network 	"ip6addr_mesh"		"2001:4c00:893b:1:cab::/128"
	local hs_enable		; config_get_bool	hs_enable		hotspot		"hs_enable"			0
	local ip4addr_hs	; config_get		ip4addr_hs		hotspot		"ip4addr_hs"		"192.168.10.1"
	local netmask_hs	; config_get		netmask_hs		hotspot 	"netmask_hs"		"255.255.255.0"
	local hsSSID		; config_get		hsSSID			hotspot 	"hsSSID"			"www.ninux.org"
	local hsMaxClients	; config_get		hsMaxClients	hotspot 	"hsMaxClients"		"50"
	local wan_set		; config_get_bool	wan_set			network 	"wan_set"			0
	local ip4_wan		; config_get		ip4_wan			network 	"ip4_wan"			"0.0.0.0"
	local wan_mask		; config_get		wan_mask		network 	"wan_mask"			"0.0.0.0"
	local hostName		; config_get		hostName		network 	"hostName"			"node_device"
	local resolvers		; config_get		resolvers		network 	"resolvers"			"8.8.8.8 2001:4860:4860::8888"
	local apMaxClients	; config_get		apMaxClients	wireless	 "apMaxClients"		"25"
	local wifi_mesh		; config_get_bool	wifi_mesh		wireless	 "wifi_mesh"		1
	local ath9k_mesh	; config_get_bool	ath9k_mesh		wireless	 "wifi_mesh"		1
	local madwifi_mesh	; config_get_bool	madwifi_mesh	wireless	 "wifi_mesh"		1
	local mesh_mode		; config_get		mesh_mode		wireless	 "mesh_mode"		"adhoc"
	local mac_sta		; config_get		mac_sta			wireless	 "station_mac"		"0"
	local tx_power		; config_get		tx_power		wireless	 "tx_power"			"10"
	local countrycode	; config_get		countrycode		wireless	 "countrycode"		"US"
	local mesh2channel	; config_get		mesh2channel	wireless	 "wifi_channel"		"1"
	local meshSSID		; config_get		meshSSID		wireless	 "meshSSID"			"mesh.ninux.org"
	local meshBSSID		; config_get		meshBSSID		wireless	 "meshBSSID"		"02:aa:bb:cc:dd:00"
	local meshMcastRate	; config_get		meshMcastRate	wireless	 "meshMcastRate"	""
	local ap_staSSID	; config_get		ap_staSSID		wireless	 "ap_staSSID"		"ninux.org"
	local ap_enable		; config_get_bool	ap_enable		wireless	 "ap_enable"		1
	local apSSID		; config_get		apSSID			wireless	 "apSSID"			"ap.ninux.org"
	local apKEY			; config_get		apKEY			wireless	 "apKEY"
	
	# Getting router model
	local model=$(cat /proc/cpuinfo |grep machine|awk '{print $4}')

	local TimeZone="CET-1CEST,M3.5.0,M10.5.0/3"
	uci set system.@system[0].hostname=$hostName
	uci set system.@system[0].timezone=$TimeZone
	uci del system.ntp
	uci set system.ntp=timeserver
	uci set system.ntp.enable_server=1
	uci set system.ntp.server=timeserver.ninux.org

	/etc/init.d/firewall disable
	/etc/init.d/olsrd disable
	rm -rf /etc/config/olsrd

	echo -e "$(cat /etc/sysctl.conf | grep -v net.ipv6.conf.all.autoconf) \n net.ipv6.conf.all.autoconf=0" > /etc/sysctl.conf

	rm -rf /etc/resolv.conf
	for dns in $resolvers
	do
		echo nameserver $dns >> /etc/resolv.conf
	done
	
	/etc/init.d/dnsmasq enable

	config_load wireless
	config_foreach del_wifi_iface wifi-iface

	config_load network
	config_foreach del_interface interface

	uci set network.loopback=interface
	uci set network.loopback.ifname=lo
	uci set network.loopback.proto=static
	uci set network.loopback.ipaddr="127.0.0.1"
	uci set network.loopback.netmask="255.0.0.0"
	uci set network.loopback.ip6addr="0::1/128"

	uci set network.lan=interface
	uci set network.lan.proto=static
	uci set network.lan.type=bridge
	uci set network.lan.ip6addr=$ip6addr_lan
	uci set network.lan.ipaddr=$ip4addr_lan
	uci set network.lan.netmask=$netmask_lan
	
	if [ $model = TL-WR741ND ]
		then
			[ $wan_set -eq 1 ] &&
			{
				uci set network.wan=interface
				uci set network.wan.ifname=eth1
				uci set network.wan.proto=static
				uci set network.wan.ipaddr=$ip4_wan
				uci set network.wan.netmask=$wan_mask
				uci set network.wan.dns=$resolvers
			}
			[ $wan_set -eq 0 ] &&
			{
				uci set network.wan=interface
				uci set network.wan.ifname=eth1
				uci set network.wan.proto=dhcp
			}
			uci add_list network.lan.ifname=eth0

	elif [ $model = TL-WR1043ND ]
		then
			[ $wan_set -eq 1 ] &&
			{
				uci set network.wan=interface
				uci set network.wan.ifname=eth0.2
				uci set network.wan.proto=static
				uci set network.wan.ipaddr=$ip4_wan
				uci set network.wan.netmask=$wan_mask
				uci set network.wan.dns=$resolvers
			}
			[ $wan_set -eq 0 ] &&
			{
				uci set network.wan=interface
				uci set network.wan.ifname=eth0.2
				uci set network.wan.proto=dhcp
			}
			uci add_list network.lan.ifname=eth0.1
	else
		uci add_list network.lan.ifname=eth0
	fi

	for device in $(scan_devices)
	do
		devtype=$(echo $device | sed -e 's/[0-9]*$//')
		devindex=$(echo $device | sed -e 's/.*\([0-9]\)/\1/')

		case $devtype in
			"wifi")
				uci set wireless.$device.disabled=0
				uci set wireless.$device.channel=$mesh2channel
				uci set wireless.$device.txpower=$tx_power
				uci set wireless.$device.country=$countrycode

				[ $madwifi_mesh -eq 1 ] &&
				{
					uci set wireless.mesh$device=wifi-iface
					uci set wireless.mesh$device.device=$device
					uci set wireless.mesh$device.network=nmesh$device
					uci set wireless.mesh$device.mode=$mesh_mode
					uci set wireless.mesh$device.encryption=none

					if [ $mesh_mode = adhoc ]
						then
						uci set wireless.mesh$device.bssid=$meshBSSID
						uci set wireless.mesh$device.ssid=$meshSSID
						uci set wireless.mesh$device.mcast_rate=$meshMcastRate

					elif [ $mesh_mode = sta ]
						then
						uci set wireless.mesh$device.bssid=$mac_sta
						uci set wireless.mesh$device.ssid=$ap_staSSID

					elif [ $mesh_mode = ap ]
						then
						uci set wireless.mesh$device.ssid=$ap_staSSID
					fi					
								
					uci set network.nmesh$device=interface
					uci set network.nmesh$device.proto=static
					uci set network.nmesh$device.ip6addr=$ip6addr_mesh
					uci set network.nmesh$device.ipaddr=$ip4addr_mesh
					uci set network.nmesh$device.netmask=$netmask_mesh
					ifname_mesh=nmesh$device
				}
				
				[ $ap_enable -eq 1 ] &&
				{
					uci set wireless.ap$device=wifi-iface
					uci set wireless.ap$device.device=$device
					uci set wireless.ap$device.network=lan
					uci set wireless.ap$device.mode=ap
					uci set wireless.ap$device.ssid=$apSSID

					[ ${#apKEY} -lt 8 ] &&
					{
						uci set wireless.ap$device.encryption=none
					} ||
					{
						uci set wireless.ap$device.encryption=psk
						uci set wireless.ap$device.key=$apKEY
					}
					uci set wireless.ap$device.maxassoc=$apMaxClients
				}

				[ $hs_enable -eq 1 ] &&
				{
					uci set wireless.hs$device=wifi-iface
					uci set wireless.hs$device.device=$device
					uci set wireless.hs$device.network=hot$device
					uci set wireless.hs$device.mode=ap
					uci set wireless.hs$device.ssid=$hsSSID
					uci set wireless.hs$device.encryption=none
					uci set wireless.hs$device.maxassoc=$hsMaxClients

					uci set network.hot$device=interface
					uci set network.hot$device.proto=static
					uci set network.hot$device.ipaddr=$ip4addr_hs
					uci set network.hot$device.netmask=$netmask_hs
					ifname_hs=hot$device
				}
			;;

			"radio")
				uci set wireless.$device.disabled=0
				uci set wireless.$device.channel=$mesh2channel
				uci set wireless.$device.txpower=$tx_power
				uci set wireless.$device.country=$countrycode ## Seems newer hardware doest permit change country

				[ $ath9k_mesh -eq 1 ] &&
				{
					uci set wireless.mesh$device=wifi-iface
					uci set wireless.mesh$device.device=$device
					uci set wireless.mesh$device.network=nmesh$device
					uci set wireless.mesh$device.mode=$mesh_mode
					uci set wireless.mesh$device.encryption=none

					if [ $mesh_mode = adhoc ]
						then
						uci set wireless.mesh$device.bssid=$meshBSSID
						uci set wireless.mesh$device.ssid=$meshSSID
						uci set wireless.mesh$device.mcast_rate=$meshMcastRate

					elif [ $mesh_mode = sta ]
						then
						uci set wireless.mesh$device.bssid=$mac_sta
						uci set wireless.mesh$device.ssid=$ap_staSSID

					elif [ $mesh_mode = ap ]
						then
						uci set wireless.mesh$device.ssid=$ap_staSSID
					fi					
										
					uci set network.nmesh$device=interface
					uci set network.nmesh$device.proto=static
					uci set network.nmesh$device.ip6addr=$ip6addr_mesh
					uci set network.nmesh$device.ipaddr=$ip4addr_mesh
					uci set network.nmesh$device.netmask=$netmask_mesh
					ifname_mesh=nmesh$device
				}
				
				[ $ap_enable -eq 1 ] &&
				{
					uci set wireless.ap$device=wifi-iface
					uci set wireless.ap$device.device=$device
					uci set wireless.ap$device.network=lan
					uci set wireless.ap$device.mode=ap
					uci set wireless.ap$device.ssid=$apSSID

					[ ${#apKEY} -lt 8 ] &&
					{
						uci set wireless.ap$device.encryption=none
					} ||
					{
						uci set wireless.ap$device.encryption=psk
						uci set wireless.ap$device.key=$apKEY
					}
					uci set wireless.ap$device.maxassoc=$apMaxClients
				}

				[ $hs_enable -eq 1 ] &&
				{
					uci set wireless.hs$device=wifi-iface
					uci set wireless.hs$device.device=$device
					uci set wireless.hs$device.network=hot$device
					uci set wireless.hs$device.mode=ap
					uci set wireless.hs$device.ssid=$hsSSID
					uci set wireless.hs$device.encryption=none
					uci set wireless.hs$device.maxassoc=$hsMaxClients

					uci set network.hot$device=interface
					uci set network.hot$device.proto=static
					uci set network.hot$device.ipaddr=$ip4addr_hs
					uci set network.hot$device.netmask=$netmask_hs
					ifname_hs=hot$device
				}
			;;
		esac
	done

	uci commit network
	uci commit wireless
	/etc/init.d/network restart
}

configureOlsrd4()
{
	local wifi_mesh		; config_get_bool	wifi_mesh		wireless	"wifi_mesh"			1
	local ip4addr_mesh	; config_get		ip4addr_mesh	network		"ip4addr_mesh"		"172.16.0.1"
	local ip4addr_lan	; config_get		ip4addr_lan		network		"ip4addr_lan"		"192.168.1.21"
	local netmask_lan	; config_get		netmask_lan		network		"netmask_lan"		"255.255.255.0"
	local olsrd_enable	; config_get_bool	olsrd_enable	olsrd		"enable"			0
	local supernode		; config_get_bool	supernode		olsrd		"supernode"			0
	local gw_enable		; config_get_bool	gw_enable		olsrd		"gw_enable"			0
	local gw=""
	local iface_mesh=$(ip -4 a s | grep "$ip4addr_mesh" | awk '{print $7}')
	local OLSRD4="/etc/config/olsrd4"
	local hna4=$(ipcalc.sh ${ip4addr_lan} ${netmask_lan} | grep NETWORK | sed 's/NETWORK=//')
	local hna4_full="${hna4} ${netmask_lan}"
	
	rm -rf /etc/init.d/olsrd4
	touch $OLSRD4
	chmod +x $OLSRD4

	[ $wifi_mesh -eq 1 ] &&
	{
		local iface_olsrd=$(echo '"'${iface_mesh}'"')
	}

	[ $olsrd_enable -eq 1 ] &&
	{
		[ $wifi_mesh -eq 1 ] && [ $supernode -eq 1 ] &&
		{
			local iface_olsrd=$(echo '"'${iface_mesh}'"' '"br-lan"')
		}

		[ $wifi_mesh -eq 0 ] && [ $supernode -eq 1 ] &&
		{
			local iface_olsrd=$(echo '"br-lan"')
		}

		[ $wifi_mesh -eq 1 ] && [ $supernode -eq 0 ] &&
		{
			local iface_olsrd=$(echo '"'${iface_mesh}'"')
		}
	}

		if [ $gw_enable -eq 1 ]
			then
				local gw="0.0.0.0 0.0.0.0"
			else
				local gw="#"
		fi

	cat > $OLSRD4 << EOF
#Automatically generated for Eigennet
DebugLevel  0
IpVersion 4

Pollrate  0.025
FIBMetric "flat"

# RtTable 111
# RtTableDefault 112

UseNiit no
SmartGateway no

Hna4
{
${hna4_full}
${gw}
}

#Hna6
#{
#}

UseHysteresis no
TcRedundancy  2
MprCoverage 7

LinkQualityLevel 2
LinkQualityAlgorithm    "etx_ff"
LinkQualityAging 0.05
LinkQualityFishEye  1

# Don't remove olsrd_txtinfo from this file
# as this plugin is used by the Webinterface
# to display the OLSR Info
LoadPlugin "olsrd_txtinfo.so.0.1"
{
   PlParam     "port"   "2006"
   PlParam     "Accept"   "127.0.0.1"
}

InterfaceDefaults {
   HelloInterval 3.0
   HelloValidityTime 125.0
   TcInterval 2.0
   TcValidityTime 500.0
   MidInterval 25.0
   MidValidityTime 500.0
   HnaInterval 10.0
   HnaValidityTime 125.0
}

Interface ${iface_olsrd}
{
    Mode "mesh"
}

EOF
		touch /etc/init.d/olsrd4
		chmod +x /etc/init.d/olsrd4
		echo "olsrd -f /etc/config/olsrd4 -d 0" > /etc/init.d/olsrd4
}

configureOlsrd6()
{
	local wifi_mesh		; config_get_bool	wifi_mesh		wireless	"wifi_mesh"			1
	local ip4addr_mesh	; config_get		ip4addr_mesh	network		"ip4addr_mesh"		"172.16.0.1"
	local ip6addr_lan	; config_get		ip6addr_lan		network		"ip6addr_lan"		"2001:4c00:893b:cab::123/64"
	local olsrd_enable	; config_get_bool	olsrd_enable	olsrd		"enable"			0
	local supernode		; config_get_bool	supernode		olsrd		"supernode"			0
	local iface_mesh=$(ip -4 a s | grep "$ip4addr_mesh" | awk '{print $7}')
	local lan6prefix=$(echo ${ip6addr_lan} | awk 'BEGIN { FS = "/" } ; { print $2 }')
	local hna6=$(echo ${ip6addr_lan} | awk 'BEGIN { FS = "::" } ; { print $1 }' | sed 's/$/::/')
	local OLSRD6="/etc/config/olsrd6"
	local hna6_full="${hna6} ${lan6prefix}"
	
	rm -rf /etc/init.d/olsrd6
	touch $OLSRD6
	chmod +x $OLSRD6

        [ $wifi_mesh -eq 1 ] &&
        {
                local iface_olsrd=$(echo '"'${iface_mesh}'"')
        }

	[ $olsrd_enable -eq 1 ] &&
	{
		[ $wifi_mesh -eq 1 ] && [ $supernode -eq 1 ] &&
		{
			local iface_olsrd=$(echo '"'${iface_mesh}'"' '"br-lan"')
		}

		[ $wifi_mesh -eq 0 ] && [ $supernode -eq 1 ] &&
		{
			local iface_olsrd=$(echo '"br-lan"')
		}

		[ $wifi_mesh -eq 1 ] && [ $supernode -eq 0 ] &&
		{
			local iface_olsrd=$(echo '"'${iface_mesh}'"')
		}
	}

	cat > $OLSRD6 << EOF
#Automatically generated for Eigennet
DebugLevel  0

IpVersion 6

Pollrate  0.025
FIBMetric "flat"
UseNiit no
SmartGateway no


Hna6
{
${hna6_full}
}

UseHysteresis no
TcRedundancy  2

MprCoverage 7

LinkQualityLevel 2
LinkQualityAlgorithm    "etx_ff"
LinkQualityAging 0.05
LinkQualityFishEye  1

LoadPlugin "olsrd_txtinfo.so.0.1"
{
   PlParam     "port"   "2007"
   PlParam     "Accept"   "::"
}

InterfaceDefaults {
   HelloInterval 3.0
   HelloValidityTime 125.0
   TcInterval 2.0
   TcValidityTime 500.0
   MidInterval 25.0
   MidValidityTime 500.0
   HnaInterval 10.0
   HnaValidityTime 125.0
}

Interface ${iface_olsrd}
{
    Mode "mesh"
    IPv6Multicast FF02::6D

}

EOF
		touch /etc/init.d/olsrd6
		echo "olsrd -f /etc/config/olsrd6 -d 0" > /etc/init.d/olsrd6
		chmod +x /etc/init.d/olsrd6
}

configureRadvd()
{
	local ip6addr_lan	; config_get		ip6addr_lan		network		"ip6addr_lan"		"2001:4c00:893b:cab::123/64"
	local lan6prefix=$(echo ${ip6addr_lan} | awk 'BEGIN { FS = "/" } ; { print $2 }')
	local hna6=$(echo ${ip6addr_lan} | awk 'BEGIN { FS = "::" } ; { print $1 }' | sed 's/$/::/')
	local radvd_prefix=$(echo ${hna6}/${lan6prefix})
	local dhcp_enable=$dhcp_enable          ; config_get_bool       dhcp_enable     network         "dhcp_enable"   "1"

	uci del radvd.@interface[0]
	uci del radvd.@prefix[0]
	uci del radvd.@rdnss[0]
	uci del radvd.@route[0]
	uci del radvd.@dnssl[0]

	uci add radvd interface
	uci add radvd prefix
	
	uci set radvd.@interface[0]=interface
	uci set radvd.@interface[0].interface=lan
	uci set radvd.@interface[0].AdvSendAdvert=1
	uci set radvd.@interface[0].AdvManagedFlag=1
	uci set radvd.@interface[0].AdvOtherConfigFlag=1
	uci set radvd.@interface[0].AdvLinkMTU=1280
	uci set radvd.@interface[0].ignore=0
	uci set radvd.@prefix[0]=prefix
	uci set radvd.@prefix[0].interface=lan
	uci set radvd.@prefix[0].prefix=${radvd_prefix}
	uci set radvd.@prefix[0].AdvOnLink=1
	uci set radvd.@prefix[0].AdvAutonomous=1
	uci set radvd.@prefix[0].AdvRouterAddr=1
	uci set radvd.@prefix[0].ignore=0

	uci commit radvd

	if [ $dhcp_enable -eq 1 ]
		then
			/etc/init.d/radvd enable
		else
			/etc/init.d/radvd disable
	fi
}

configureDhcp()
{
	local max_client=""
	local wifi_mesh		; config_get_bool	wifi_mesh		wireless	"wifi_mesh"			1
	local hs_enable		; config_get_bool	hs_enable		hotspot		"hs_enable"			0
	local apMaxClients	; config_get		apMaxClients	wireless	 "apMaxClients"		"25"
	local hsMaxClients	; config_get		hsMaxClients	hotspot 	"hsMaxClients"		"50"
	local dhcp_enable=$dhcp_enable		; config_get_bool	dhcp_enable	network		"dhcp_enable"	"1"
	local dhcp_lan_init=$dhcp_lan_init	; config_get		dhcp_lan_init	network		"dhcp_lan_init"	"10"
	local DHCP="/etc/config/dhcp"

	uci del dhcp.@dnsmasq[0]
	uci del dhcp.lan
	uci del dhcp.wan

	uci add dhcp dnsmasq

	uci set dhcp.@dnsmasq[0]=dnsmasq
	uci set dhcp.@dnsmasq[0].domainneeded=1
	uci set dhcp.@dnsmasq[0].boguspriv=1
	uci set dhcp.@dnsmasq[0].localise_queries=1
	uci set dhcp.@dnsmasq[0].rebind_protection=0
	uci set dhcp.@dnsmasq[0].local=/lan/
	uci set dhcp.@dnsmasq[0].domain=lan
	uci set dhcp.@dnsmasq[0].expandhosts=1
	uci set dhcp.@dnsmasq[0].authoritative=1
	uci set dhcp.@dnsmasq[0].readethers=1
	uci set dhcp.@dnsmasq[0].leasefile=/tmp/dhcp.leases
	uci set dhcp.@dnsmasq[0].resolvfile=/etc/resolv.conf

	uci commit dhcp
	
	[ $wifi_mesh -eq 1 ] &&
	{
		uci set dhcp.$ifname_mesh=dhcp
		uci set dhcp.$ifname_mesh.interface=$ifname_mesh
		uci set dhcp.$ifname_mesh.ignore=1
	}
	
	[ $hs_enable -eq 1 ] &&
	{
		uci set dhcp.$ifname_hs=dhcp
		uci set dhcp.$ifname_hs.interface=$ifname_hs
		uci set dhcp.$ifname_hs.leasetime=12h
		uci set dhcp.$ifname_hs.start=10
		uci set dhcp.$ifname_hs.limit=$hsMaxClients
	}

	[ $dhcp_enable -eq 1 ] &&
	{
		if [ -n $apMaxClients ]
			then
				local max_client=$(($apMaxClients+20))
			else
				local max_client=20
		fi

		uci set dhcp.lan=dhcp
		uci set dhcp.lan.interface=lan
		uci set dhcp.lan.start=${dhcp_lan_init}
		uci set dhcp.lan.limit=${max_client}
		uci set dhcp.lan.leasetime=12h
		uci set dhcp.lan.force=1
	}

	uci commit dhcp
	/etc/init.d/dnsmasq enable
}

configureSnmp()
{
	local wifi_mesh		; config_get_bool	wifi_mesh		wireless	"wifi_mesh"			1
	local snmpEnable	; config_get_bool	snmpEnable	snmp	"enable" 1
	local snmpContact	; config_get		snmpContact	snmp	"contact"	"contatti@ninux.org"
	local snmpLocation	; config_get		snmpLocation	snmp	"location"
	local hs_enable		; config_get_bool	hs_enable		hotspot		"hs_enable"			0

	uci del mini_snmpd.@mini_snmpd[0]
		
	uci add mini_snmpd mini_snmpd

	uci set mini_snmpd.@mini_snmpd[0]=mini_snmpd
	uci set mini_snmpd.@mini_snmpd[0].enabled=${snmpEnable}
	uci set mini_snmpd.@mini_snmpd[0].ipv6=${snmpEnable}
	uci set mini_snmpd.@mini_snmpd[0].community=public
	uci set mini_snmpd.@mini_snmpd[0].contact=${snmpContact}
	uci set mini_snmpd.@mini_snmpd[0].location=${snmpLocation}
	uci add_list mini_snmpd.@mini_snmpd[0].disks=/overlay
	uci add_list mini_snmpd.@mini_snmpd[0].disks=/tmp
	uci add_list mini_snmpd.@mini_snmpd[0].interfaces=br-lan

	[ $wifi_mesh -eq 1 ] && [ $hs_enable -eq 0 ] &&
	{
		uci del mini_snmpd.@mini_snmpd[0].interfaces
        uci add_list mini_snmpd.@mini_snmpd[0].interfaces=br-lan
        uci add_list mini_snmpd.@mini_snmpd[0].interfaces=${ifname_mesh}
	}

	[ $wifi_mesh -eq 0 ] && [ $hs_enable -eq 1 ] &&
	{
        uci del mini_snmpd.@mini_snmpd[0].interfaces
        uci add_list mini_snmpd.@mini_snmpd[0].interfaces=br-lan
        uci add_list mini_snmpd.@mini_snmpd[0].interfaces=${ifname_hs}
	}

	[ $wifi_mesh -eq 1 ] && [ $hs_enable -eq 1 ] &&
	{
		uci del mini_snmpd.@mini_snmpd[0].interfaces
        uci add_list mini_snmpd.@mini_snmpd[0].interfaces=br-lan
		uci add_list mini_snmpd.@mini_snmpd[0].interfaces=${ifname_hs}
        uci add_list mini_snmpd.@mini_snmpd[0].interfaces=${ifname_mesh}
	}

	uci commit mini_snmpd

	if [ $snmpEnable -eq 1 ]
		then
			/etc/init.d/mini_snmpd enable
		else
			/etc/init.d/mini_snmpd disable
	fi

}

configureSplash()
{
	local hs_enable		; config_get_bool	hs_enable		hotspot		"hs_enable"			0
	local ip4addr_hs	; config_get		ip4addr_hs		hotspot		"ip4addr_hs"		"192.168.10.1"
	local SPLASH=/etc/nodogsplash/nodogsplash.conf
	local iface_hs=$(ip -4 a s | grep "$ip4addr_hs" | awk '{print $7}')

	chmod a+x $SPLASH
	cat > $SPLASH << EOF
#Automatically generated for Eigennet
GatewayInterface ${iface_hs}
FirewallRuleSet authenticated-users {
#    FirewallRule allow all
	 FirewallRule deny all
    FirewallRule allow tcp port 20
    FirewallRule allow tcp port 21
    FirewallRule allow tcp port 22
    FirewallRule allow tcp port 25
    FirewallRule allow udp port 53	
    FirewallRule allow tcp port 53	
    FirewallRule allow udp port 67
    FirewallRule allow udp port 68
    FirewallRule allow udp port 69
    FirewallRule allow tcp port 80
    FirewallRule allow tcp port 110
    FirewallRule allow tcp port 143
    FirewallRule allow udp port 161
    FirewallRule allow udp port 162
    FirewallRule allow tcp port 443
    FirewallRule allow tcp port 993
    FirewallRule allow tcp port 993
    FirewallRule allow tcp port 5060
    FirewallRule allow udp port 5060
    FirewallRule allow tcp port 5800
    FirewallRule allow tcp port 5900
    FirewallRule allow tcp port 5222
    FirewallRule allow tcp port 8080

}
FirewallRuleSet preauthenticated-users {
    FirewallRule allow tcp port 53	
    FirewallRule allow udp port 53
    FirewallRule allow udp port 67
}
FirewallRuleSet users-to-router {
    FirewallRule allow udp port 53	
    FirewallRule allow tcp port 53	
    FirewallRule allow udp port 67
    FirewallRule allow tcp port 22
    FirewallRule allow tcp port 23
    FirewallRule allow tcp port 80
    FirewallRule allow tcp port 443
}

EOF

	if [ $hs_enable -eq 1 ]
		then
			/etc/init.d/nodogsplash enable
		else
			/etc/init.d/nodogsplash disable
	fi
}

configureUhttpd()
{
	local pointingEnabled           ; config_get_bool pointingEnabled       pointing         "enabled"                0
	local bwClientEnabled           ; config_get_bool bwClientEnabled       bwtestclient     "enabled"                0
	local httpInfoEnabled           ; config_get_bool httpInfoEnabled       httpinfo         "enabled"                0

	if [ $pointingEnabled -eq 0 ] && [ $bwClientEnabled -eq 0 ] && [ $httpInfoEnabled -eq 0 ]
		then
			/etc/init.d/uhttpd disable
		else
			/etc/init.d/uhttpd enable
			uci set      uhttpd.main.listen_http="0.0.0.0:80"
			uci add_list uhttpd.main.listen_http="[::]:80"
			#if there's no luci use index.html
			[ ! -e /www/index.html ] && cp /www/index-webui.html /www/index.html
	fi
}

configureHttpInfo()
{
	local httpInfoEnabled           ; config_get_bool httpInfoEnabled       httpinfo         "enabled"                0
	if [ $httpInfoEnabled eq 1 ]
		then
			chmod 777 /www/cgi-bin/getdBm.cgi
			chmod 777 /www/cgi-bin/ifstat.cgi
		else
			chmod 750 /www/cgi-bin/getdBm.cgi
			chmod 750 /www/cgi-bin/ifstat.cgi
	fi
}

configurePointing()
{
	local pointingEnabled           ; config_get_bool pointingEnabled       pointing         "enabled"                0

	[ $pointingEnabled -eq 1 ] && chmod 777 /www/cgi-bin/pointing.cgi
	[ $pointingEnabled -eq 0 ] && chmod 750 /www/cgi-bin/pointing.cgi
}

configureBWTestClient()
{
	local bwClientEnabled           ; config_get_bool bwClientEnabled       bwtestclient     "enabled"                0

	[ $bwClientEnabled -eq 1 ] && chmod 777 /www/cgi-bin/bwtclient.cgi && chmod 777 /www/cgi-bin/startbwt.cgi
	[ $bwClientEnabled -eq 0 ] && chmod 750 /www/cgi-bin/bwtclient.cgi && chmod 750 /www/cgi-bin/startbwt.cgi
}

configureDropbear()
{
	local sshEnabled                ; config_get_bool sshEnabled            sshserver         "enabled"               1
	local passwdAuth                ; config_get_bool passwdAuth            sshserver         "passwdAuth"            1
	local sshAuthorizedKeys         ; config_get      sshAuthorizedKeys     sshserver         "sshAuthorizedKeys"

	if [ $sshEnabled -eq 1 ]
		then
			/etc/init.d/dropbear enable
			echo "$sshAuthorizedKeys" > "/etc/dropbear/authorized_keys" 
			uci set dropbear.@dropbear[0].PasswordAuth=$passwdAuth
		else
			/etc/init.d/dropbear enable
	fi
}

configureGateway()
{
	local ip4_gw_lan	; config_get		ip4_gw_lan		network		"ip4_gw_lan"
	local wifi_mesh		; config_get_bool	wifi_mesh		wireless	"wifi_mesh"			1
	local ip4addr_hs	; config_get		ip4addr_hs		hotspot		"ip4addr_hs"		"192.168.10.1"
	local netmask_hs	; config_get		netmask_hs		hotspot 	"netmask_hs"		"255.255.255.0"
	local hs_enable		; config_get_bool	hs_enable		hotspot		"hs_enable"			0
	local olsrd_enable	; config_get_bool	olsrd_enable	olsrd		"enable"			0
	local gw_lan		; config_get_bool	gw_lan			network		"gw_lan"			0
	local ip_source=$(ipcalc.sh ${ip4addr_hs} ${netmask_hs} | grep NETWORK | sed 's/NETWORK=//')

	[ $olsrd_enable -eq 0 ] && [ $wifi_mesh -eq 0 ] || [ $gw_lan -eq 1 ] &&
	{
		uci set network.lan.gateway=$ip4_gw_lan
		uci commit network
	}
	
	[ $hs_enable -eq 1 ] &&
	{
		iptables -t nat -A POSTROUTING -s ${ip_source} -o br-lan -j MASQUERADE
	}
}

start()
{
	eigenDebug 0 "Starting"

	config_get bootmode general "bootmode" 1

	[ $bootmode -eq 0 ] &&
	{
		sleep 61s

		uci set eigennet.general.bootmode=1
		uci commit eigennet

		safe_reboot

		return 0
	}

	[ $bootmode -eq 1 ] &&
	{
		sleep 10s

		configureBWTestClient
		configureUhttpd
		configurePointing
		configureDropbear
		configureNetwork

		sleep 5s

		configureRadvd
		configureDhcp
		configureSnmp
		configureOlsrd4
		configureOlsrd6
		configureSplash

		uci set eigennet.general.bootmode=2

		uci commit eigennet

		safe_reboot

		return 0
	}

	[ $bootmode -ge 2 ] &&
	{
		local ip6addr_lan	; config_get		ip6addr_lan		network		"ip6addr_lan"		"2001:4c00:893b:cab::123/64"
		local olsrd_enable	; config_get_bool	olsrd_enable	olsrd		"enable"			0
		sysctl -w net.ipv6.conf.all.autoconf=0

		configureGateway

		/etc/init.d/network restart

		sleep 10s
##                                               
## temporary solution for ipv6 br-lan assignment         
##
		ip -6 a f scope global dev br-lan
		ip -6 a a ${ip6addr_lan} dev br-lan

		[ $olsrd_enable -eq 1 ] &&
		{
			/etc/init.d/olsrd4
			/etc/init.d/olsrd6
		}

		return 0
	}
}

stop()
{
	eigenDebug 0 "Stopping"
}

restart()
{
	stop
	sleep 2s
	start
}


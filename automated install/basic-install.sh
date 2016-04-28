#!/usr/bin/env bash

webInterfaceDir="/var/www/html/admin"


	# Check if /etc/dnsmasq.conf is from pihole.  If so replace with an original and install new in .d directory
	dnsFile1="/etc/dnsmasq.conf"
	dnsFile2="/etc/dnsmasq.conf.orig"
	dnsSearch="addn-hosts=/etc/pihole/gravity.list"
	defaultFile="/etc/.pihole/advanced/dnsmasq.conf.original"
	newFileToInstall="/etc/.pihole/advanced/01-pihole.conf"
	newFileFinalLocation="/etc/dnsmasq.d/01-pihole.conf"

	echo -n ":::    Copying 01-pihole.conf to /etc/dnsmasq.d/01-pihole.conf..."
	$SUDO cp $newFileToInstall $newFileFinalLocation
	echo " done."
	$SUDO sed -i "s/@INT@/$piholeInterface/" $newFileFinalLocation
	if [[ "$piholeDNS1" != "" ]]; then
		$SUDO sed -i "s/@DNS1@/$piholeDNS1/" $newFileFinalLocation
	else
		$SUDO sed -i '/^server=@DNS1@/d' $newFileFinalLocation
	fi
	if [[ "$piholeDNS2" != "" ]]; then
		$SUDO sed -i "s/@DNS2@/$piholeDNS2/" $newFileFinalLocation
	else
		$SUDO sed -i '/^server=@DNS2@/d' $newFileFinalLocation
	fi
}


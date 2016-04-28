#!/usr/bin/env bash
# Pi-hole: A black hole for Internet advertisements
# (c) 2015, 2016 by Jacob Salmela
# Network-wide ad blocking via your Raspberry Pi
# http://pi-hole.net
# Installs Pi-hole
#
# Pi-hole is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.

# pi-hole.net/donate
#
# Install with this command (from your Pi):
#
# curl -L install.pi-hole.net | bash


######## VARIABLES #########

tmpLog=/tmp/pihole-install.log
instalLogLoc=/etc/pihole/install.log

webInterfaceGitUrl="https://github.com/pi-hole/AdminLTE.git"
webInterfaceDir="/var/www/html/admin"
piholeGitUrl="https://github.com/pi-hole/pi-hole.git"
piholeFilesDir="/etc/.pihole"

dhcpcdFile=/etc/dhcpcd.conf


cleanupIPv6() {
	# Removes IPv6 indicator file if we are not using IPv6
	if [ -f "/etc/pihole/.useIPv6" ] && [ ! "$useIPv6" ]; then
		rm /etc/pihole/.useIPv6
	fi
}

touch /etc/pihole/.useIPv6
#set dhcpcd.conf



function valid_ip()
{
	local  ip=$1
	local  stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		ip=($ip)
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
		&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi
	return $stat
}
	piholeDNS1="8.8.8.8"
	piholeDNS2="8.8.4.4"

versionCheckDNSmasq(){
	# Check if /etc/dnsmasq.conf is from pihole.  If so replace with an original and install new in .d directory
	dnsFile1="/etc/dnsmasq.conf"
	dnsFile2="/etc/dnsmasq.conf.orig"
	dnsSearch="addn-hosts=/etc/pihole/gravity.list"
	defaultFile="/etc/.pihole/advanced/dnsmasq.conf.original"
	newFileToInstall="/etc/.pihole/advanced/01-pihole.conf"
	newFileFinalLocation="/etc/dnsmasq.d/01-pihole.conf"


	if [ -f $dnsFile1 ]; then
		echo -n ":::    Existing dnsmasq.conf found..."
		if grep -q $dnsSearch $dnsFile1; then
			echo " it is from a previous pi-hole install."
			echo -n ":::    Backing up dnsmasq.conf to dnsmasq.conf.orig..."
			$SUDO mv -f $dnsFile1 $dnsFile2
			echo " done."
			echo -n ":::    Restoring default dnsmasq.conf..."
			$SUDO cp $defaultFile $dnsFile1
			echo " done."
		else
			echo " it is not a pi-hole file, leaving alone!"
		fi
	else
		echo -n ":::    No dnsmasq.conf found.. restoring default dnsmasq.conf..."
		$SUDO cp $defaultFile $dnsFile1
		echo " done."
	fi

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

installScripts() {
	# Install the scripts from /etc/.pihole to their various locations
	$SUDO echo ":::"
	$SUDO echo -n "::: Installing scripts to /opt/pihole..."
	if [ ! -d /opt/pihole ]; then
		$SUDO mkdir /opt/pihole
		$SUDO chown "$USER":root /opt/pihole
		$SUDO chmod u+srwx /opt/pihole
	fi
	$SUDO chmod 755 /opt/pihole/{gravity,chronometer,whitelist,blacklist,piholeLogFlush,updateDashboard,uninstall,setupLCD}.sh
	$SUDO cp /etc/.pihole/pihole /usr/local/bin/pihole
	$SUDO chmod 755 /usr/local/bin/pihole
	$SUDO cp /etc/.pihole/advanced/bash-completion/pihole /etc/bash_completion.d/pihole
	. /etc/bash_completion.d/pihole

	#Tidy up /usr/local/bin directory if installing over previous install.
	oldFiles=( gravity chronometer whitelist blacklist piholeLogFlush updateDashboard uninstall setupLCD piholeDebug)
	for i in "${oldFiles[@]}"; do
		if [ -f "/usr/local/bin/$i.sh" ]; then
			$SUDO rm /usr/local/bin/"$i".sh
		fi
	done

	$SUDO echo " done."
}

installConfigs() {
	# Install the configs from /etc/.pihole to their various locations
	$SUDO echo ":::"
	$SUDO echo "::: Installing configs..."
	versionCheckDNSmasq
	if [ ! -d "/etc/lighttpd" ]; then
		$SUDO mkdir /etc/lighttpd
		$SUDO chown "$USER":root /etc/lighttpd
		$SUDO mv /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf.orig
	fi
	$SUDO cp /etc/.pihole/advanced/lighttpd.conf /etc/lighttpd/lighttpd.conf
}

checkForDependencies() {
	#Running apt-get update/upgrade with minimal output can cause some issues with
	#requiring user input (e.g password for phpmyadmin see #218)
	#We'll change the logic up here, to check to see if there are any updates availible and
	# if so, advise the user to run apt-get update/upgrade at their own discretion
	#Check to see if apt-get update has already been run today
	# it needs to have been run at least once on new installs!

	timestamp=$(stat -c %Y /var/cache/apt/)
	timestampAsDate=$(date -d @"$timestamp" "+%b %e")
	today=$(date "+%b %e")

	if [ ! "$today" == "$timestampAsDate" ]; then
		#update package lists
		echo ":::"
		echo -n "::: apt-get update has not been run today. Running now..."
		$SUDO apt-get -qq update & spinner $!
		echo " done!"
	fi
	echo ":::"
	echo -n "::: Checking apt-get for upgraded packages...."
    updatesToInstall=$($SUDO apt-get -s -o Debug::NoLocking=true upgrade | grep -c ^Inst)
    echo " done!"
    echo ":::"
    if [[ $updatesToInstall -eq "0" ]]; then
		echo "::: Your pi is up to date! Continuing with pi-hole installation..."
    else
		echo "::: There are $updatesToInstall updates availible for your pi!"
		echo "::: We recommend you run 'sudo apt-get upgrade' after installing Pi-Hole! "
		echo ":::"
    fi
    echo ":::"
    echo "::: Checking dependencies:"

  dependencies=( dnsutils bc toilet figlet dnsmasq lighttpd php5-common php5-cgi php5 git curl unzip wget )
	for i in "${dependencies[@]}"; do
		echo -n ":::    Checking for $i..."
		if [ "$(dpkg-query -W -f='${Status}' "$i" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
			echo -n " Not found! Installing...."
			$SUDO apt-get -y -qq install "$i" > /dev/null & spinner $!
			echo " done!"
		else
			echo " already installed!"
		fi
	done
}

CreateLogFile() {
	# Create logfiles if necessary
	echo ":::"
	$SUDO  echo -n "::: Creating log file and changing owner to dnsmasq..."
	if [ ! -f /var/log/pihole.log ]; then
		$SUDO touch /var/log/pihole.log
		$SUDO chmod 644 /var/log/pihole.log
		$SUDO chown dnsmasq:root /var/log/pihole.log
		$SUDO echo " done!"
	else
		$SUDO  echo " already exists!"
	fi
}

installPiholeWeb() {
	# Install the web interface
	$SUDO echo ":::"
	$SUDO echo -n "::: Installing pihole custom index page..."
	if [ -d "/var/www/html/pihole" ]; then
		$SUDO echo " Existing page detected, not overwriting"
	else
		$SUDO mkdir /var/www/html/pihole
		if [ -f /var/www/html/index.lighttpd.html ]; then
			$SUDO mv /var/www/html/index.lighttpd.html /var/www/html/index.lighttpd.orig
		else
			printf "\n:::\tNo default index.lighttpd.html file found... not backing up"
		fi
		$SUDO cp /etc/.pihole/advanced/index.* /var/www/html/pihole/.
		$SUDO echo " done!"
	fi
}

 echo -n "::: Installing latest Cron script..."
 cp /etc/.pihole/advanced/pihole.cron /etc/cron.d/pihole


runGravity() {
	# Rub gravity.sh to build blacklists
	$SUDO echo ":::"
	$SUDO echo "::: Preparing to run gravity.sh to refresh hosts..."
	if ls /etc/pihole/list* 1> /dev/null 2>&1; then
		echo "::: Cleaning up previous install (preserving whitelist/blacklist)"
		$SUDO rm /etc/pihole/list.*
	fi
	echo "::: Running gravity.sh"
	$SUDO /opt/pihole/gravity.sh
}

 useradd -r -s /usr/sbin/nologin pihole
installPihole() {
	# Install base files and web interface
	checkForDependencies # done
	stopServices
	setUser
	$SUDO mkdir -p /etc/pihole/
	if [ ! -d "/var/www/html" ]; then
		$SUDO mkdir -p /var/www/html
	fi
	$SUDO chown www-data:www-data /var/www/html
	$SUDO chmod 775 /var/www/html
	$SUDO usermod -a -G www-data pihole
	$SUDO lighty-enable-mod fastcgi fastcgi-php > /dev/null

	getGitFiles
	installScripts
	installConfigs
	CreateLogFile
	installPiholeWeb
	installCron
	runGravity
}

######## SCRIPT ############
# Start the installer
$SUDO mkdir -p /etc/pihole/

# Let the user decide if they want to block ads over IPv4 and/or IPv6
use4andor6

# Decide what upstream DNS Servers to use
setDNS

# Install and log everything to a file
installPihole | tee $tmpLog

# Move the log file into /etc/pihole for storage
$SUDO mv $tmpLog $instalLogLoc

echo " done."


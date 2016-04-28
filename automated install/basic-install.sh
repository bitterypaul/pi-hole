#!/usr/bin/env bash

tmpLog=/tmp/pihole-install.log
instalLogLoc=/etc/pihole/install.log

webInterfaceGitUrl="https://github.com/pi-hole/AdminLTE.git"
webInterfaceDir="/var/www/html/admin"
piholeGitUrl="https://github.com/pi-hole/pi-hole.git"
piholeFilesDir="/etc/.pihole"

dhcpcdFile=/etc/dhcpcd.conf


touch /etc/pihole/.useIPv6
#set dhcpcd.conf

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
cp pihole /usr/local/bin/pihole
chmod 755 /usr/local/bin/pihole



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

#installPiholeWeb

mkdir /var/www/html/pihole
cp /etc/.pihole/advanced/index.* /var/www/html/pihole/.


 echo -n "::: Installing latest Cron script..."
 cp /etc/.pihole/advanced/pihole.cron /etc/cron.d/pihole

sh /opt/pihole/gravity.sh

 useradd -r -s /usr/sbin/nologin pihole
installPihole()
	mkdir -p /etc/pihole/
	mkdir -p /var/www/html
	chown www-data:www-data /var/www/html
	chmod 775 /var/www/html
	usermod -a -G www-data pihole
	lighty-enable-mod fastcgi fastcgi-php > /dev/null


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


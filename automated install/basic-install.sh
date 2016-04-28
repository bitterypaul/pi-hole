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

use4andor6() {
	# Let use select IPv4 and/or IPv6
	cmd=(whiptail --separate-output --checklist "Select Protocols (press space to select)" $r $c 2)
	options=(IPv4 "Block ads over IPv4" on
	IPv6 "Block ads over IPv6" off)
	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	if [[ $? = 0 ]];then
		for choice in $choices
		do
			case $choice in
			IPv4  )   useIPv4=true;;
			IPv6  )   useIPv6=true;;
			esac
		done

		if [ $useIPv4 ] && [ ! $useIPv6 ]; then
			getStaticIPv4Settings
			setStaticIPv4
			echo "::: Using IPv4 on $IPv4addr"
			echo "::: IPv6 will NOT be used."
		fi
		if [ ! $useIPv4 ] && [ $useIPv6 ]; then
			useIPv6dialog
			echo "::: IPv4 will NOT be used."
			echo "::: Using IPv6 on $piholeIPv6"
		fi
		if [ $useIPv4 ] && [  $useIPv6 ]; then
			getStaticIPv4Settings
			setStaticIPv4
			useIPv6dialog
			echo "::: Using IPv4 on $IPv4addr"
			echo "::: Using IPv6 on $piholeIPv6"
		fi
		if [ ! $useIPv4 ] && [ ! $useIPv6 ]; then
			echo "::: Cannot continue, neither IPv4 or IPv6 selected"
			echo "::: Exiting"
			exit 1
		fi
		cleanupIPv6
	else
		echo "::: Cancel selected. Exiting..."
		exit 1
	fi
}

useIPv6dialog() {
	# Show the IPv6 address used for blocking
	piholeIPv6=$(ip -6 route get 2001:4860:4860::8888 | awk -F " " '{ for(i=1;i<=NF;i++) if ($i == "src") print $(i+1) }')
	whiptail --msgbox --backtitle "IPv6..." --title "IPv6 Supported" "$piholeIPv6 will be used to block ads." $r $c

	$SUDO touch /etc/pihole/.useIPv6
}

getStaticIPv4Settings() {
	# Ask if the user wants to use DHCP settings as their static IP
	if (whiptail --backtitle "Calibrating network interface" --title "Static IP Address" --yesno "Do you want to use your current network settings as a static address?
					IP address:    $IPv4addr
					Gateway:       $IPv4gw" $r $c) then
		# If they choose yes, let the user know that the IP address will not be available via DHCP and may cause a conflict.
		whiptail --msgbox --backtitle "IP information" --title "FYI: IP Conflict" "It is possible your router could still try to assign this IP to a device, which would cause a conflict.  But in most cases the router is smart enough to not do that.
If you are worried, either manually set the address, or modify the DHCP reservation pool so it does not include the IP you want.
It is also possible to use a DHCP reservation, but if you are going to do that, you might as well set a static address." $r $c
		# Nothing else to do since the variables are already set above
	else
		# Otherwise, we need to ask the user to input their desired settings.
		# Start by getting the IPv4 address (pre-filling it with info gathered from DHCP)
		# Start a loop to let the user enter their information with the chance to go back and edit it if necessary
		until [[ $ipSettingsCorrect = True ]]
		do
			# Ask for the IPv4 address
			IPv4addr=$(whiptail --backtitle "Calibrating network interface" --title "IPv4 address" --inputbox "Enter your desired IPv4 address" $r $c "$IPv4addr" 3>&1 1>&2 2>&3)
			if [[ $? = 0 ]];then
			echo "::: Your static IPv4 address:    $IPv4addr"
			# Ask for the gateway
			IPv4gw=$(whiptail --backtitle "Calibrating network interface" --title "IPv4 gateway (router)" --inputbox "Enter your desired IPv4 default gateway" $r $c "$IPv4gw" 3>&1 1>&2 2>&3)
			if [[ $? = 0 ]];then
				echo "::: Your static IPv4 gateway:    $IPv4gw"
				# Give the user a chance to review their settings before moving on
				if (whiptail --backtitle "Calibrating network interface" --title "Static IP Address" --yesno "Are these settings correct?
					IP address:    $IPv4addr
					Gateway:       $IPv4gw" $r $c)then
					# If the settings are correct, then we need to set the piholeIP
					# Saving it to a temporary file us to retrieve it later when we run the gravity.sh script
					echo "${IPv4addr%/*}" > /tmp/piholeIP
					echo "$piholeInterface" > /tmp/piholeINT
					# After that's done, the loop ends and we move on
					ipSettingsCorrect=True
				else
					# If the settings are wrong, the loop continues
					ipSettingsCorrect=False
				fi
			else
				# Cancelling gateway settings window
				ipSettingsCorrect=False
				echo "::: Cancel selected. Exiting..."
				exit 1
			fi
		else
			# Cancelling IPv4 settings window
			ipSettingsCorrect=False
			echo "::: Cancel selected. Exiting..."
			exit 1
		fi
		done
		# End the if statement for DHCP vs. static
	fi
}

#set dhcpcd.conf


setStaticIPv4() {
	# Tries to set the IPv4 address
	if grep -q "$IPv4addr" $dhcpcdFile; then
		# address already set, noop
		:
	else
		setDHCPCD
		$SUDO ip addr replace dev "$piholeInterface" "$IPv4addr"
		echo ":::"
		echo "::: Setting IP to $IPv4addr.  You may need to restart after the install is complete."
		echo ":::"
	fi
}

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
	$SUDO cp /etc/.pihole/gravity.sh /opt/pihole/gravity.sh
	$SUDO cp /etc/.pihole/advanced/Scripts/chronometer.sh /opt/pihole/chronometer.sh
	$SUDO cp /etc/.pihole/advanced/Scripts/whitelist.sh /opt/pihole/whitelist.sh
	$SUDO cp /etc/.pihole/advanced/Scripts/blacklist.sh /opt/pihole/blacklist.sh
	$SUDO cp /etc/.pihole/advanced/Scripts/piholeDebug.sh /opt/pihole/piholeDebug.sh
	$SUDO cp /etc/.pihole/advanced/Scripts/piholeLogFlush.sh /opt/pihole/piholeLogFlush.sh
	$SUDO cp /etc/.pihole/advanced/Scripts/updateDashboard.sh /opt/pihole/updateDashboard.sh
	$SUDO cp /etc/.pihole/automated\ install/uninstall.sh /opt/pihole/uninstall.sh
	$SUDO cp /etc/.pihole/advanced/Scripts/setupLCD.sh /opt/pihole/setupLCD.sh
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

stopServices() {
	# Stop dnsmasq and lighttpd
	$SUDO echo ":::"
	$SUDO echo -n "::: Stopping services..."
	#$SUDO service dnsmasq stop & spinner $! || true
	$SUDO service lighttpd stop & spinner $! || true
	$SUDO echo " done."
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

getGitFiles() {
	# Setup git repos for base files and web admin
	echo ":::"
	echo "::: Checking for existing base files..."
	if is_repo $piholeFilesDir; then
		make_repo $piholeFilesDir $piholeGitUrl
	else
		update_repo $piholeFilesDir
	fi

	echo ":::"
	echo "::: Checking for existing web interface..."
	if is_repo $webInterfaceDir; then
		make_repo $webInterfaceDir $webInterfaceGitUrl
	else
		update_repo $webInterfaceDir
	fi
}

is_repo() {
	# If the directory does not have a .git folder it is not a repo
	echo -n ":::    Checking $1 is a repo..."
		if [ -d "$1/.git" ]; then
		echo " OK!"
		return 1
	fi
	echo " not found!!"
	return 0
}

make_repo() {
    # Remove the non-repod interface and clone the interface
    echo -n ":::    Cloning $2 into $1..."
    $SUDO rm -rf "$1"
    $SUDO git clone -q "$2" "$1" > /dev/null & spinner $!
    echo " done!"
}

update_repo() {
    # Pull the latest commits
    echo -n ":::     Updating repo in $1..."
    cd "$1" || exit
    $SUDO git pull -q > /dev/null & spinner $!
    echo " done!"
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



sudo bash


touch /etc/pihole/.useIPv6
#set interface as wlan0.i.e, modify etc/network/interfaces.
#getstaticipv4settings.i.e, copy dhcpcd.conf to req location.
#setDNS.i.e, modify dnsmasq
#
#
#
#
apt-get update

apt-get install dnsutils bc toilet figlet dnsmasq lighttpd php5-common php5-cgi php5 git curl unzip wget

#stop services
service lighttpd stop
service dnsmasq stop

#add user pihole
useradd -r -s /usr/sbin/nologin pihole



#continue the same logic as in installPihole()
mkdir -p /etc/pihole/
mkdir -p /var/www/html
chown www-data:www-data /var/www/html
chmod 775 /var/www/html
usermod -a -G www-data pihole
  #lighty-enable-mod fastcgi fastcgi-php > /dev/null
  #be more verborse
lighty-enable-mod fastcgi fastcgi-php


########branching
##edit:git repos for pi-hole cannot be used since we don't declare variables.
#copy n paste only.
 
#installscripts()
mkdir /opt/pihole
#beware of variable user!!!!!!!!!!!!!!!!
chown "$USER":root /opt/pihole
chmod u+srwx /opt/pihole

cp Scripts/gravity.sh /opt/pihole/gravity.sh
cp Scripts/chronometer.sh /opt/pihole/chronometer.sh
cp Scripts/whitelist.sh /opt/pihole/whitelist.sh
cp Scripts/blacklist.sh /opt/pihole/blacklist.sh
cp Scripts/piholeDebug.sh /opt/pihole/piholeDebug.sh
cp Scripts/piholeLogFlush.sh /opt/pihole/piholeLogFlush.sh
cp Scripts/updateDashboard.sh /opt/pihole/updateDashboard.sh
chmod 777 /opt/pihole/{gravity,chronometer,whitelist,blacklist,piholeLogFlush,updateDashboard}.sh
cp /etc/.pihole/pihole /usr/local/bin/pihole
chmod 777 /usr/local/bin/pihole


#skipping dnsmasq config

###########################################################################
##WARNING::::::  PARTIAL IMPLEMENTATION:::::::::::::::::::::::::::::::::::

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


























###########################################################################
#lighttpd config
mv /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf.orig
cp lighttpd.conf /etc/lighttpd/lighttpd.conf
chmod 777 /etc/lighttpd/lighttpd.conf



#creating log file

touch /var/log/pihole.log
chmod 777 /var/log/pihole.log
chown dnsmasq:root /var/log/pihole.log


#installpiholeweb
mkdir /var/www/html/pihole
mv /var/www/html/index.lighttpd.html /var/www/html/index.lighttpd.orig
cp index.* /var/www/html/pihole/.



#install cron
cp pihole.cron /etc/cron.d/pihole


#run gravity.sh.

sh /opt/pihole/gravity.sh












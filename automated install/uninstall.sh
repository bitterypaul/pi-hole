
sudo bash

touch /etc/pihole/.useIPv6
#set interface as wlan0.i.e, modify etc/network/interfaces.
#getstaticipv4settings.i.e, copy dhcpcd.conf to req location.
#setDNS.i.e, modify dnsmasq
#
#
#
#

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
 












sudo bash
apt-get install dnsutils bc toilet figlet dnsmasq lighttpd php5-common php5-cgi php5 git curl unzip wget


touch /etc/pihole/.useIPv6

cp pihole /usr/local/bin/pihole
chmod 755 /usr/local/bin/pihole



mkdir -p /etc/pihole/

 useradd -r -s /usr/sbin/nologin pihole
	mkdir -p /var/www/html
	chown www-data:www-data /var/www/html
	chmod 775 /var/www/html
	usermod -a -G www-data pihole
	lighty-enable-mod fastcgi fastcgi-php > /dev/null

mkdir /var/www/html/pihole
cp /etc/.pihole/advanced/index.* /var/www/html/pihole/.
 cp /etc/.pihole/advanced/pihole.cron /etc/cron.d/pihole

cp pihole /usr/local/bin/pihole
chmod 755 /usr/local/bin/pihole
mkdir /etc/lighttpd
 chown "$USER":root /etc/lighttpd
		mv /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf.orig
cp /etc/.pihole/advanced/lighttpd.conf /etc/lighttpd/lighttpd.conf

touch /var/log/pihole.log
chmod 777 /var/log/pihole.log




 useradd -r -s /usr/sbin/nologin pihole









sh /opt/pihole/gravity.sh


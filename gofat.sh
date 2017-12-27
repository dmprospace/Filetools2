#!/bin/bash

# See http://mybookworld.wikidot.com/forum/t-583096
# See http://tech.roxee.tv/2012/06/12/solving-the-my-book-live-insane-load/
# http://community.wd.com/t5/My-Book-Live-Duo/New-MyBook-Duo-4Tb-astonishingly-slow-I-mean-really-soul/td-p/417642/page/5

# Disable all this stuff, but also make miocrawler drops its logs.
# vi /etc/rsyslog.d/miocrawler.conf

# [root@storagecasa rsyslog.d]# cat miocrawler.conf 
## local4.*       /var/log/miocrawler.log
# local4.*    /dev/null


# Make mediacrawler service unexecutable, and disable the 'tally' script in miocrawler.conf.

/etc/init.d/nfs-kernel-server restart
/etc/init.d/nfs-common restart
/etc/init.d/netatalk restart
/etc/init.d/portmap restart
/etc/init.d/upnp_nas restart
/etc/init.d/mDNSResponder restart
/etc/init.d/smb-daemon restart
/etc/init.d/orion restart

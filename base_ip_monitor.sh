#!/bin/sh

while [ 1 ]; do
IP=$HOME/bin/ip_addr
if [ ! -f  $IP ]; then touch $IP; fi
old=`cat $IP`
new=`wget -qO- http://ipecho.net/plain`

if [ X$old != X$new ];then
  echo "`date +%Y%m$d-%H%M%S`: Ended $old" >> $HOME/bin/old_ip_addr
  echo $new > $IP
  echo "<TABLE BORDER=3>"                    >  /tmp/ipmail
  echo "<TR><td>old</TD><td>new</TD></tr>"   >> /tmp/ipmail
  echo "<TR><td>$old</TD><td>$new</TD></tr>" >> /tmp/ipmail
  echo "</TABLE>"                            >> /tmp/ipmail
  ~/bin/sm.sh deveshmohnani@overstock.com,dmohnani@yahoo.com NEW_IP_IS_${new} /tmp/ipmail
  rm /tmp/ipmail
fi
sleep 3600
done
exit 0

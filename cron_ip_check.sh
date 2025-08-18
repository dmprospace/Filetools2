#!/bin/sh

IP=$HOME/bin/ip_addr
if [ ! -f  $IP ]; then touch $IP; fi
old=`cat $IP`
new=`wget -qO- http://ipecho.net/plain`

if [ X$old != X$new ];then
  echo $new > $IP
  echo "<TABLE BORDER=3>"                    >  /tmp/ip
  echo "<TR><td>old</TD><td>new</TD></tr>"   >> /tmp/ip
  echo "<TR><td>$old</TD><td>$new</TD></tr>" >> /tmp/ip
  echo "</TABLE>"                            >> /tmp/ip
  ~/bin/sm.sh <EMAIL> NEW_IP_IS_${new} /tmp/ip
  rm /tmp/ip
fi

exit 0

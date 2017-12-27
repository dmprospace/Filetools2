#!/bin/sh

myip=`curl -s checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//'`

echo $myip > ./ipaddr.txt

echo >> ./ipaddr.txt

myip=`wget -qO- http://ipecho.net/plain`

echo $myip >> ipaddr.txt

echo >>ipaddr.txt

#pstatus=`ping -c 1 192.168.1.25 2>/dev/null|grep icmp|awk '{print $NF}'`

#if [ $pstatus == "ms" ];then

# mout=`mount|grep '192.168.1.25'|awk -F ":" '{print $1}'`

# if [ $mout == '192.168.1.25' ];then

#   exit 0

# fi

# mount -a >/dev/null 2>&1

#else

# exit 0

#fi


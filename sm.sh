#!/bin/sh

cat /root/mailheader|sed -e "s/RECIPIENT/$1/g"| sed -e "s/SUBJECT/$2/g" >/tmp/p.$$
cat /tmp/p.$$ $3|sendmail -t
rm  /tmp/p.$$

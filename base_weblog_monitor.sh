#!/bin/sh -x
# Monitors Access Log of Apache for suspicious activity
while [ 1 ];do
# look for Unknown IPs
egrep -v '::|174.52.14.5|50.112.194.65|192.168.29.|192.168.1.|199.91.135.165|172.56.39.244|174.52.22.232|192.168.1|65.116.116.6|199.116.169.254|199.91.135.163|199.91.135.140|172.56.15.141|73.98.163.84|40.78.27.43|74.122.76.46|208.87.233.201|158.130.6.191|98.139.190.56|GET \/ HTTP|HEAD \/ HTTP|OPTIONS \/ HTTP|OPTIONS \* |GET \/index|POST \/ HTTP|GET http:|GET https:|GET \/\/ HTTP' /var/log/apache2/access.log |cut -d ' ' -f1,4,5,6,7,8,9,10|egrep '2[0-9][0-9] [0-9]+$'|sed -e 's/ -0700]/_-0700]/g'|sed -e 's/ -0600]/_-0600]/g'|tr -d '"'|sort -u> /tmp/unk_log_ips_new

if [ ! -f /tmp/unk_log_ips_old ];then
   cp -f /tmp/unk_log_ips_new /tmp/unk_log_ips_old
fi

# if something suspicious is found; compare with last run
diff /tmp/unk_log_ips_old /tmp/unk_log_ips_new >/dev/null 2>&1
RV=$?

# if something suspicious is found
if [ -f /tmp/unk_log_ips_new -a -s /tmp/unk_log_ips_new -a $RV -ne 0 ] ; then
  echo "[`date +%F_%T`] Found some new Suspicious activity" 
  echo ''> /tmp/whois_unk_log_ips_new

  for i in `cat /tmp/unk_log_ips_new |cut -d ' ' -f 1` ;do
    org=`whois $i|grep OrgName|tr -s ' '|cut -d ':' -f2|tr '\n' ','|tr ' ' '_'`
    grep $i /tmp/unk_log_ips_new|sed -e "s/$/ $org/g" >> /tmp/whois_unk_log_ips_new
  done

  echo '<TABLE BORDER=3><TR><TD>IP</td><td>DTTM</td><td>HTTP_CMD</td><td>URL</td><td>PROTO</td><td>CODE</td><td>LENGTH</TD><TD>ORGANIZATION</TD></TR>' >/tmp/mb
  cat /tmp/whois_unk_log_ips_new|perl -pe 's/ /<\/td><td>/g;s/^/<TR><TD>/g;s/$/<\/TD><\/TR>/g'|egrep -v '^</TD></TR>$'  >> /tmp/mb
  echo '</TABLE>' >> /tmp/mb
  echo '' >>/tmp/mb

  SUBJ="Found_some_new_activity"
  ~/bin/sm.sh <ADDR> Found_some_new_activity /tmp/mb ##~/mailbody
  echo $SUBJ
  rm /tmp/whois_unk_log_ips_new 
  mv /tmp/unk_log_ips_new /tmp/unk_log_ips_old
else
  echo "[`date +%F_%T`] No Suspicious activity"
fi
sleep 3600
done

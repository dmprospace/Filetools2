#!/bin/bash +x
egrep -v '::|199.91.135.165|172.56.39.244|174.52.22.232|192.168.1|65.116.116.6|199.116.169.254|199.91.135.163|199.91.135.140|172.56.15.141|73.98.163.84|40.78.27.43|74.122.76.46|208.87.233.201|158.130.6.191|98.139.190.56|GET \/ HTTP|HEAD \/ HTTP|OPTIONS \/ HTTP|OPTIONS \* |GET \/index|POST \/ HTTP|GET http:|GET https:|GET \/\/ HTTP|ttyy' /var/log/apache2/access.log |cut -d ' ' -f1,4,5,6,7,8,9,10|egrep '2[0-9][0-9] [0-9]+$'|sed -e 's/ -0600]/_-0600]/g'|tr -d '"'|sort -u> /tmp/unk_log_ips_new

if [[ ! -f /tmp/unk_log_ips_old ]];then
   cp -f /tmp/unk_log_ips_new /tmp/unk_log_ips_old
fi

# if something suspicious is found
diff /tmp/unk_log_ips_old /tmp/unk_log_ips_new >/dev/null 2>&1
RV=$?

if [[ -s /tmp/unk_log_ips_new && $RV -ne 0 ]] ; then
  echo "[`date +%F_%T`] Found some new Suspicious activity" 
fi

#!/bin/sh
# This Function gets image snapshot from all cams
snapshot()
{
   i=$1
   j=`echo $1|tr '.' '_'`
   ts=`date +%Y_%m_%d_%H_%M_%S`
   k="${j}_${ts}"
   wget http://$i/cgi-bin/snapshot.cgi \
       --http-user=admin \
       --http-password= \
        -O /var/www/ttyy/_cam/$j/$k.jpg >/dev/null 2>&1
   if [ ! -s /var/www/ttyy/_cam/$j/$k.jpg ]; then
      rm -f /var/www/ttyy/_cam/$j/$k.jpg >/dev/null 2>&1
   else
      unlink /var/www/ttyy/_cam/$j.jpg >/dev/null 2>&1
      ln -s /var/www/ttyy/_cam/$j/$k.jpg  /var/www/ttyy/_cam/$j.jpg
   fi
#   find /var/www/ttyy/_cam -name $j'*'.jpg -cmin +900 -exec mv {} /media4/_cam_pic_backup/$j/ \;
#   find /media4/_cam_pic_backup/$j -name $j'*'.jpg -cmin +2880 -exec rm {} \; 
   #wget http://$i/cgi-bin/magicBox.cgi?action=reboot \
   #--http-user=admin --http-password=  >/dev/null 2>&1
   #   /usr/bin/convert -thumbnail 200 $j.jpg tn_${j}.jpg &
}

#Main Program
d=`date +%Y_%m_%d_%H_%M_%S`;
while [ 1 ];do
 if [ ! -f '/var/www/ttyy/_cam/pause' ]; then
   echo "-------------------------------------"
   for i in `cat /var/www/ttyy/_cam/camips|egrep -v '^#'|tr '\n' ' '`
   do
    echo "[`date +%Y-%m-%d_%H-%M-%S`] START $i"
    snapshot $i
    echo "[`date +%Y-%m-%d_%H-%M-%S`] Done!"
    echo "-------------------------------------"
   done
     echo $d > /var/www/ttyy/_cam/last_run
 fi
 sleep 1
done


#!/bin/sh

while [ 1 ];do
  #find /var/www/ttyy/_cam -name $j'*'.jpg -cmin +900 -exec mv {} /media4/_cam_pic_backup/$j/ \;
  #find /media4/_cam_pic_backup/$j -name $j'*'.jpg -cmin +4320 -exec rm {} \;
  find /var/www/ttyy/_cam -name $j'*'.jpg -cmin +900 -exec rm {} \;
  sleep 300
done


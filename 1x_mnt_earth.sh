#!/bin/bash -x

param=$1

# MOUNT DOC share for www
set -o pipefail
# Is Mounted
###################################
#Mount PUBLIC for books
mount|grep '192.168.1.23'|grep -i PUBLIC
if [ $? -ne 0 ];then
#Not mounted
  if [ X$param == X-M ]; then
  # Is requested to mount
  # Mount
     mount -t cifs -o rw -o username=root,password=,uid=33,gid=33 //192.168.1.23/Public/earthpublic_backup/earthpublic /media2/mnt/earthpublic
     if [ $? == 0 ];then
       echo "Mount was Successful"
       ls -l /media2/mnt/earthpublic
     fi
  fi
else
# Mounted
  echo "Already mounted /media2/mnt/earthpublic"
  ls -l /media2/mnt/earthpublic
fi

param=$1
 

# Is Mounted
mount|grep '192.168.1.28'
if [ $? -ne 0 ];then
#Not mounted
  if [ X$param == X-M ] ;then
  # Is requested to mount
  # Mount
     mount -t smbfs -o username=root,password= //192.168.1.28/PLUTO/ /shares/Public/mnt/pluto/
     if [ $? == 0 ];then
       echo "Mount SuccessFull"
       ls -l /shares/Public/mnt/pluto/
     fi
  fi
else
# Mounted
  echo "Already mounted"
  ls -l /shares/Public/mnt/pluto/
fi

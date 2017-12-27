param=$1
 

# Is Mounted
mount|grep 192.168.1.25
if [ $? -ne 0 ];then
#Not mounted
  if [ X$param == X-M ] ;then
  # Is requested to mount
  # Mount
     mount -o username=root,password= //192.168.1.25/Public /media4/
     if [ $? == 0 ];then
       echo "Mount SuccessFull"
       #ls -l /media4/
     else
       exit 1
     fi
   fi
else
# Mounted
  echo "Already mounted"
  ls -l /media4/
fi

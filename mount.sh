#mount -t smbfs -o username=your_username,password=your_password //remote/location /local/location
#mount -t smbfs -o username=root,password= //192.168.1.22/location /local/location

#//192.168.1.22/F on /shares/Public/mnt/venus/F type cifs (rw)
#//192.168.1.22/I on /shares/Public/mnt/venus/I type cifs (rw)
for i in `mount|grep venus|cut -d ' ' -f 3`
do
 umount $i
done
x=`mount|grep venus|cut -d ' ' -f 3`

if [ X$x=="X" ];then
 rm -rf /shares/Public/mnt/venus/*
fi

for i in `/home/root/scripts/list_venus_mounts.sh`
do
  mkdir /shares/Public/mnt/venus/$i
  mount -t smbfs -o username=root,password= //192.168.1.22/$i //shares/Public/mnt/venus/$i
done

#mount -t smbfs -o username=root,password= //192.168.1.22/F //shares/Public/mnt/venus/F
#mount -t smbfs -o username=root,password= //192.168.1.22/I //shares/Public/mnt/venus/I


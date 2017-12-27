#!/bin/sh

#This Shell script takes a backup of a stock version of UNIX system config file
#and preserves full path as underscored separated NAME
#under back path of ~/wd_sys_backup/

if [ X"$1" == "X" ];then
   echo "File $1 not provided";
   exit 1
fi

if [ ! -f $1 ];then
   echo "File $1 not found";
   exit 1
fi


cp $1 ~/wd_sys_backup/`echo $1|tr '/' '_'`
if [ $? == 0 ];then
   echo "Copy successful"
   ls -l ~/wd_sys_backup/`echo $1|tr '/' '_'`
else
   echo "Copy Failed"
fi


#!/bin/bash
ps -aef|grep base_cam_monitor.sh |grep -v grep
RV=$?

if [ $RV -ne "0" ];then
 nohup /bin/sh ~/bin/base_cam_monitor.sh >/dev/null 2>&1 &
fi


ps -aef|grep old_cam_pic_cleanup.sh|grep -v grep
RV=$?

if [ $RV -ne "0" ];then
 nohup /bin/sh ~/bin/old_cam_pic_cleanup.sh >/dev/null 2>&1 &
fi


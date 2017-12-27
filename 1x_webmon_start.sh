#!/bin/bash
ps -aef|grep base_weblog_monitor.sh|grep -v grep
RV=$?

if [ $RV -ne "0" ];then
  nohup ~/bin/base_weblog_monitor.sh >/dev/null 2>&1 &
fi

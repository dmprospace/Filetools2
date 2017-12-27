#!/bin/sh
smbclient -U=root --no-pass -L 192.168.1.24 2>/dev/null |grep '        '|grep Disk|tr -s ' '|cut -d ' ' -f 1|sed -e 's/[^A-Z]//g'
smbclient -U=root --no-pass -L 192.168.1.26 2>/dev/null |grep '        '|grep Disk|tr -s ' '|cut -d ' ' -f 1|sed -e 's/[^A-Z]//g'
smbclient -U=root --no-pass -L 192.168.1.24 2>/dev/null |grep '        '|grep Disk
smbclient -U=root --no-pass -L 192.168.1.26 2>/dev/null |grep '        '|grep Disk

#!/bin/bash

# wget https://raw.githubusercontent.com/muwlgr/scripts/main/upgrade-lubuntu3264.sh
# sudo bash upgrade-lubuntu3264.sh

grep -w lm /proc/cpuinfo || {
 echo long mode not supported on CPU
 exit 1
}

[ $(awk '$1=="MemTotal:"{print $2}' /proc/meminfo) -lt $((1024**2*3/2)) ] && {
 echo RAM is less than 1.5 GB
 exit 1
}

[ $(df -P / | awk '$NF=="/"{print $4}') -lt $((1024**2*8)) ] && {
 echo root FS has less than 8 GB free
 exit 1
}

pfl=pkgs1.tmp
aapkg=apt-auto.tmp

uname -m | grep i.86 && { # while we are under 32-bit kernel
 dpkg --get-selections > $pfl # save installed package list
 apt-mark showauto | sed 's/:.*//' | sort -u > $aapkg # save auto marks
 dpkg --add-architecture amd64
 apt update
 apt install linux-image-generic:amd64 thermald:i386 # this will pull in iucode-tool:amd64, not runnable under i386, but this is not fatal
 reboot
}

apt remove $(dpkg -l | egrep -i '(java|jdk|jre|libfm|cron|logrotate|libdaemon).*i386' | awk '{print $2}') # to avoid upgrade conflicts, will be reinstalled later

dpkg -l dpkg | grep -w i.86 && { # upgrade apt and dpkg
 apt install apt:amd64 apt-utils:amd64 dpkg:amd64
 apt update
}

apt install perl-base:amd64 # first critical package to upgrade separately
apt -f install
apt autoremove

dpkg -l systemd | grep -w i.86 && { # need to complete systemd upgrade before udev could be properly restarted
 apt install $(awk '$2=="install"&&$1~/systemd/{print $1}' $pfl | grep -v cron | sed 's/:i386/:amd64/')
}

#critical packages better to upgrade in advance
apt install $(egrep '^(base-files|base-passwd|bash|bsdutils|coreutils|debianutils|diffutils|e2fsprogs|fdisk|findutils|grep|gzip|hostname|init|libc-bin|login|mount|ncurses-bin|sed|sudo|sysvinit-utils|tar|util-linux)\s+install$' $pfl | 
              awk '{print $1":amd64"}')
apt autoremove

dpkg -l dash | grep -w i.86 && { # remove diverts before upgrading dash, https://askubuntu.com/questions/81824
 dpkg-divert --remove /bin/sh
 dpkg-divert --remove /usr/share/man/man1/sh.1.gz
 apt install dash:amd64
}

dpkg -l acpid | grep -w i.86 && { # acpid upgrade bug at https://bugs.launchpad.net/ubuntu/+source/acpid/+bug/1760391
 apt install acpid:amd64
 systemctl --failed | grep acpid && {
  systemctl restart acpid.socket
  systemctl restart acpid 
 }
 dpkg -l acpid | grep 'iF *acpid ' && apt -f install
}

apt install $(dpkg -l | awk '$4=="i386"&&$1=="ii"{print $2}' | awk -F: '{print $1":amd64"}') # explicit install all amd64 versions where i386 is still installed
apt autoremove 
apt install $(awk '$2=="install"{print $1}' $pfl | grep -v :i386 | grep -v cndrvcups) # upgrade the rest
apt-mark auto $(cat $aapkg) # restore auto marks for apt autoremove

pkgs() { # $1 - architecture
 dpkg -l | awk '$4=="'$1'"{print $2}' | awk -F: '{print $1}' | sort -u
}

apt remove $(comm -12 <(pkgs i386) <(pkgs amd64) | sed 's/$/:i386/' ) #remove every :i386 pkg which has :amd64 equivalent installed
apt autoremove # autoremove the rest
dpkg --purge $(dpkg -l | awk '$4=="i386"&&$1=="rc"{print $2}')

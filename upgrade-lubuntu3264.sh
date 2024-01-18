#!/bin/bash

# wget https://raw.githubusercontent.com/muwlgr/scripts/main/upgrade-lubuntu3264.sh
# sudo bash upgrade-lubuntu3264.sh

pfl=pkgs1.tmp

dpkg --get-selections > $pfl

uname -m | grep 'i.86' && {
 dpkg --add-architecture amd64
 apt update
 apt install linux-image-generic:amd64
 reboot
}

dpkg -l dpkg | grep -w i.86 && { 
 apt install apt:amd64 apt-utils:amd64 dpkg:amd64
 apt update
}

apt install perl-base:amd64
apt -f install

dpkg -l systemd | grep -w i.86 && {
 apt install $(awk '$2=="install"{print $1}' $pfl | egrep -i 'systemd|udev' | sed 's/:i386//')
 apt -f install
}

apt install base-files:amd64 base-passwd:amd64 bash:amd64 bsdutils:amd64 coreutils:amd64 debianutils:amd64 diffutils:amd64 e2fsprogs:amd64 fdisk:amd64 findutils:amd64 grep:amd64 gzip:amd64 hostname:amd64 init:amd64 libc-bin:amd64 login:amd64 mount:amd64 ncurses-bin:amd64 sed:amd64 sudo:amd64 sysvinit-utils:amd64 tar:amd64 util-linux:amd64
dpkg -l dash | grep -w i.86 &&
{ dpkg-divert --remove /bin/sh
  dpkg-divert --remove /usr/share/man/man1/sh.1.gz
  apt install dash:amd64
}

apt install $(awk '$2=="install"{print $1}' $pfl | grep -v :i386)

pkgs() { # $1 - architecture
 dpkg -l | awk '$4=="'$1'"{print $2}' | awk -F: '{print $1}' | sort -u
}
apt remove $(comm -12 <(pkgs i386) <(pkgs amd64) | sed 's/$/:i386/' )
apt autoremove


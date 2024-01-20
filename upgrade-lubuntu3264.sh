#!/bin/bash

# wget https://raw.githubusercontent.com/muwlgr/scripts/main/upgrade-lubuntu3264.sh
# sudo bash upgrade-lubuntu3264.sh

pfl=pkgs1.tmp

uname -m | grep i.86 && { # while we are under 32-bit kernel
 dpkg --get-selections > $pfl # save installed package list
 dpkg --add-architecture amd64
 apt update
 apt install linux-image-generic:amd64 thermald:i386 # this will pull in iucode-tool:amd64, not runnable under i386, but this is not fatal
 reboot
}

# acpid can't complete its upgrade properly, reinstall it - https://bugs.launchpad.net/ubuntu/+source/acpid/+bug/1760391
dpkg -l acpid | grep -w i.86 && apt remove acpid

dpkg -l dpkg | grep -w i.86 && { # upgrade apt and dpkg
 apt install apt:amd64 apt-utils:amd64 dpkg:amd64
 apt update
}

apt install perl-base:amd64 # first critical package to upgrade separately
apt -f install
apt autoremove

dpkg -l systemd | grep -w i.86 && { # need to complete systemd upgrade before udev could be properly restarted
 apt install $(awk '$2=="install"&&$1~/systemd/{print $1}' $pfl | sed 's/:i386//')
}

#critical packages better to upgrade in advance
apt install base-files:amd64 base-passwd:amd64 bash:amd64 bsdutils:amd64 coreutils:amd64 debianutils:amd64 diffutils:amd64 e2fsprogs:amd64 fdisk:amd64 findutils:amd64 grep:amd64 gzip:amd64 hostname:amd64 init:amd64 libc-bin:amd64 login:amd64 mount:amd64 ncurses-bin:amd64 sed:amd64 sudo:amd64 sysvinit-utils:amd64 tar:amd64 util-linux:amd64
apt autoremove

dpkg -l dash | grep -w i.86 && { # remove diverts before upgrading dash, https://askubuntu.com/questions/81824
 dpkg-divert --remove /bin/sh
 dpkg-divert --remove /usr/share/man/man1/sh.1.gz
 apt install dash:amd64
}

apt install $(awk '$2=="install"{print $1}' $pfl | grep -v :i386) # upgrade the rest
systemctl --failed | grep acpid && { # acpid bug at https://bugs.launchpad.net/ubuntu/+source/acpid/+bug/1760391
 systemctl restart acpid.socket
 systemctl restart acpid
}
dpkg -l acpid | grep '^iF *acpid' && apt -f install
apt autoremove

pkgs() { # $1 - architecture
 dpkg -l | awk '$4=="'$1'"{print $2}' | awk -F: '{print $1}' | sort -u
}

apt remove $(comm -12 <(pkgs i386) <(pkgs amd64) | sed 's/$/:i386/' ) #remove every :i386 pkg which has :amd64 equivalent installed


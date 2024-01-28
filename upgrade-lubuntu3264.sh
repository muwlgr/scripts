#!/bin/bash

# wget https://raw.githubusercontent.com/muwlgr/scripts/main/upgrade-lubuntu3264.sh
# sudo bash upgrade-lubuntu3264.sh
# the script is as idempotent/repeatable as it is possible. you may restart it multiple times if your upgrade is incomplete by some reson. also you may modify it according to your /bin/bash knowledge

[ $(lsb_release -sc) = "bionic" ] || {
 echo support only Ubuntu 18.04 Bionic
 exit 1
}

grep -w lm /proc/cpuinfo || {
 echo long mode not supported on the CPU
 exit 1
}

[ $(awk '$1=="MemTotal:"{print $2}' /proc/meminfo) -lt $((1024**2*3/2)) ] && {
 echo RAM is less than 1.5 GB
 exit 1
}

[ $(df -P / | awk '$NF=="/"{print $4}') -lt $((1024**2*8)) ] && {
 echo root FS has less than 8 GB free space
 exit 1
}

pfl=pkgs1.tmp
aapkg=apt-auto.tmp

uname -m | grep i.86 && { # while we are under 32-bit kernel
 dpkg --get-selections > $pfl # save installed package list
 apt-mark showauto | sed 's/:.*//' | sort -u > $aapkg # save auto marks
 dpkg --add-architecture amd64
 apt update
 apt install linux-image-generic:amd64 thermald:i386 # this will pull in iucode-tool:amd64, not runnable under i386, but this will be fixed after the reboot
 reboot
}

apt remove $(dpkg -l | 
             egrep -i '^ii .*(java|jdk|jre|libfm|cron|logrotate|libunity|upower|hplip|hpaio|lvm2|wine|system-config-date|xfburn|light|python).* i386 ' | # add your own patterns for egrep
             awk '{print $2}') # to avoid upgrade conflicts, will be reinstalled later
dpkg -l openjdk-11-jre-headless | grep -w i.86 && dpkg --purge openjdk-11-jre-headless # this 
dpkg -l libkmod2 | grep -w i.86 && rm -v /usr/share/doc/libkmod2/changelog.Debian.gz   # and this is my findings coded explicitly to avoid upgrade conflicts

dpkg -l dpkg | grep -w i.86 && { # upgrade apt and dpkg
 apt install apt:amd64 apt-utils:amd64 dpkg:amd64
 apt update
}

apt -f install # this will upgrade perl-base:i386 to :amd64
apt autoremove

dpkg -l acpid | grep -w i.86 && { # acpid upgrade bug at https://bugs.launchpad.net/ubuntu/+source/acpid/+bug/1760391
 apt install acpid:amd64
 systemctl --failed | grep acpid && {
  systemctl restart acpid.socket
  systemctl restart acpid 
 }
 dpkg -l acpid | grep 'iF *acpid ' && apt -f install
}

# to avoid being cut off the network. move this higher if you wish. may be even higher that apt/dpkg upgrade.
apt install $(dpkg -l | egrep '^ii .*(openssh|network-manager|sudo|libpam|appindicator).* i386 ' | awk '{print $2}' | sed 's/:i386//;s/$/:amd64/')
[ -s /etc/resolv.conf ] || ln -sfv /run/NetworkManager/resolv.conf /etc/ # sometimes this happens, some times it does not ...

# need to complete systemd upgrade before udev could be properly restarted
dpkg -l systemd | grep -w i.86 && apt install $(dpkg -l | egrep '^ii +.*systemd.*[: ].*i386 ' | awk '{print $2}' | sed 's/:i386//;s/$/:amd64/')

#critical packages better to upgrade in advance
apt install $(dpkg -l | 
              egrep '^ii +(base-files|base-passwd|bash|bsdutils|coreutils|debianutils|diffutils|e2fsprogs|fdisk|findutils|grep|gzip|hostname|init|libc-bin|login|mount|ncurses-bin|sed|sysvinit-utils|tar|util-linux)[: ].*i386 ' | 
              awk '{print $2}' | sed 's/:i386//;s/$/:amd64/')

dpkg -l dash | grep -w i.86 && { # remove diverts before upgrading dash, https://askubuntu.com/questions/81824
 dpkg-divert --remove /bin/sh
 dpkg-divert --remove /usr/share/man/man1/sh.1.gz
 apt install dash:amd64
}

# upgrade all running i386 executables, including udev
z="$(dpkg -l $(lsof -n | sed -n '/ txt /{s_^.* /_/_;s_^/usr/_/_;p}' | sort -u | grep -v '/proc/.*/exe' |
               fgrep -f - /var/lib/dpkg/info/*.list | sed 's/\.list:.*//;s_.*/__' | sort -u) | 
     grep -w i.86 | awk '{print $2}' | sed 's/:i386//;s/$/:amd64/')"
[ "$z" ] && {
 apt install $z
 apt -f install
}

pkgs() { # $1 - architecture
 dpkg -l | awk '$4=="'$1'" && $1=="ii"{print $2}' | awk -F: '{print $1}' | sort -u
}

apt install $(dpkg -l | awk '$4=="i386" && $1=="ii" && $2!~/^lib/{print $2}' | sed 's/:i386/:amd64/') # upgrade all non-library packages
apt autoremove
apt install $(dpkg -l | awk '$4=="i386" && $1=="ii" && $2~/^lib/{print $2}' | sed 's/:i386/:amd64/') # then libraries
apt autoremove

pfilter='drvcups|google-chrome|miniupnp|insserv|gstreamer|gksu|png12|anydesk|kyocera|audcore|plymouth|hotkeys|gnome-search|gtop|cramfs|cgmanager|xfce4|xtables|vte|mountall|gnomekeyring|gudev|python-support|system-config-date|ubuntu-extras-keyring|icu5|heirloom|gcc-4.9|adobe-flash|gecko|gutenprint|toshset|^lib[abcdeghijlmopqstuvwx]|oxideqt|gnome-mplayer|^lib(readline|rtmp|farstream)|initscripts|sysv-rc|wine|cque|unetbootin|ubuntu-software-center|skype|ualinux|linux-.*4\.4\.0|eusw|esound-common' # add more stray packages to this list if you get 'exit 1' from failed 'apt install' commands below
apt install $(dpkg -l $(awk '$2=="install"{print $1}' $pfl | awk -F: '{print $1}') | 
              tail -n +$((1+$(dpkg -l | grep -n '====' | awk -F: '{print $1}'))) | 
              awk '$4=="i386"||$1!="ii"{print $2}' | egrep -v $pfilter | grep -v binutils | sed 's/:i386/:amd64/') || exit 1
apt autoremove 
apt install $(awk '$2=="install"{print $1}' $pfl | grep -v :i386 | egrep -v $pfilter | grep -v binutils ) || exit 1 # upgrade the rest
apt-mark auto $(comm -23 $aapkg <(apt-mark showauto | sed 's/:.*//' | sort -u)) # restore auto marks for apt autoremove

apt remove $(comm -12 <(pkgs i386) <(pkgs amd64) | sed 's/$/:i386/' ) #remove every :i386 pkg which has :amd64 equivalent installed
apt remove $(diff -Bbw <(grep -w install $pfl | 
                         sed 's/:i386//') <(dpkg --get-selections | 
                                            grep -w install | 
                                            sed 's/:amd64//' ) | 
             awk '$1==">"{print $2}' | 
             egrep -v 'microcode|binutils|thermald') # remove unneeded packages pulled in during upgrade
apt autoremove # autoremove the rest
z="$(dpkg -l | awk '$4=="i386"&&$1=="rc"{print $2}')"
[ "$z" ] && dpkg --purge $z # clean out remaining i386 leftovers

diff <(awk '$2=="install"{print $1}' $pfl | 
       awk -F: '{print $1}') <(dpkg --get-selections | awk '$2=="install"{print $1}' |
                               awk -F: '{print $1}') # print what packages you have gained and lost for your review

#!/bin/bash

# wget https://raw.githubusercontent.com/muwlgr/scripts/main/upgrade-lubuntu3264.sh
# sudo bash upgrade-lubuntu3264.sh
# the script is as idempotent/repeatable as it is possible. you may restart it multiple times if your upgrade is incomplete by some reson. also you may modify it according to your /bin/bash knowledge

distro=$(lsb_release -sc)

fail1(){ echo $* # $* - message
         exit 1
}

# pre-flight checks

[ $distro = bionic ]                                                      || fail1 support only Ubuntu 18.04 Bionic
grep -w lm /proc/cpuinfo                                                  || fail1 long mode not supported on the CPU
[ $(awk '$1=="MemTotal:"{print $2}' /proc/meminfo) -gt $((1024**2*3/2)) ] || fail1 RAM is less than 1.5 GB
[ $(df -P / | awk '$NF=="/"{print $4}')            -gt $((1024**2*8))   ] || fail1 root FS has less than 8 GB free space

pfl=pkg-$distro.tmp
aapkg=aapkg-$distro.tmp

iigrep(){ dpkg -l | egrep -i '^ii +('"$1"')' | awk '{gsub(/:[^:]*/,"",$2);print $2}' # $1 - egrep regexp
}
pkgs(){ dpkg -l | awk '$4=="'$1'" && $1=="ii"{print $2}' | awk -F: '{print $1}' | sort -u # $1 - architecture
}
pkgfilter(){ awk '$2=="install"{print $1}' | sed 's/:.*//' | sort -u # stdin: output of dpkg --get-selections
}

uname -m | grep i.86 && { # while we are under 32-bit kernel
 [ -f $pfl ] || dpkg --get-selections > $pfl # save installed package list
 apt-mark showauto | sed 's/:.*//' | sort -u > $aapkg # save auto marks
 dpkg --add-architecture amd64
 apt update
 apt install $(iigrep linux-image-generic | sed 's/$/:amd64/') thermald:i386 || apt -f install # this will pull in iucode-tool:amd64, not runnable under i386, but this will be fixed after the reboot
 reboot
}

dpkg -l openjdk-11-jre-headless | grep -w i.86 && dpkg --purge openjdk-11-jre-headless # this
fn=/usr/share/doc/libkmod2/changelog.Debian.gz
dpkg -l libkmod2 | grep -w i.86 && [ -f $fn ] && rm -v $fn || :   # and this is my findings coded explicitly to avoid upgrade conflicts

apt install $(iigrep '(dpkg|apt(-utils)?) .* i386' | sed 's/$/:amd64/')
apt update
later=$(iigrep '.*(openssh|network-manager|sudo|libpam|appindicator).* i386 ' | sed 's/$/:amd64/')
while ! apt -f install  # this will upgrade perl-base:i386 to :amd64
do :
done
apt autoremove
# to avoid being cut off the network. move this higher if you wish. may be even higher that apt/dpkg upgrade.
apt install $later
[ -s /etc/resolv.conf ] || ln -sfv /run/NetworkManager/resolv.conf /etc/ # sometimes this happens, some times it does not ...
dpkg -l | grep libsane-hpaio:i386 && apt purge libsane-hpaio:i386 # damn
dpkg -l acpid | grep -w i.86 && { # acpid upgrade bug at https://bugs.launchpad.net/ubuntu/+source/acpid/+bug/1760391
 apt install acpid:amd64 || {
  systemctl --failed | grep acpid && {
   systemctl restart acpid.socket
   systemctl restart acpid
  }
 }
 dpkg -l acpid | grep 'iF *acpid ' && apt -f install
}

# need to complete systemd upgrade before udev could be properly restarted
#dpkg -l systemd | grep -w i.86 && apt install $(dpkg -l | egrep '^ii +.*systemd.*[: ].*i386 ' | awk '{print $2}' | sed 's/:i386//;s/$/:amd64/')
apt install $(iigrep '.*systemd.* .* i386' | sed 's/$/:amd64/')

dpkg -l dash | grep -w i.86 && { # remove diverts before upgrading dash, https://askubuntu.com/questions/81824
 dpkg-divert --remove /bin/sh
 dpkg-divert --remove /usr/share/man/man1/sh.1.gz
 apt install dash:amd64 # need to upgrade dash alone, as it provides /bin/sh
}

#critical packages better to upgrade in advance
apt install $(
 iigrep '(base-files|base-passwd|bash|bsdutils|coreutils|dash|debianutils|diffutils|e2fsprogs|fdisk|findutils|grep|gzip|hostname|init|kmod|libc-bin|login|mount|ncurses-bin|sed|sysvinit-utils|tar|util-linux)[: ].*i386 ' |
 sed 's/$/:amd64/')

apt install $(iigrep '.* i386' | grep -v 'linux-[hilm]' | sed 's/$/:amd64/')

apt remove $(comm -12 <(pkgs i386) <(pkgs amd64) | sed 's/$/:i386/' ) #remove every :i386 pkg which has :amd64 equivalent installed
apt autoremove
z="$(dpkg -l | awk '$4=="i386"&&$1=="rc"{print $2}')"
[ "$z" ] && dpkg --purge $z # clean out remaining i386 leftovers
apt install $(comm -23 <(pkgfilter < $pfl) <(dpkg --get-selections | pkgfilter) | egrep -iv 'binutils|linux-[hilm]')
apt remove  $(comm -13 <(pkgfilter < $pfl) <(dpkg --get-selections | pkgfilter | fgrep -v fwup))

apt-mark auto $(comm -23 $aapkg <(apt-mark showauto | sed 's/:.*//' | sort -u)) # restore auto marks for apt autoremove
comm -3 <(pkgfilter < $pfl) <(dpkg --get-selections | pkgfilter) # print what packages you have gained and lost for your review

exit 1 # what is below, should be removed or moved above if needed --------------------------------------------------

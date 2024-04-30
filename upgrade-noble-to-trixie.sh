
gen_debian_list() { # $1 - deb or deb-src, $2 - mirror URL, $3 - suite name , $4 - sections , $5 - sec.upd. url/path
 { for i in $3 $3-updates 
   do echo $1 $2 $i $4
   done
   echo $1 $5 $4
 } > /etc/apt/sources.list.d/$3.list
 apt update
}

gen_debian_list_trixie() { # $1 - deb or deb-src, $2 - mirror URL, $3 - distro name
 gen_debian_list $1 $2 $3 'main contrib non-free non-free-firmware' 'http://security.debian.org/debian-security '$3'-security' # added section non-free-firmware
}

drop_sources() { # $1 - distro name
 find /etc/apt/sources* -type f -iname '*.list' | xargs grep -l '^ *deb .* '$1 | while read l
 do sed -r -i '/^ *deb/s/^/#/' $l # disconnect from specified repos
 done
 grep -lw $1 /etc/apt/sources*/*.sources | while read l 
 do mv $l $l.disabled
 done
}

debian_quick_upgrade(){ # $1 - old distro, $2 - new distro , $3 - arch , $4 - debmir
 drop_sources $1
 gen_debian_list_$2 deb $4 $2
 apt install apt dpkg
 apt update
 apt install $(dpkg -l | egrep 'ii *(base-files|lsb-release)' | awk '{print $2}') # bump lsb_release version
 apt autoremove
# reboot
}

pvcat(){ # $1 - folder
 cd $1 
 for p in * 
 do echo $p=$(cat $p)
 done
}

debmir=http://debian.volia.net/debian

arch='x'
case $(uname -m) in
 i686) arch=686 ;;
 x86_64) arch=amd64 ;;
esac

distro=trixie
olddistro=noble
pfl=pkg-noble.tmp
aapkg=aapkg-noble.tmp
flist=$(pwd)/dpkg-l.tmp
ulist=$(mktemp -d)

main(){ # called recursively for upgrade without reboot
 type lsb_release || apt install lsb-release
 case $(lsb_release -sc) in
  noble)
   # save package lists and states
   [ -f $pfl ] || dpkg --get-selections > $pfl
   [ -f $aapkg ] || apt-mark showauto | sed 's/:.*//' | sort -u > $aapkg
   [ -s $flist ] || dpkg -l > $flist

   # revert some ubuntu customizations
   dpkg -l | grep language-pack && ls /var/lib/locales/supported.d/* && sort -u /var/lib/locales/supported.d/* | grep '^[A-Za-z]' > /tmp/locale.gen
   find /etc/profile.d -type f | xargs grep -l '^eval .*locale-check' | while read l
   do sed -r -i '/^ *eval .*locale-check/s/^/#/' $l
   done
   ( cd /etc
     for i in passwd group shadow gshadow
     do grep '^gdm:' $i && ! grep '^Debian-gdm:' $i && echo Debian-$(grep '^gdm:' $i) >> $i || : # debian gdm3 hack
     done )

   type snap && snap remove firefox snapd-desktop-integration # this damned crap prevents snapd from being purged
   apt purge $(dpkg -l | egrep -i 'ii +(ubuntu-advantage-tools|ubuntu-pro-client|apparmor) ' | awk '{print $2}')
   apt remove $(dpkg -l | egrep -i 'ii +(snapd) .*build' | awk '{print $2}')
   apt remove $(dpkg -l | egrep -i '(fcitx|abiword|gnumeric|manpages|mailcap|mime-support|usb-creator|fwupd|transmission|plym|audacious|xf[bc]|system-config|gnome-control|indicator|firefox|gdebi|language-pack|linux-firmware|chromaprint|freerdp|pidgin|purple|[ b]gconf|nmap|lib(qt)|ry-cu|(ubuntu|gnome-user)-docs|ps-br|rsyslog| cups |me-us|ud-in).*ubuntu|on-data-server .*3.52.0' | awk '{print $2}' )
   apt autoremove

   dpkg -l | grep '^ii *debian-archive-keyring ' || {
    set -- $(wget -O - https://packages.debian.org/$distro/all/debian-archive-keyring/download | grep -io 'http.*all\.deb' | sort -u) # get package name from its DL page
    wget $1
    dpkg -i $(basename $1)
   }

   drop_sources $olddistro
   gen_debian_list_$distro deb $debmir $distro # some downgrades before quick upgrade
   dpkg -l | egrep '^ii +network-manager' || { # prepare to drop netplan
    dpkg -l | egrep -i '^ii +netplan' && {
     ls -l /etc/systemd/network/* || cp -av /run/systemd/network/* /etc/systemd/network/ 
     systemctl is-enabled systemd-networkd || systemctl enable systemd-networkd 
    }
   }

   awk '$1=="ii"{print $2,$3}' $flist | # list all we had initially
   while read pp ubuv # for every installed package
   do [ -f $ulist/$pp ] && continue
      apt-cache showpkg $pp | grep $distro'.*Packages' | grep -v '^ ' | sed 's/ (.*//' | sort -V | tail -n1 | # find its Debian upgrade version
      while read debv
      do echo $debv > $ulist/$pp # record this version to be installed for this package name
      done
   done # so in $ulist we have only packages which have Debian version

   ulist0=$(mktemp -d) # apt & dpkg
   ( cd $ulist 
     mv -v $(ls apt* dpkg* *eatmydata* ) $ulist0/ ) # upgrade them first
   apt install $(pvcat $ulist0) # upgrade apt and dpkg
   apt update # rebuild package DB with updated apt
   ulist2=$(mktemp -d) # libc6 & locales
   ( cd $ulist 
     mv -v $(ls libc6* libc-* locales cloud*) $ulist2/ ) # postpone breaking upgrades
   ulist3=$(mktemp -d) # base-files
   ( cd $ulist
     mv -v base-files $ulist3/ ) # postpone breaking upgrades

   mlist=$(mktemp) # install some debian&hardware-specific pkgs
   lspci | grep -i realtek && echo firmware-realtek >> $mlist
   lspci | grep -i atheros && echo firmware-atheros >> $mlist
   lspci | egrep -i 'vga.*(intel|nvidia)' && echo firmware-misc-nonfree >> $mlist
   dpkg -l | grep -i linux-header && echo linux-headers-$arch >> $mlist
   echo linux-image-$arch >> $mlist
   grep 'ii *gnome-session-bin ' $flist && echo gnome-session >> $mlist

   apt install $(pvcat $ulist) $(cat $mlist) 
   ( cd $ulist
     [ -f gdm3 ] && mv gdm3 $ulist2/ ) || : # don't allow to remove it
   [ -s /tmp/locale.gen ] && comm -23 /tmp/locale.gen <(grep '^[A-Za-z]' /etc/locale.gen | sort -u) >> /etc/locale.gen
   tail /etc/locale.gen
   apt install $(pvcat $ulist2) # dangerous upgrades of libc6/locales
   apt install $(pvcat $ulist3) # dangerous upgrade of base-files
   rm -rv $ulist0 $mlist $ulist2 $ulist3
   debian_quick_upgrade $olddistro $distro $arch $debmir 
   main # restart upgrade for trixie
  ;;
  trixie)

   krlist=$(mktemp) # remove ubuntu's kernel
   for i in $(dpkg -l | grep $(uname -r) | awk '{print $2}') 
   do apt-cache showpkg $i | grep -i $distro || echo $i >> $krlist
   done
   
   apt remove $(dpkg -l | egrep -i 'ubuntu-|n(et)?plan' | awk '{print $2}' ) $(cat $krlist)
   apt autoremove
   apt upgrade || apt -f install
   apt autoremove
   apt dist-upgrade 
   apt autoremove
   
   ulist4=$(mktemp -d)
   diff <(awk '$2=="install"{print $1}' $pfl | 
       awk -F: '{print $1}') <(dpkg --get-selections | awk '$2=="install"{print $1}' |
                               awk -F: '{print $1}') | awk '$1=="<"{print $2}' |
   ( cd $ulist
     mv -v $(ls $(cat)) $ulist4/ || : )
   apt install $(pvcat $ulist4) # install what could potentially had been removed
   
   rm -rv $ulist $ulist4

  ;;
 esac
}

main

diff <(awk '$2=="install"{print $1}' $pfl | 
       awk -F: '{print $1}') <(dpkg --get-selections | awk '$2=="install"{print $1}' |
                               awk -F: '{print $1}') # print what packages you have gained and lost for your review

dpkg -l $(awk '$1=="'$(date +%Y-%m-%d)'" && $3=="remove" {print $4}' /var/log/dpkg.log | awk -F: '{print $1}' | sort -u ) | fgrep -wv ii


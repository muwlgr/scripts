
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

debmir=http://debian.volia.net/debian

arch='x'
case $(uname -m) in
 i686) arch=686 ;;
 x86_64) arch=amd64 ;;
esac

pfl=pkg-noble.tmp
aapkg=aapkg-noble.tmp

main(){ # called recursively for upgrade without reboot
 type lsb_release || apt install lsb-release
 case $(lsb_release -sc) in
  noble)
   olddistro=noble
   # save package lists and states
   [ -f $pfl ] || dpkg --get-selections > $pfl
   [ -f $aapkg ] || apt-mark showauto | sed 's/:.*//' | sort -u > $aapkg

   # revert some ubuntu customizations
   find /etc/profile.d -type f | xargs grep -l '^eval .*locale-check' | while read l
   do sed -r -i '/^ *eval .*locale-check/s/^/#/' $l
   done
   apt remove $(dpkg -l | egrep -i 'appstream|fcitx|zjs|gnome-|abiword|gnumeric|manpages|mailcap|mime-support|usb-creator|fwupd|transmission|plym|audacious|xf[bc]|system-config|indicator|firefox|gdebi|language-pack|linux-firmware|gstreamer-plugins|pulse|chromaprint|freerdp|pidgin|purple|gudev|[ b]gconf|nmap|lib(input|wacom|qt)|ry-cu' | awk '{print $2}' )
   apt purge $(dpkg -l | egrep -i ' (ubuntu-advantage-tools|snapd) ' | awk '{print $2}')
   apt autoremove

   distro=trixie
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

   flist=$(mktemp)
   ulist=$(mktemp -d)
   dpkg -l | grep -v base-files > $flist
   awk '$1=="ii"{print $2,$3}' $flist | # list all we have
   while read pp ubuv # for every installed package
   do [ -f $ulist/$pp ] && continue
      apt-cache show $pp | awk '$1=="Version:" && $2!="'$ubuv'" {print $2}' | sort -V | tail -n1 | # find its Debian upgrade version
      while read debv
      do echo $debv > $ulist/$pp # record this version to be installed for this package name
      done
   done

   mlist=$(mktemp) # install some debian&hardware-specific pkgs
   lspci | grep -i realtek && echo firmware-realtek >> $mlist
   lspci | grep -i atheros && echo firmware-atheros >> $mlist
   lspci | egrep -i 'vga.*(intel|nvidia)' && echo firmware-misc-nonfree >> $mlist
   dpkg -l | grep -i linux-header && echo linux-headers-$arch >> $mlist
   echo linux-image-$arch >> $mlist

   apt install $(cd $ulist 
                 for p in * 
                 do echo $p=$(cat $p)
                 done) $(cat $mlist) ||
   apt -f install
   apt autoremove
   rm -rv $flist $ulist $mlist

   debian_quick_upgrade $olddistro $distro $arch $debmir 
   apt remove $(dpkg -l | egrep -i 'ubuntu-|n(et)?plan' | awk '{print $2}' )
   apt autoremove
   main
  ;;
  trixie)
   apt upgrade || apt -f install
   apt autoremove
   apt dist-upgrade 
   apt autoremove
  ;;
 esac
}

main

diff <(awk '$2=="install"{print $1}' $pfl | 
       awk -F: '{print $1}') <(dpkg --get-selections | awk '$2=="install"{print $1}' |
                               awk -F: '{print $1}') # print what packages you have gained and lost for your review

dpkg -l $(awk '$1=="'$(date +%Y-%m-%d)'" && $3=="remove" {print $4}' /var/log/dpkg.log | awk -F: '{print $1}' | sort -u ) | fgrep -wv ii


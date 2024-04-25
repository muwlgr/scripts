
gen_debian_list() { # $1 - deb or deb-src, $2 - mirror URL, $3 - suite name , $4 - sections , $5 - sec.upd. url/path
 { for i in $3 $3-updates 
   do echo $1 $2 $i $4
   done
   echo $1 $5 $4
 } > /etc/apt/sources.list.d/$3.list
 apt update
}

gen_debian_list_bookworm() { # $1 - deb or deb-src, $2 - mirror URL, $3 - distro name
 gen_debian_list $1 $2 $3 'main contrib non-free non-free-firmware' 'http://security.debian.org/debian-security '$3'-security' # added section non-free-firmware
}

drop_sources() { # $1 - distro name
 find /etc/apt/sources* -type f -iname '*.list' | xargs grep -l '^ *deb .* '$1 | while read l
 do sed -r -i '/^ *deb/s/^/#/' $l # disconnect from specified repos
 done
}

debian_quick_upgrade(){ # $1 - old distro, $2 - new distro , $3 - arch , $4 - debmir
 drop_sources $1
 gen_debian_list_$2 deb $4 $2
 apt install apt dpkg
 apt update
 type lspci || apt install pciutils
 lspci | grep -i realtek && apt install firmware-realtek
 lspci | grep -i atheros && apt install firmware-atheros
 lspci | egrep -i 'vga.*(intel|nvidia)' && apt install firmware-misc-nonfree
 dpkg -l | grep -i linux-header && apt install linux-headers-$3
 apt install $(dpkg -l | egrep 'ii *(openssh-server|network-manager|initramfs-tools|libc6|locales|systemd|resolv|login|passwd|util-linux|sudo)' | awk '{print $2}') linux-image-$3 # upgrade important pkgs
 [ -f /lib/systemd/systemd-resolved ] || apt install systemd-resolved
 [ -f /lib/systemd/systemd-timesyncd ] || apt install systemd-timesyncd
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

pfl=pkg-bionic.tmp
aapkg=aapkg-bionic.tmp

main(){ # called recursively for upgrade without reboot
 type lsb_release || apt install lsb-release
 case $(lsb_release -sc) in
  jammy) 
   dpkg --get-selections > $pfl
   apt-mark showauto | sed 's/:.*//' | sort -u > $aapkg

   apt remove $(dpkg -l | egrep -i 'appstream|fcitx|zjs|gnome-|abiword|gnumeric|manpages|mailcap|mime-support|usb-creator|fwupd|transmission|audacious|xf[bc]|system-config|indicator|firefox|gdebi|language-pack|linux-firmware|gstreamer-plugins|light|pulse|chromaprint|freerdp|pidgin|purple|gudev|[ b]gconf|nmap|lib(input|wacom|qt)' | awk '{print $2}' ) pinentry-curses 
   apt autoremove
   apt install $(dpkg -l | egrep '^ii (.*[ou]code|locales)' | awk '{print $2}') #keep amd64-microcode intel-microcode iucode-tool
   dpkg-reconfigure locales
   apt autoremove
   find /etc/profile.d -type f | xargs grep -l '^eval .*locale-check' | while read l
   do sed -r -i '/^ *eval .*locale-check/s/^/#/' $l
   done
   apt purge $(dpkg -l | egrep -i ' (ubuntu-advantage-tools|snapd) ' | awk '{print $2}')

   distro=bookworm
   dpkg -l | grep '^ii *debian-archive-keyring ' || {
    set -- $(wget -O - https://packages.debian.org/$distro/all/debian-archive-keyring/download | grep -io 'http.*all\.deb' | sort -u) # get package name from its DL page
    wget $1
    dpkg -i $(basename $1)
   }

   drop_sources jammy
   gen_debian_list_$distro deb $debmir $distro # some downgrades before quick upgrade
   dpkg -l | egrep -i '(grub|shim).*-signed .*ubuntu.*' && { # downgrade grub&shim signed pkgs
    apt install grub-efi-amd64-signed=1+2.06+13+deb12u1 shim-signed=1.39+15.7-1 shim-signed-common=1.39+15.7-1 ||
    apt -f install
   }
   ubuv='12.3.0-1ubuntu1~22.04'
   debv='12.2.0-14'
   apt install $(dpkg -l | awk '$3=="'$ubuv'"{print $2"='$debv'"}') || apt -f install # downgrade gcc from Jammy to BookWorm
   dpkg -l | grep systemd.*249 && apt install systemd-resolved
   
   debian_quick_upgrade jammy $distro $arch $debmir 
   apt remove $(dpkg -l | egrep -i 'ubuntu-|n(et)?plan' | awk '{print $2}' )
   apt autoremove
   main
  ;;
  bookworm)
   apt install $(dpkg -l | egrep 'ii *(acpid)' | awk '{print $2}')
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


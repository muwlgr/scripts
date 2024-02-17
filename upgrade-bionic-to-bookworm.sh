
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

gen_debian_list_bullseye() {
 gen_debian_list $1 $2 $3 'main contrib non-free' 'http://security.debian.org/debian-security '$3'-security' # changed sec.upd. url/path
}

gen_debian_list_buster() {
 gen_debian_list $1 $2 $3 'main contrib non-free' 'http://security.debian.org/ '$3'/updates'
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
 apt install $(dpkg -l | egrep 'ii *(openssh-server|network-manager|initramfs-tools|locales|systemd|resolv|login|passwd|util-linux|sudo)' | awk '{print $2}') linux-image-$3 # upgrade important pkgs
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
  bionic) 
   dpkg --get-selections > $pfl
   apt-mark showauto | sed 's/:.*//' | sort -u > $aapkg

   apt remove $(dpkg -l | egrep -i 'appstream|apport|fcitx|zjs|fonts-|gnome-|abiword|gnumeric|keyutils|manpages|usb-creator|fwupd|transmission|audacious|xf[bc]|system-config|indicator|firefox|gdebi|language-pack|linux-firmware|gstreamer-plugins|light|lx|pulse|chromaprint|freerdp|pidgin|purple|gudev|[ b]gconf|cups|python|nmap' | awk '{print $2}' ) ttf-bitstream-vera foomatic-filters pinentry-curses
   apt install $(dpkg -l | egrep '^ii (.*[ou]code|locales)' | awk '{print $2}') #keep amd64-microcode intel-microcode iucode-tool
   dpkg-reconfigure locales
   apt autoremove
   find /etc/profile.d -type f | xargs grep -l '^eval .*locale-check' | while read l
   do sed -r -i '/^ *eval .*locale-check/s/^/#/' $l
   done
   apt purge ubuntu-advantage-tools snapd

   distro=buster
   set -- $(wget -O - https://packages.debian.org/$distro/all/debian-archive-keyring/download | grep -io 'http.*all\.deb' | sort -u) # get package name from its DL page
   wget $1
   dpkg -i $(basename $1)

   debian_quick_upgrade bionic $distro $arch $debmir
   apt remove $(dpkg -l | egrep -i 'ubuntu-|n(et)?plan' | awk '{print $2}' )
   apt autoremove
   main
  ;;
  buster)
   debian_quick_upgrade buster bullseye $arch $debmir
   main
  ;;
  bullseye)
   debian_quick_upgrade bullseye bookworm $arch $debmir
   reboot # this time, don't call main recursively
  ;;
  bookworm)
   apt install $(dpkg -l | egrep 'ii *(acpid)' | awk '{print $2}')
   apt upgrade
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



gen_debian_list() { # $1 - deb or deb-src, $2 - mirror URL, $3 - suite name , $4 - sections , $5 - sec.upd. url/path
 { for i in $3 $3-updates
   do echo $1 $2 $i $4
   done
   [ "$5" ] && echo $1 $5 $4
 } > /etc/apt/sources.list.d/$3.list
 apt update
}

gen_debian_list_stable(){ # trixie now
 easl=/etc/apt/sources.list
 dakr=/usr/share/keyrings/debian-archive-keyring.gpg
 mcnnf="main contrib non-free non-free-firmware"
 edcs=$easl.d/$3.sources
 [ -f $edcs ] || echo "Types: $1
URIs: $2
Suites: $3 $3-updates
Components: $mcnnf
Signed-By: $dakr

Types: $1
URIs: http://security.debian.org/debian-security
Suites: $3-security
Components: $mcnnf
Enabled: yes
Signed-By: $dakr" > $edcs
 apt update
}

gen_debian_list_bookworm() { # $1 - deb or deb-src, $2 - mirror URL, $3 - distro name
 gen_debian_list $1 $2 $3 'main contrib non-free non-free-firmware' 'http://security.debian.org/debian-security '$3'-security' # added section non-free-firmware
}

gen_debian_list_bullseye() {
 gen_debian_list $1 $2 $3 'main contrib non-free' 'http://security.debian.org/debian-security '$3'-security' # changed sec.upd. url/path
}

gen_debian_list_buster() {
 gen_debian_list $1 $2 $3 'main contrib non-free'
}

drop_sources() { # $1 - distro name
 find /etc/apt/sources* -type f -iname '*.list' | xargs grep -l '^ *deb .* '$1 | while read l
 do sed -r -i '/^ *deb/s/^/#/' $l # disconnect from specified repos
 done
}

debian_quick_upgrade(){ # $1 - old distro, $2 - new distro , $3 - arch , $4 - debmir
 later=$(iigrep '(openssh|network-manager|initramfs-tools|klibc|locales|systemd|resolv|login|passwd|util-linux|sudo)')
 drop_sources $1
 gen_debian_list_$2 deb $4 $2
 apt install apt dpkg
 apt update
 type lspci || apt install pciutils
 lspci | grep -i realtek && apt install firmware-realtek
 lspci | grep -i atheros && apt install firmware-atheros
 lspci | egrep -i 'vga.*(intel|nvidia)' && apt install firmware-misc-nonfree
 apt install $later linux-image-$3 # upgrade important pkgs
 [ -f /lib/systemd/systemd-resolved ] || apt install systemd-resolved
 [ -f /lib/systemd/systemd-timesyncd ] || apt install systemd-timesyncd
 apt install $(iigrep '(base-files|lsb-release)') # bump lsb_release version
 apt autoremove
# reboot
}

iigrep(){ dpkg -l | egrep -i '^ii +('"$1"')' | awk '{gsub(/:[^:]*/,"",$2);print $2}' # $1 - egrep regexp
        }

pkgfilter(){ awk '$2=="install"{print $1}' | sed 's/:.*//' | sort -u # stdin: output of dpkg --get-selections
           }

newv(){  ( set +x # stdin: list of packages, 1 per line , $1 - distro name
           while read pp
           do ubuv=$(dpkg -l $pp | awk '$2~/'$pp'(:[^ ])?/ {print $3}')
              debv=$(apt-cache showpkg $pp | egrep $1'.*Packages' | grep -v '^ ' | sed 's/ (.*//' | sort -V | tail -n1)
              [ "$debv" ] && [ "$debv" != "$ubuv" ] && echo $pp=$debv
           done )
      }


defdebmir=http://debian.volia.net/debian
debmir=$(awk '$1=="deb"{if ($2 in a) a[$2]+=1 ; else a[$2]=1} END {for (i in a) print a[i]" "i}' /etc/apt/sources.list | sort -n | tail -n1 | awk '{print $2}')
if [ "$debmir" ] && echo $debmir | grep '^http.*//'
then echo $debmir | grep '[a-z]/ubuntu'     && debmir=$(echo $debmir | sed -r 's ([a-z])/ubuntu \1/debian ')
     echo $debmir | fgrep ua.archive.ubuntu && debmir=$(echo $debmir | sed 's/ua.archive.ubuntu.com/debian.volia.net/')
     wget --spider $debmir/dists/stable/Release || debmir=$defdebmir
else debmir=$defdebmir
fi

arch='x'
case $(uname -m) in
 i686) arch=686 ;;
 x86_64) arch=amd64 ;;
esac

pfl=pkg-bionic.tmp
aapkg=aapkg-bionic.tmp

main(){ # called recursively for upgrade without reboot
 type lsb_release || apt install lsb-release
 distro=$(lsb_release -sc)
 case $distro in
  bionic)
   [ -f "$pfl" ] || dpkg --get-selections > $pfl
   [ -f "$aapkg" ] || apt-mark showauto | sed 's/:.*//' | sort -u > $aapkg

#   apt remove $(dpkg -l | egrep -i 'appstream|apport|fcitx|zjs|fonts-|gnome-|abiword|gnumeric|keyutils|manpages|usb-creator|fwupd|transmission|audacious|xf[bc]|system-config|indicator|firefox|gdebi|language-pack|linux-firmware|gstreamer-plugins|light|lx|pulse|chromaprint|freerdp|pidgin|purple|gudev|[ b]gconf|cups|python|nmap' | awk '{print $2}' ) ttf-bitstream-vera foomatic-filters pinentry-curses
   apt install $(iigrep '(.*[ou]code|locales)') usrmerge #keep amd64-microcode intel-microcode iucode-tool
   apt autoremove
   find /etc/profile.d -type f | xargs grep -l '^eval .*locale-check' | while read l
   do sed -r -i '/^ *eval .*locale-check/s/^/#/' $l
   done
   apt purge $(iigrep 'ubuntu-advantage-tools|snapd|apparmor|appstream|apport|linux-firmware|ubuntu-docs|libsane-hpaio')
   apt remove $(iigrep '.*(abiword|gnumeric|farstream|gudev|gvfs|mtp|plym|pulse|sensors|ureadah|audacious|language-|(fire|ubu)fox|libqt|icon-them|ufw|lxl|usb(ut|-crea)|whoop|ot-db|it-de|locate|fetch|ub-gf).*') pinentry-curses
   dpkg-reconfigure locales

   dpkg -l debian-archive-keyring || { set -- $(wget -O - https://packages.debian.org/stable/all/debian-archive-keyring/download | grep -io 'http.*all\.deb' | egrep -iv '\.(br|za)' | sort -u) # get package name from its DL page
                                       wget $1
                                       dpkg -i $(basename $1)
                                     }

   debian_quick_upgrade $distro buster $arch http://archive.debian.org/debian
   [ "$(iigrep netplan)" ] && if [ "$(iigrep network-manager)" ] # prepare to drop netplan
                              then ( cd /run/NetworkManager/conf.d/
                                     ls * && cp -av * /etc/NetworkManager/conf.d/ ) # copy generated configs to NetworkManager
                              else ( cd /run/systemd/network/ # copy generated configs to networkd
                                     ls * && cp -av * /etc/systemd/network/ )
                                   systemctl is-enabled systemd-networkd || systemctl enable systemd-networkd
                              fi

   apt remove $(iigrep 'apparmor|.*(ubuntu-|n(et)?plan|hwe|hplip|hpaio).*')
   apt autoremove
   sync
   sync
   sync
   reboot -f
  ;;
  buster)
   debian_quick_upgrade buster bullseye $arch $debmir
   main
  ;;
  bullseye)
   debian_quick_upgrade bullseye bookworm $arch $debmir
   main
  ;;
  bookworm)
   debian_quick_upgrade bookworm stable $arch $debmir
   reboot # this time, don't call main recursively
  ;;
  trixie)
   type aptitude || apt install aptitude
   apt remove $(aptitude search '~o' | sed 's/ *- .*//;s/.* //' | egrep -iv 'lubuntu|ubuntu-mono|policykit') $(iigrep 'binutils |aptitude|usrmerge')
   apt dist-upgrade
   [ -f "$pfl" ] && { sed -i 's/-hwe-18.04\s/ /' $pfl
                      apt install $(comm -23 <(pkgfilter < $pfl) <(dpkg --get-selections | pkgfilter) | fgrep -v gpg-wks-server | newv stable) # gpg-wks-server pulls in mailx and exim (!)
                      apt remove  $(comm -13 <(pkgfilter < $pfl) <(dpkg --get-selections | pkgfilter) | egrep -i 'exim|iperf|op-ba')
                    }

   apt autoremove
  ;;
 esac
}

main

diff <(pkgfilter < $pfl) <(dpkg --get-selections | pkgfilter) # print what packages you have gained and lost for your review


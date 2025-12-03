set -x -e

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
 grep -lw $1 /etc/apt/sources*/*.sources | while read l 
 do mv $l $l.disabled
 done
}

newv(){ # stdin: list of packages, 1 per line , $1 - distro name
 ( set +x 
   while read pp
   do ubuv=$(dpkg -l $pp | awk '$2~/'$pp'(:[^ ])?/ {print $3}')
      debv=$(apt-cache showpkg $pp | egrep $1'.*Packages' | grep -v '^ ' | sed 's/ (.*//' | sort -V | tail -n1)
      [ "$debv" ] && [ "$debv" != "$ubuv" ] && echo $pp=$debv
   done )
}

iigrep(){ # $1 - egrep regexp
 dpkg -l | egrep -i '^ii +('"$1"')' | awk '{gsub(/:[^:]*/,"",$2);print $2}'
}

reinstall_so(){ # $1 - $solist, $2 - package list with versions pkg=ver
 [ "$2" ] || return 0
 apt install $2 || : # this may fail due to improperly removed .so libs
 missing_so="$( cd /var/lib/dpkg/info
                grep -h bin/ *list | xargs file | awk -F: '/ELF.*dyn.*link/{print $1}' | sort -u | # find ELF dynamic linkec executables
                xargs ldd | grep 'not found' | awk '{print $1}' | sort -u )" # find what .so libs they are lacking

 [ "$missing_so" ] || return 0
 pkgl2=$( dpkg -l | fgrep -f <(fgrep -f <(echo "$missing_so") $1 | sed 's/\.list:.*//;s/.*\///;s/:.*//;s/t64//' | sort -u) | # find what packages they should be in
          awk '{print $2}' | awk -F: '{print $1}' | sort -u)
 [ "$pkgl2" ] || return 0
 apt reinstall $pkgl2 
}

arch='x'
case $(uname -m) in
 i686) arch=686 ;;
 x86_64) arch=amd64 ;;
esac

debmir=$(find /etc/apt/sources.list* -type f | xargs awk '$1=="deb" && $3~/'$olddistro'/{print $2}' | sort -u | fgrep -v ubuntu.com | sed 's/ubuntu/debian/g'
         # or add echo $your own mirror and comment out the line above, else you would get errors everywhere
         )
set -- $debmir
[ $# -eq 1 ] || debmir=http://debian.volia.net/debian
olddistro=jammy
distro=bookworm # fill missing pkgs from Bookworm
pfl=$(pwd)/pkg-$olddistro.tmp
aapkg=$(pwd)/aapkg-$olddistro.tmp
flist=$(pwd)/dpkg-$olddistro.tmp
solist=$(pwd)/solibs-$olddistro.tmp

main(){ # called recursively for upgrade without reboot
 type lsb_release || apt install lsb-release
 case $(lsb_release -sc) in
  $olddistro)
   # save package lists and states
   [ -f $pfl ] || dpkg --get-selections > $pfl
   [ -f $aapkg ] || apt-mark showauto | sed 's/:.*//' | sort -u > $aapkg
   [ -s $flist ] || dpkg -l > $flist

   # revert some ubuntu customizations
   dpkg -l | egrep -i '^ii +language-pack' && ls /var/lib/locales/supported.d/* && sort -u /var/lib/locales/supported.d/* | grep '^[A-Za-z]' > /tmp/locale.gen
   find /etc/profile.d -type f | xargs grep -l '^eval .*locale-check' | while read l
   do sed -r -i '/^ *eval .*locale-check/s/^/#/' $l
   done
   ( cd /etc
     for i in passwd group shadow gshadow
     do grep '^gdm:' $i && ! grep '^Debian-gdm:' $i && echo Debian-$(grep '^gdm:' $i) >> $i || : # debian gdm3 hack
     done )

   dpkg -l | egrep -i '^ii +snapd .*build' && snap remove firefox snapd-desktop-integration # this damned crap prevents snapd from being purged
   apt purge $(iigrep '(ubuntu-(advantage-tools|pro-client)|(apparmor|plasma-welcome|libplymouth5).*ubuntu.*) ') 
   apt remove $(iigrep '(.*(appstream|app-config-icons|printer-driver|xrender)).* .*build|(.*(baloowidget|pg-agent|libreoffice|uno-libs|flac|glib2|fontconfig|activi|kwayland)).* .*ubuntu|.*(ge-pa|xorg)')
   [ -s /tmp/locale.gen ] && {
    comm -23 /tmp/locale.gen <(grep '^[A-Za-z]' /etc/locale.gen | sort -u) >> /etc/locale.gen
    tail /etc/locale.gen
   }
   apt autoremove

   dpkg -l | egrep '^ii +network-manager' || { # prepare to drop netplan
    dpkg -l | egrep -i '^ii +netplan' && {
     ls -l /etc/systemd/network/* || cp -av /run/systemd/network/* /etc/systemd/network/ || :
     systemctl is-enabled systemd-networkd || systemctl enable systemd-networkd 
    }
   }

   dpkg -l | grep '^ii *debian-archive-keyring .*2023' || {
    set -- $(wget -O - https://packages.debian.org/$distro/all/debian-archive-keyring/download | grep -io 'http.*all\.deb' | sort -u) # get package name from its DL page
    wget $1
    dpkg -i $(basename $1)
   }

   apt remove $(iigrep 'appstream|fcitx|zjs|gnome-|abiword|gnumeric|manpages|mailcap|mime-support|usb-creator|fwupd|transmission|audacious|xf[bc]|system-config|indicator|firefox|gdebi|language-pack|linux-firmware|gstreamer-plugins|light|pulse|chromaprint|freerdp|pidgin|purple|gudev|[ b]gconf|nmap|lib(input|wacom|qt|ry-cu)' ) 
   apt autoremove
   apt install $(iigrep '.*[ou]code|locales') #keep amd64-microcode intel-microcode iucode-tool
   dpkg-reconfigure locales
   apt autoremove
   find /etc/profile.d -type f | xargs grep -l '^eval .*locale-check' | while read l
   do sed -r -i '/^ *eval .*locale-check/s/^/#/' $l
   done
   apt purge $(dpkg -l | egrep -i ' (ubuntu-advantage-tools|snapd) ' | awk '{print $2}')

   drop_sources $olddistro
   gen_debian_list_$distro deb $debmir $distro # some downgrades before quick upgrade
   set -- $(iigrep mysql-server)
   [ $# -gt 0 ] && wget https://repo.mysql.com//mysql-apt-config_0.8.36-1_all.deb
   
   grep '^ii *eatmydata' $flist && apt install eatmydata
   [ -f $solist ] || ( cd /var/lib/dpkg/info 
                       egrep '\.so(\.|$)' *.list ) > $solist
   apt install $(iigrep 'apt|dpkg|gzip' | newv $distro)
   apt install $(iigrep 'shim-signed .*ubuntu' | newv $distro) || apt -f install
   apt autoremove
   apt download libapt-pkg6.0
   apt install $(iigrep 'libapt.*t64' | sed 's/t64//' | newv $distro) # here we may lose libapt-pkg*.so, but reinstall_so would not help as it uses apt inside
   apt help || { dpkg -i libapt-pkg*deb # dirty little fix
                 rm -v libapt-pkg*deb 
               }
   apt update
   reinstall_so $solist "$(iigrep '.*' | grep -v base-files | newv $distro)"
   reinstall_so $solist "$(iigrep '.*' | grep -v base-files | newv $distro)" # this may need to be restarted to upgrade remaining pkgs
   reinstall_so $solist "$(iigrep '.*t64.* ' | sed 's/t64//' | newv $distro)" # downgrade Trixie t64 libs to Bookworm's non-t64
   apt install $(iigrep 'base-files' | newv $distro) # finally install base-files
   [ -f mysql-apt-config*.deb ] && { apt install gnupg
                                     dpkg -i mysql-apt-config*.deb
                                     apt update
                                   }
   apt remove $(iigrep '(n(et)?plan.*ubuntu|.*(ubuntu|pd-si|op-pr|ub-gf)|(libaio|secureboot).* .*build)' | grep -v yaru )
   apt autoremove
   main
  ;;
  $distro)
   apt install $(for i in $(comm -23 <(grep '^ii ' $flist | egrep -v 'kf5kdelibs|libldb|libsmb|linux-gnu|t64' | awk '{print $2}' | awk -F: '{print $1}' |
                                       sort -u) <(dpkg -l | grep '^ii ' | awk '{print $2}' | awk -F: '{print $1}' | sort -u)) 
                 do apt-cache showpkg $i | egrep -qi $distro && echo $i 
                 done) # reinstall all pkgs removed from Ubuntu which have Debian equivalent
   apt install $( pci=$(mktemp)
                  lspci > $pci
                  grep -iq realtek $pci && echo firmware-realtek 
                  grep -iq atheros $pci && echo firmware-atheros 
                  grep -iq 'intel.*wifi' $pci && echo firmware-iwlwifi 
                  egrep -iq 'vga.*(intel|nvidia)' $pci && echo firmware-misc-nonfree 
                  egrep -iq 'intel.*sound'  $pci && echo firmware-sof-signed 
                  rm $pci
                  grep -iq '^ii *linux-header' $flist && echo linux-headers-$arch 
                  grep -iq '^ii *firefox .*snap.*ubuntu.*' $flist && echo firefox-esr 
                  echo linux-image-$arch 
                  grep -q '^ii *gnome-session-bin ' $flist && echo gnome-session )
   apt remove $( for i in $(dpkg -l | grep '^ii *.*'$(uname -r) | awk '{print $2}') 
                 do apt-cache showpkg $i | egrep -iq $distro || echo $i 
                 done ) # and ubuntu's running kernel
   re='bzip2|ptitu|exfat|exim|2-ma|me-(br|sh|so)|cp-co|on-th|d2-pl|ev-cr|or-0-pl|ls-bi|td-pk|io-ut|n3-(ke|ren|sm|uri|web)|md-co|ib-me|lynx|perl-tk|sy-rs|pcscd|realmd|rtmp|wayland|foomatic|paps|pinentry|gstream.*(ugly|libav|qt5)| (tk[0-9.]+|tix) '
   apt remove $(comm -23 <(dpkg -l | egrep -i "$re" | awk '$1=="ii"{print$2}' | awk -F: '{print $1}' |
                           sort -u) <(egrep -i "$re" $flist | awk '$1=="ii"{print$2}' | awk -F: '{print $1}' |
                                      sort -u)) # clean after Debian
   apt autoremove
   apt dist-upgrade 
  ;;
 esac
}

main

diff <(awk '$2=="install"{print $1}' $pfl | 
       awk -F: '{print $1}') <(dpkg --get-selections | awk '$2=="install"{print $1}' |
                               awk -F: '{print $1}') # print what packages you have gained and lost for your review

dpkg -l $(awk '$1=="'$(date +%Y-%m-%d)'" && $3=="remove" {print $4}' /var/log/dpkg.log | awk -F: '{print $1}' | sort -u ) | fgrep -wv ii


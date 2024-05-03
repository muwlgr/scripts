
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

pvcat(){ # $1 - folder
 cd $1 
 for p in $(ls)
 do echo $p=$(cat $p)
 done
}

arch='x'
case $(uname -m) in
 i686) arch=686 ;;
 x86_64) arch=amd64 ;;
esac

debmir=http://debian.volia.net/debian

distro=trixie
olddistro=noble
pfl=$(pwd)/pkg-$olddistro.tmp
aapkg=$(pwd)/aapkg-$olddistro.tmp
flist=$(pwd)/dpkg-l.tmp
ulist=$(pwd)/$distro-pkgv.tmp
[ -d $ulist ] || mkdir -p $ulist

main(){ # called recursively for upgrade without reboot
 type lsb_release || apt install lsb-release
 case $(lsb_release -sc) in
  $olddistro)
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

   dpkg -l | egrep -i '^ii +snapd .*build' && snap remove firefox snapd-desktop-integration # this damned crap prevents snapd from being purged
   eb=$(pwd)/etc-$olddistro.tar.gz
   ( cd /var/lib/dpkg/info # resolve apparmor problems once and for all
     fl=$(mktemp)
     ls *conffiles | grep -v apparmor | xargs grep -il apparmor | xargs grep -h . | sort -u > $fl
     [ -s $fl ] && {
      [ -f $eb ] && mv -v $eb $eb.bak || :
      tar -T $fl -czvf $eb
      rm -v $fl
     } || :
     apt purge $(dpkg -l | egrep -i '^ii +(ubuntu-(advantage-tools|pro-client)|(apparmor|plasma-welcome).*ubuntu.*) ' | awk '{print $2}') $(ls *conffiles | grep -v apparmor | xargs grep -il apparmor | awk -F. '{print $1}')
   )
   apt remove $(dpkg -l | egrep -i '^ii +((snapd|.*on-data-server|libwinpr.*t64.*) .*build|((konversation|libkf5(baloowidgets|holidays|kdegames))-data|gnome-control).*ubuntu|(ubuntu|gnome-user)-docs|language-(pack|select)|.*(pd-si|gphoto|gutenprint|op-pr|ot-db|sb-cr|eo-qx|ly-re))' | awk '{print $2}')
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

   
   awk '$1=="ii"{gsub(/:[^:]*/,"",$2);print $2,$3}' $flist | sort -u | # all we had initially
   ( cd $ulist
     while read pp ubuv # for every installed package
     do [ -f $pp ] && continue
        apt-cache showpkg $pp | grep $distro'.*Packages' | grep -v '^ ' | sed 's/ (.*//' | sort -V | tail -n1 | # find its Debian upgrade version
        while read debv
        do [ $debv = $ubuv ] || echo $debv > $pp # record this version to be installed for this package name
        done
     done ) # so in $ulist we have only packages which have Debian version

   ulist0=$(mktemp -d) # apt & dpkg
   ( cd $ulist 
     [ -f apt-utils ] || cp -av apt apt-utils # install apt-utils of the same version as apt
     mv -v $(ls apt* dpkg* *eatmydata* ) $ulist0/ ) # upgrade them first
   apt install $(pvcat $ulist0) # upgrade apt and dpkg
   rm -rv $ulist0
   apt update # rebuild package DB with updated apt

   ulist05=$(mktemp -d)
   ( cd $ulist
     ls *shim-signed* && mv *shim-signed* $ulist05/ ) # separate upgrade of shim-signed
   apt install $(pvcat $ulist05) || apt -f install # restart apt on unpacking conflict
   rm -rv $ulist05

   ulist2=$(mktemp -d) # libc6 & locales
   ( cd $ulist 
     mv -v $(ls libc6* libc-* locales cloud*) $ulist2/ # postpone breaking upgrade of libc6+locales
     [ -f gdm3 ] && ln -v gdm3 $ulist2/ || : ) # also prevent gdm3 from being removed
   ulist3=$(mktemp -d) # base-files
   ( cd $ulist
     mv -v base-files $ulist3/ ) # postpone breaking upgrade of base-files

   mlist=$(mktemp) # install some debian&hardware-specific pkgs
   lspci | grep -i realtek && echo firmware-realtek >> $mlist
   lspci | grep -i atheros && echo firmware-atheros >> $mlist
   lspci | grep -i 'intel.*wifi' && echo firmware-iwlwifi >> $mlist
   lspci | egrep -i 'vga.*(intel|nvidia)' && echo firmware-misc-nonfree >> $mlist
   grep -i '^ii *linux-header' $flist && echo linux-headers-$arch >> $mlist
   grep -i '^ii *firefox .*snap.*ubuntu.*' $flist && echo firefox-esr >> $mlist
   echo linux-image-$arch >> $mlist
   grep 'ii *gnome-session-bin ' $flist && echo gnome-session >> $mlist

   apt install $(pvcat $ulist) $(cat $mlist) # main upgrade
   rm -rv $ulist $mlist
   apt install $(for i in $(dpkg -l | egrep '^ii +lib.*t64.*(ubuntu|build)' | awk '{print $2}' | sed 's/t64.*//') # some Noble t64 libs need to be downgraded to Trixie non-t64
                 do apt-cache showpkg $i | grep -qi $distro && echo $i
                 done)
   [ -s /tmp/locale.gen ] && {
    comm -23 /tmp/locale.gen <(grep '^[A-Za-z]' /etc/locale.gen | sort -u) >> /etc/locale.gen
    tail /etc/locale.gen
   }
   apt remove $(dpkg -l | egrep -i '^ii +n(et)?plan.*ubuntu|ubuntu-' | awk '{print $2}' )
   apt install $(pvcat $ulist2) # dangerous upgrades of libc6/locales
   rm -rv $ulist2
   apt install $(pvcat $ulist3) # dangerous upgrade of base-files
   rm -rv $ulist3
   main # restart upgrade for trixie
  ;;

  $distro)

   apt update # for new packages on repeated runs
   apt remove $(dpkg -l | egrep -i '^ii +([^ ]+ +[^ ]*ubuntu[^ ]* |.*ub-gf)' | awk '{print $2}' # remove leftover ubuntu pkgs
                for i in $(dpkg -l | grep '^ii *.*'$(uname -r) | awk '{print $2}') 
                do apt-cache showpkg $i | grep -iq $distro || echo $i 
                done) # and ubuntu's running kernel
   apt dist-upgrade 
   apt install $(for i in $(comm -23 <(grep '^ii ' $flist | awk '{print $2}' |
                                       awk -F: '{print $1}') <(dpkg -l | grep '^ii ' | awk '{print $2}' |
                                                               awk -F: '{print $1}') ) 
                 do apt-cache showpkg $i | grep -qi $distro && echo $i 
                 done)
   re='exim|apache|lynx|perl-tk|mailcap|sy-rs|pcscd|realmd| (tk[0-9.]+|tix) '
   apt remove $(comm -23 <(dpkg -l | egrep -i "$re" | awk '$1=="ii"{print$2}' | awk -F: '{print $1}' |
                           sort -u) <(egrep -i "$re" $flist | awk '$1=="ii"{print$2}' | awk -F: '{print $1}' |
                                      sort -u)) # clean after Debian
   apt autoremove
  ;;
 esac
}

main

comm -3 <(awk '$2=="install"{print $1}' $pfl | 
          awk -F: '{print $1}' | sort -u) <(dpkg --get-selections | awk '$2=="install"{print $1}' |
                                  awk -F: '{print $1}' | sort -u) # print what packages you have gained and lost for your review

dpkg -l $(awk '$1=="ii"{print $2}' $flist  | awk -F: '{print $1}' ) | fgrep -vw ii

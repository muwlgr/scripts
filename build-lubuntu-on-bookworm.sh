# build dependencies
apt install debhelper germinate dpkg-dev icon-naming-utils intltool gir1.2-rsvg-2.0 scour gpg 

getpgpkey(){ # $1 - fingerprint, $2 - keyserver, $3 - output file
 gpg --recv-keys --keyserver $2 $1
 gpg --output $3 --armour --export $1
}

# get Ubuntu keys and trust them
( cd /etc/apt/trusted.gpg.d/
  getpgpkey 3B4FE6ACC0B21F32 keyserver.ubuntu.com bionic.asc
  getpgpkey 871920D1991BC93C keyserver.ubuntu.com jammy.asc
)

# connect to bionic sources
set -- deb-src http://ua.archive.ubuntu.com/ubuntu bionic
{ for i in $3 $3-updates $3-security
  do echo $1 $2 $i main restricted universe multiverse
  done
} > /etc/apt/sources.list.d/$3.list

apt update
cd
# get bionic package sources 
apt source lubuntu-meta lubuntu-artwork lubuntu-default-settings

# patch them to remove unneeded dependencies
( cd lubuntu-meta-*
  sedprog='s/fcitx-config-gtk2/fcitx-config-gtk/;s/firefox$/firefox-esr/;s/leafpad/l3afpad/
           /abiword|gnumeric|gdebi|fwupdate|kerneloops|whoopsie|apport|indicator-|language-select|usb-creat|plymouth|gtk2-perl|ubuntu-(driver|release|font)|update-notifier|ubufox/d'
  { egrep -i '(seeds|architectures):' update.cfg | tr -d ':' | while read a b 
    do echo for $a in $b ';' do
    done
    echo echo '$seeds-$architectures'
    echo echo '$seeds-recommends-$architectures'
    echo done ';' done
  } | sh | while read fn
  do echo ---- $fn
     diff $fn <(sed -r "$sedprog" $fn) || sed -r -i "$sedprog" $fn
  done
)
( cd lubuntu-default-settings-*
  sed -i '/ubuntu-font/d' debian/control
)

#build bionic pkgs
for i in lubuntu-meta-* lubuntu-artwork-* lubuntu-default-settings-*
do ( cd $i
     dpkg-buildpackage -b )
done

# connect to jammy sources
sed 's/bionic/jammy/' /etc/apt/sources.list.d/bionic.list > /etc/apt/sources.list.d/jammy.list

apt update
# get jammy package sources 
apt source ubuntu-themes policykit-desktop-privileges

#build jammy pkgs
for i in ubuntu-themes-* policykit-desktop-privileges-*
do ( cd $i
     dpkg-buildpackage -b )
done

tar czf /tmp/lubuntu-bookworm.tgz lubuntu-desktop_*_*.deb lubuntu-gtk-core_*_*.deb lubuntu-gtk-desktop_*_*.deb lubuntu-artwork_*_*.deb lubuntu-artwork-18-04_*_*.deb lubuntu-lxpanel-icons_*_*.deb lubuntu-default-session_*_*.deb lubuntu-default-settings_*_*.deb lubuntu-icon-theme_*_*.deb ubuntu-mono_*_*.deb

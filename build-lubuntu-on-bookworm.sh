# build dependencies
apt install debhelper germinate dpkg-dev icon-naming-utils intltool gir1.2-rsvg-2.0 scour gpg 

getpgpkey(){ # $1 - fingerprint, $2 - keyserver, $3 - output file
 [ -f $3 ] || {
  gpg --recv-keys --keyserver $2 $1
  gpg --output $3 --armour --export $1
 }
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

#clean
for i in lubuntu-meta-* 
do [ -d $i ] && rm -rv $i
done

# get bionic package sources 
apt source lubuntu-meta 

# patch them to remove unneeded dependencies
( cd lubuntu-meta-*
  sedprog='s/firefox$/firefox-esr/;s/leafpad/l3afpad/;s/gnome-mpv/vlc/
           /abiword|gnumeric|gdebi|fcitx|fwupdate|kerneloops|whoopsie|apport|indicator-|language-select|usb-creat|plymouth|gtk2-perl|software-properties-|ubuntu-(driver|release)|update-notifier|ubufox/d'
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

#build bionic pkgs
for i in lubuntu-meta-* 
do ( cd $i
     dpkg-buildpackage -b --no-sign )
done

tar czvf /tmp/lubuntu-bookworm.tgz lubuntu-desktop_*_*.deb lubuntu-gtk-core_*_*.deb lubuntu-gtk-desktop_*_*.deb 
ls -lh /tmp/lubuntu-bookworm.tgz

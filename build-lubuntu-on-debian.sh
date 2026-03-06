# build dependencies

distro=bionic
[ $(lsb_release -sc) = $distro ] && { echo please upgrade to Debian first
                                      exit 1
                                    }
# Ubuntu 18.04 Bionic uses SHA1 sig.verif.algo obsoleted with current apt.
# so we create Ubuntu Bionic chroot and download LUbuntu source packages for rebuild and binary packages for install under Debian
target=/tmp/$distro
dbs=debootstrap
type $dbs || apt install $dbs
[ -d $target ] || mkdir -v $target
[ -f $target/etc/apt/sources.list.d/$distro.sources ] || $dbs $distro $target http://ua.archive.ubuntu.com/ubuntu
[ $(stat -c %d,%i /dev/null) = $(stat -c %d,%i $target/dev/null) ] || mount --bind /dev $target/dev # many programs require /dev/ files
fgrep -il proxy /etc/apt/apt.conf.d/* | while read f
do sudo cp -av $f $target/etc/apt/apt.conf.d/
done
beasl=$target/etc/apt/sources.list
set -- $(cat $beasl) # short sources.list from debootstrap
[ -f $beasl.d/$3.sources ] || { echo "Types: $1 $1-src
URIs: $2
Suites: $3 $3-updates
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: $1 $1-src
URIs: http://security.ubuntu.com/ubuntu
Suites: $3-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg" > $beasl.d/$3.sources # full sources in modern format
                                sed -i '/^ *deb/s/^/#/' $beasl
                              }

chroot $target sh -xc 'apt update
cd /tmp
mkdir debs
cd debs
apt download lubuntu-artwork lubuntu-artwork-18-04 lubuntu-default-session lubuntu-icon-theme lubuntu-lxpanel-icons
cd ..
mkdir src
cd src
apt --download-only source lubuntu-meta lubuntu-default-settings'
umount $target/dev

apt install debhelper germinate dpkg-dev icon-naming-utils intltool gir1.2-rsvg-2.0 scour gpg # build deps

( cd $target/tmp/src
#clean
  for i in lubuntu-meta-* lubuntu-default-settings-*
  do [ -d $i ] && rm -rv $i
  done

sedprog='s/firefox$/firefox-esr/;s/leafpad/l3afpad/;s/gnome-mpv/vlc/;s/ttf-ubuntu-font-family/fonts-ubuntu/
         /abiword|audacious|gnumeric|gdebi|fcitx|fwupdate|kerneloops|whoopsie|apport|indicator-|language-select|usb-creat|pidgin|plymouth|gtk2-perl|software-properties-|ubuntu-(driver|release)|update-notifier|ubufox/d'

  ( dpkg-source -x lubuntu-meta_*.dsc
    cd lubuntu-meta-*
# patch them to remove unneeded dependencies
    { egrep -i '(seeds|architectures):' update.cfg | tr -d ':' | while read a b
      do echo for $a in $b ';' do
      done
      echo echo '$seeds-$architectures'
      echo echo '$seeds-recommends-$architectures'
      echo done ';' done
    } | sh | while read fn
    do echo ---- $fn
       sed -r "$sedprog" $fn | diff $fn - || sed -r -i "$sedprog" $fn
    done
#build bionic pkgs
    dpkg-buildpackage -b --no-sign )

  ( dpkg-source -x lubuntu-default-settings_*.dsc
    cd lubuntu-default-settings-*
    fn=debian/control
    sed -r "$sedprog" $fn | diff $fn - || sed -r -i "$sedprog" $fn
    fn=src/etc/xdg/lubuntu/menus/lxde-applications.menu
    sedprog='s/system-tools/system/'
    sed -r "$sedprog" $fn | diff $fn - || sed -r -i "$sedprog" $fn
    dpkg-buildpackage -b --no-sign )
# replace selected downloaded debs with re-built debs
  mv -v lubuntu-default-settings_*_*deb lubuntu-desktop_*_*deb lubuntu-gtk*_*_*deb ../debs/ )

( cd $target/tmp/debs
  tar -czvf /tmp/lubuntu-debian.tgz lubuntu-desktop_*_*deb lubuntu-gtk*_*_*deb lubuntu-artwork*_*_*deb lubuntu-default*_*_*deb  lubuntu-icon-theme_*_*deb lubuntu-lxpanel*_*_*deb )

ls -lh /tmp/lubuntu-debian.tgz
echo please save the above file to copy it onto every other Debian on which you waht to recreate Lubuntu
rm -r $target

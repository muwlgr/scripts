apt install ubuntu-keyring lightdm firefox-esr l3afpad vlc libfm-tools # || apt -f install

genubuntulist() { # $1 - deb or deb-src or both, $2 - mirror URL, $3 - distro name
 edcs=/etc/apt/sources.list.d/$3.sources
 uakr=/usr/share/keyrings/ubuntu-archive-keyring.gpg
 mrum='main restricted universe multiverse'
 [ -f $edcs ] || echo "Types: $1
URIs: $2
Suites: $3 $3-updates
Components: $mrum
Signed-By: $uakr

Types: $1 $1-src
URIs: http://security.ubuntu.com/ubuntu
Suites: $3-security
Components: $mrum
Signed-By: $uakr" > $edcs # full sources in modern format

 apt update
}

apt purge apt-file

ubmir=http://ua.archive.ubuntu.com/ubuntu

# install debs from Ubuntu LTS (24.04 Noble)
[ $(dpkg -l policykit-desktop-privileges ubuntu-mono fonts-ubuntu | grep -wc ii) -eq 3 ] || {
 d1=noble
 genubuntulist deb $ubmir $d1
 apt install policykit-desktop-privileges ubuntu-mono fonts-ubuntu
 rm /etc/apt/sources.list.d/$d1.sources
}

# install locally built .debs
[ $(dpkg -l lubuntu-artwork lubuntu-default-settings lubuntu-default-session | grep -wc ii) -eq 3 ] ||
{ dpkg -i lubuntu-icon-theme_*_*.deb lubuntu-artwork*_*deb lubuntu-default-se*_*deb lubuntu-lxpanel*_*deb  ||
  apt -f install
}

[ $(dpkg -l lubuntu-desktop lubuntu-gtk-core lubuntu-gtk-desktop | grep -wc ii) -eq 3 ] || 
{ dpkg -i lubuntu-desktop_*_*.deb lubuntu-gtk-core_*_*.deb lubuntu-gtk-desktop_*_*.deb ||
  apt -f install
}
pfl=pkg-bionic.tmp
aapkg=aapkg-bionic.tmp
apt-mark auto $(comm -23 $aapkg <(apt-mark showauto | sed 's/:.*//' | sort -u) | fgrep -v fonts-ubuntu) || : # restore auto marks for apt autoremove
apt install $(dpkg -l | grep 'ii *.*[ou]code' | awk '{print $2}') sudo rsync
type aptitude || apt install aptitude
apt remove $(aptitude search '~o' | egrep -v 'ubuntu|font|ttf|icon|theme|privil|[ou]code' | sed 's/ * - .*//;s/.* //') rtkit
fgrep exim $pfl || eatmydata apt remove $(dpkg -l | grep exim | awk '{print $2}')
apt autoremove

sed -i '/#greeter-hide-users=false/s/^#//' /etc/lightdm/lightdm.conf
id user | grep lpadmin || adduser user lpadmin

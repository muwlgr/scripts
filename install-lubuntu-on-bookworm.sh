ldmdeps='aptitude audacious blueman cups cups-filters desktop-base evince ffmpegthumbnailer file-roller firefox-esr fonts-quicksand fwupd galculator ghostscript-x gnome-accessibility-themes gnome-disk-utility gnome-mpv gnome-software gnome-system-tools gnome-themes-extra gnome-themes-extra-data gpicview gtk2-engines gtk2-engines-pixbuf gucharmap guvcview hardinfo hplip l3afpad libayatana-ido3-0.4-0 libayatana-indicator3-7 libevdev2 libinput10 libinput-bin libmtdev1 libplymouth5 libwacom9 libwacom-common libxatracker2 libxcb-util1 libxcvt0 libxfont2 libxklavier16 libxvmc1 lxappearance lxappearance-obconf lxhotkey-gtk lxhotkey-plugin-openbox lxinput lxlauncher lxshortcut lxterminal mtpaint network-manager-gnome pavucontrol pidgin pinentry-gtk2 plymouth plymouth-label printer-driver-foo2zjs printer-driver-gutenprint printer-driver-pnm2ppa printer-driver-ptouch printer-driver-pxljr printer-driver-sag-gdi printer-driver-splix simple-scan software-properties-gtk sylpheed sylpheed-doc sylpheed-i18n sylpheed-plugins synaptic system-config-printer transmission-gtk x11-utils x11-xkb-utils xcvt xfburn xfce4-notifyd xfce4-power-manager xfce4-power-manager-plugins xfonts-base xpad xserver-common xserver-xorg xserver-xorg-core xserver-xorg-input-all xserver-xorg-input-libinput xserver-xorg-input-wacom xserver-xorg-legacy xserver-xorg-video-all xserver-xorg-video-amdgpu xserver-xorg-video-ati xserver-xorg-video-fbdev xserver-xorg-video-intel xserver-xorg-video-nouveau xserver-xorg-video-qxl xserver-xorg-video-radeon xserver-xorg-video-vesa xserver-xorg-video-vmware x11vnc libreoffice cifs-utils remmina freerdp2-x11 firefox-esr-l10n-uk firefox-esr-l10n-ru'

apt install lightdm $ldmdeps

ls /etc/apt/trusted.gpg.d/ubuntu-keyring* || {
 distro=noble
 set -- $(wget -O - https://packages.ubuntu.com/$distro/all/ubuntu-keyring/download | grep -io 'http.*all\.deb' | sort -u) # get package name from its DL page
 wget $1
 dpkg -i $(basename $1)
}

genubuntulist() { # $1 - deb or deb-src, $2 - mirror URL, $3 - suite name
 { for i in $3 $3-updates $3-security
   do echo $1 $2 $i main restricted universe multiverse
   done
 } > /etc/apt/sources.list.d/$3.list
 apt update
}

apt purge apt-file

ubmir=http://ua.archive.ubuntu.com/ubuntu

[ $(dpkg -l policykit-desktop-privileges ubuntu-mono fonts-ubuntu | grep -wc ii) -eq 3 ] || {
 genubuntulist deb $ubmir jammy
 apt install policykit-desktop-privileges ubuntu-mono fonts-ubuntu
 rm /etc/apt/sources.list.d/jammy.list
}

[ $(dpkg -l ttf-ubuntu-font-family | grep -wc ii) -eq 1 ] || {
 genubuntulist deb $ubmir focal
 apt install ttf-ubuntu-font-family
 rm /etc/apt/sources.list.d/focal.list
}

getpgpkey(){ # $1 - fingerprint, $2 - keyserver, $3 - output file
 [ -f $3 ] || {
  gpg --recv-keys --keyserver $2 $1
  gpg --output $3 --armour --export $1
 }
}

ks=keyserver.ubuntu.com

[ $(dpkg -l lubuntu-icon-theme lubuntu-default-settings lubuntu-default-session | grep -wc ii) -eq 3 ] || {
 # get Ubuntu keys and trust them
 ( cd /etc/apt/trusted.gpg.d/
   getpgpkey 3B4FE6ACC0B21F32 $ks bionic.asc
 )

 genubuntulist deb $ubmir bionic
 apt install lubuntu-icon-theme lubuntu-default-settings lubuntu-default-session
 rm /etc/apt/sources.list.d/bionic.list
}
apt update

# install locally built .debs
dpkg -i lubuntu-desktop_*_*.deb lubuntu-gtk-core_*_*.deb lubuntu-gtk-desktop_*_*.deb || apt -f install
aapkg=aapkg-bionic.tmp
apt-mark auto $(comm -23 $aapkg <(apt-mark showauto | sed 's/:.*//' | sort -u)) || : # restore auto marks for apt autoremove
apt install $(dpkg -l | grep 'ii *.*[ou]code' | awk '{print $2}')
apt remove $(aptitude search '~o' | egrep -v 'ubuntu|font|ttf|icon|theme|privil|[ou]code' | sed 's/ * - .*//;s/.* //') rtkit
fgrep exim pkg* || eatmydata apt remove $(dpkg -l | grep exim | awk '{print $2}')
apt autoremove

sed -i '/#greeter-hide-users=false/s/^#//' /etc/lightdm/lightdm.conf
id user | grep lpadmin || adduser user lpadmin

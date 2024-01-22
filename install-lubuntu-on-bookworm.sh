ldmdeps='desktop-base fonts-quicksand gnome-accessibility-themes gnome-themes-extra gnome-themes-extra-data gtk2-engines gtk2-engines-pixbuf libayatana-ido3-0.4-0 libayatana-indicator3-7 libevdev2 libinput-bin libinput10 liblightdm-gobject-1-0 libmtdev1 libplymouth5 libwacom-common libwacom9 libxatracker2 libxcb-util1 libxcvt0 libxfont2 libxklavier16 libxvmc1 lightdm-gtk-greeter plymouth plymouth-label  x11-xkb-utils xcvt xfonts-base xserver-common xserver-xorg xserver-xorg-core xserver-xorg-input-all xserver-xorg-input-libinput xserver-xorg-input-wacom xserver-xorg-legacy xserver-xorg-video-all xserver-xorg-video-amdgpu xserver-xorg-video-ati xserver-xorg-video-fbdev xserver-xorg-video-intel xserver-xorg-video-nouveau xserver-xorg-video-qxl xserver-xorg-video-radeon xserver-xorg-video-vesa xserver-xorg-video-vmware'

apt install lightdm $ldmdeps
apt-mark auto $ldmdeps

getpgpkey(){ # $1 - fingerprint, $2 - keyserver, $3 - output file
 [ -f $3 ] || {
  gpg --recv-keys --keyserver $2 $1
  gpg --output $3 --armour --export $1
 }
}

ks=keyserver.ubuntu.com

# get Ubuntu keys and trust them
( cd /etc/apt/trusted.gpg.d/
  getpgpkey 3B4FE6ACC0B21F32 $ks bionic.asc
  getpgpkey 871920D1991BC93C $ks jammy.asc
)

genubuntulist() { # $1 - deb or deb-src, $2 - mirror URL, $3 - suite name
 { for i in $3 $3-updates $3-security
   do echo $1 $2 $i main restricted universe multiverse
   done
 } > /etc/apt/sources.list.d/$3.list
 apt update
}

ubmir=http://ua.archive.ubuntu.com/ubuntu

genubuntulist deb $ubmir jammy
apt install policykit-desktop-privileges ubuntu-mono
rm /etc/apt/sources.list.d/jammy.list

genubuntulist deb $ubmir bionic
apt install lubuntu-icon-theme lubuntu-default-settings lubuntu-default-session
rm /etc/apt/sources.list.d/bionic.list
apt update

# small workaround for Ubuntu's libnewt
#mkdir /etc/newt
#touch /etc/newt/palette.original
#update-alternatives --install /etc/newt/palette newt-palette /etc/newt/palette.original 20

# install locally built .debs
dpkg -i lubuntu-desktop_*_*.deb lubuntu-gtk-core_*_*.deb lubuntu-gtk-desktop_*_*.deb 
apt -f install

sed -i '/#greeter-hide-users=false/s/^#//' /etc/lightdm/lightdm.conf

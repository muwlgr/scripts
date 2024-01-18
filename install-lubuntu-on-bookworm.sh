# small workaround for Ubuntu's libnewt
#mkdir /etc/newt
#touch /etc/newt/palette.original
#update-alternatives --install /etc/newt/palette newt-palette /etc/newt/palette.original 20

# install locally built .debs
dpkg -i lubuntu-desktop_*_*.deb lubuntu-gtk-core_*_*.deb lubuntu-gtk-desktop_*_*.deb lubuntu-artwork_*_*.deb lubuntu-artwork-18-04_*_*.deb lubuntu-lxpanel-icons_*_*.deb lubuntu-default-session_*_*.deb lubuntu-default-settings_*_*.deb lubuntu-icon-theme_*_*.deb ubuntu-mono_*_*.deb
apt -f install

sed -i '/#greeter-hide-users=false/s/^#//' /etc/lightdm/lightdm.conf

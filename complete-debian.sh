set -x -e

#safety checks
[ "$COMPLETE" = "y" ]
[ "$DEBIAN" = "y" ]

#prepare fstab
{ echo $(blkid -o export /dev/${DEV}2 | grep ^UUID) / auto defaults 0 0 
  echo $(blkid -o export /dev/${DEV}1 | grep ^UUID) /mnt/boot auto defaults 0 0 
  echo /mnt/boot/debian-boot /boot none bind 0 0
  echo /mnt/boot /boot/efi none bind 0 0
  echo tmpfs /tmp tmpfs defaults 0 0 
} >> /etc/fstab
#prepare boot folder on FAT
mkdir /mnt/boot
mount /mnt/boot
( cd /mnt/boot
  for d in debian-boot EFI
  do [ -d $d ] || mkdir $d 
  done
)
mount /boot
mount /boot/efi

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

apt install eatmydata locales sudo
echo Europe/Kyiv > /etc/timezone
sed -r -i '/^ *(en_US|ru_|uk_UA).* *UTF-8/s/^# *//' /etc/locale.gen

set -- $(cat /etc/apt/sources.list)
sed -i '/^ *deb/s/^/#/' /etc/apt/sources.list
gen_debian_list_$3 $1 $2 $3

time eatmydata apt dist-upgrade # not dist-upgrade, to keep fwupd packages
dpkg-reconfigure tzdata locales
time eatmydata apt install nmap tcpdump lsof lshw rsync openssh-server systemd-cron bash-completion dphys-swapfile nullmailer
eatmydata apt remove apparmor at-spi2-core anacron cron gnome-online-accounts gnome-control-center gnome-session-bin gnome-software-plugin-snap networkd-dispatcher netplan.io nplan nullmailer rsyslog rtkit snapd squashfs-tools thermald unity-control-center xserver-xorg-legacy zeitgeist-core
eatmydata apt autoremove

#echo do_symlinks = no >> /etc/kernel-img.conf # else focal won't install linux-image on FAT

eatmydata apt install linux-image-amd64 grub-pc # this will pull in grub-pc , install it into /dev/$DEV
ird=$(find /boot/ -type f -iname 'initrd.img*' | xargs ls -t | head -n1)
eatmydata apt install dosfstools # this will update initrd
echo GRUB_CMDLINE_LINUX_DEFAULT=\"root=$(awk '$2=="/"{print $1}' /etc/fstab)\" >> /etc/default/grub
grub-install /dev/$DEV # install into MBR
update-grub

adduser office
adduser user
adduser user sudo
adduser user lpadmin

set -x -e

#safety checks
[ "$COMPLETE" = "y" ]
[ "$LUBUNTU" = "y" ]

#prepare fstab
{ echo $(blkid -o export /dev/${DEV}2 | grep ^UUID) / auto defaults 0 0 
  echo $(blkid -o export /dev/${DEV}1 | grep ^UUID) /mnt/boot auto defaults 0 0 
  echo /mnt/boot/ubuntu-boot /boot none bind 0 0
  echo tmpfs /tmp tmpfs defaults 0 0 
} >> /etc/fstab
#prepare boot folder on FAT
mkdir /mnt/boot
mount /mnt/boot
( cd /mnt/boot
  [ -d ubuntu-boot ] || mkdir ubuntu-boot # EFI 
)
mount /boot

#connect to universe and install lubuntu-desktop, as it may not be installable with -updates and -security
apt install eatmydata
sed -i '/^deb.*main$/s/$/ universe/' /etc/apt/sources.list
eatmydata apt update
time eatmydata apt install lubuntu-desktop 
touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf # https://gist.github.com/DennisPohlmann/7a8cfbfa4f432c238728e44f81d8b128

#reorganize sources.list, connecting it to -updates, -security, restricted and multiverse
set -- $(cat /etc/apt/sources.list)
{ for i in $3 $3-security $3-updates
  do echo $1 $2 $i main restricted universe multiverse
  done
  echo $1 http://archive.canonical.com/ubuntu $3 partner
} > /etc/apt/sources.list.d/$3.list
sed -i '/^ *deb/s/^/#/' /etc/apt/sources.list
eatmydata apt update
time eatmydata apt upgrade # not dist-upgrade, to keep fwupd packages
dpkg-reconfigure tzdata
dpkg-reconfigure locales
time eatmydata apt install libreoffice nmap tcpdump lsof lshw rsync openssh-server systemd-cron bash-completion dphys-swapfile
echo CONF_SWAPSIZE=2048 >> /etc/dphys-swapfile # it still requires manual reconfiguration
dd if=/dev/zero of=/var/swap bs=1M count=2048 # and fallocate creates files with holes on f2fs, so create it by dd
sudo add-apt-repository ppa:remmina-ppa-team/remmina-next
eatmydata install remmina
#trim some slack pulled in by lubuntu-desktop
eatmydata apt remove activity-log-manager apparmor at-spi2-core anacron cron gnome-online-accounts gnome-control-center gnome-session-bin gnome-startup-applications gnome-software-plugin-snap libwhoopsie-preferences0 networkd-dispatcher netplan.io nplan nullmailer rsyslog rtkit snapd squashfs-tools thermald unity-control-center whoopsie-preferences xserver-xorg-legacy zeitgeist-core
eatmydata apt autoremove

echo do_symlinks = no >> /etc/kernel-img.conf # else focal won't install linux-image on FAT

eatmydata apt install linux-image-generic # this will pull in grub-pc , install it into /dev/$DEV
ird=$(find /boot/ -type f -iname 'initrd.img*' | xargs ls -t | head -n1)
t=$(mktemp)
lsinitramfs $ird > $t
for i in f2fs libcrc32c crc32_generic crc32-pclmul
do fgrep '/'$i'.ko' $t || echo $i >> /etc/initramfs-tools/modules
done # fix for f2fs support in bionic
rm $t
eatmydata apt install f2fs-tools dosfstools # this will update initrd
echo GRUB_CMDLINE_LINUX_DEFAULT=\"root=$(awk '$2=="/"{print $1}' /etc/fstab)\" >> /etc/default/grub
#grub-install /dev/$DEV # install into MBR
update-grub

adduser office
adduser user
adduser user sudo
adduser user lpadmin

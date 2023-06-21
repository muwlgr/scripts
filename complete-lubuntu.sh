set -x -e
[ "$COMPLETE" = "y" ]
[ "$LUBUNTU" = "y" ]
{ echo $(blkid -o export /dev/${DEV}2 | grep ^UUID) / auto defaults 0 0 
  echo $(blkid -o export /dev/${DEV}1 | grep ^UUID) /mnt/boot auto defaults 0 0 
  echo /mnt/boot/ubuntu-boot /boot none bind 0 0
  echo tmpfs /tmp tmpfs defaults 0 0 >> etc/fstab
} >> /etc/fstab
mkdir /mnt/boot
mount /mnt/boot
( cd /mnt/boot
  mkdir ubuntu-boot # EFI 
)
mount /boot

apt install eatmydata
sed -i '/deb.*main/s/$/ universe/' /etc/apt/sources.list
eatmydata apt update
eatmydata apt install lubuntu-desktop libreoffice

set -- $(cat /etc/apt/sources.list)
{ for i in $3 $3-security $3-updates
  do echo $1 $2 $i main restricted universe multiverse
  done
  echo $1 http://archive.canonical.com/ubuntu $3 partner
} > /etc/apt/sources.list.d/$3.list
sed -i '/^ *deb/s/^/#/' /etc/apt/sources.list
eatmydata apt update

echo do_symlinks = no >> /etc/kernel-img.conf # else focal won't install linux-image on FAT

eatmydata apt install linux-image-generic # this will pull in grub-pc 
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

touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf # https://gist.github.com/DennisPohlmann/7a8cfbfa4f432c238728e44f81d8b128
adduser office
adduser user
adduser user sudo
#eatmydata apt install lubuntu-desktop libreoffice

easl=/etc/apt/sources.list
dakr=/usr/share/keyrings/debian-archive-keyring.gpg
cnnf="contrib non-free non-free-firmware"
grep ^deb $easl | while read a b c d
do edcs=$easl.d/$c.sources
   [ -f $edcs ] || echo "Types: $a 
URIs: $b
Suites: $c $c-updates
Components: $d $cnnf
Signed-By: $dakr

Types: $a
URIs: http://security.debian.org/debian-security
Suites: $c-security
Components: $d $cnnf
Enabled: yes
Signed-By: $dakr" > $edcs
   cat $edcs
   sed -i '/^deb/s/^/#/' $easl
done # reform sources.list from debootstrap into stable.sources recommended by Debian

type eatmydata && emd=eatmydata
$emd apt update
$emd apt install eatmydata locales fakeroot initramfs-tools sudo systemd-resolved systemd-cron wget
$emd dpkg-reconfigure locales tzdata
type eatmydata && emd=eatmydata

# set up fstab
fgrep /boot  /etc/fstab || echo /host/linux/boot      /boot     none  bind     0 0 >> /etc/fstab
grep ^efivar /proc/mounts && ! fgrep /boot/efi /etc/fstab &&
                           echo /host                 /boot/efi none  bind     0 0 >> /etc/fstab
fgrep /swap. /etc/fstab || echo /host/linux/swap.loop none      swap  sw       0 0 >> /etc/fstab
fgrep /tmp   /etc/fstab || echo tmpfs                 /tmp      tmpfs defaults 0 0 >> /etc/fstab

cat /etc/fstab

# install and set up grub

gdev=$(awk '$2=="/host"{print $1}' /proc/mounts | sort -u)

#install grub-pc first to gain bios/csm compatibility
$emd apt install grub-pc
$emd grub-install ${gdev%[0-9]} # install into the MBR

if grep ^efivar /proc/mounts # then if we have efivarfs mounted,
then $emd apt install grub-efi-amd64 # replace it with grub-efi
     $emd grub-install # install into default EFI folder under /boot/efi/
     $emd apt autoremove # to remove grub-pc-bin
fi

echo 'GRUB_FONT=/boot/grub/fonts/unicode.pf2
GRUB_DEVICE=$GRUB_DEVICE_BOOT
GRUB_DEVICE_UUID=$GRUB_DEVICE_BOOT_UUID
GRUB_CMDLINE_LINUX_DEFAULT="loop=linux/root.loop rw"' >> /etc/default/grub # to properly drive update-grub

# set up initramfs-tools

ekic=/etc/kernel-img.conf
dsln="do_symlinks = no"
fgrep "$dsln" $ekic || echo "$dsln" >> $ekic

( cd /etc/initramfs-tools/
  FSTYPE=$(blkid $gdev -s TYPE -o value) # should be vfat
  fgrep -w $FSTYPE modules || echo $FSTYPE >> modules
  fgrep -w vfat modules && { 
   for i in cp437 ascii # add vfat codepages
   do fgrep -w nls_$i modules || echo nls_$i >> modules 
   done
  }
  ghir=https://raw.githubusercontent.com/muwlgr/scripts/refs/heads/main/initramfs
  for i in premount bottom # add host/loop handling scripts
  do ( cd scripts/local-$i
       [ -f hostloop-$i ] || { wget $ghir/hostloop-$i
                               chmod -v +x hostloop-$i
                             } )
  done )

$emd apt install linux-image-amd64 || fakeroot $emd apt -f install # workaround for vfat volume mounted with non-root uid
$emd update-grub
$emd apt remove ifupdown apparmor fakeroot wget
$emd apt autoremove 
$emd apt clean 

[ -d /etc/systemd/network/ ] && ( cd /etc/systemd/network/ 
 for i in en wl # initialize simplest config for systemd-networkd
 do [ -f $i.network ] || cat << EOF1 > $i.network
[Match]
Name=$i*
[Network]
DHCP=ipv4
EOF1
 done 
 systemctl is-enabled systemd-networkd || systemctl enable systemd-networkd ) 

df -h /
echo your system is configured. now please add the first user and give him/her sudo rights
echo like this : 'u=user ; adduser $u ; adduser $u sudo'

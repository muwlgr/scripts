easl=/etc/apt/sources.list
dakr=/usr/share/keyrings/debian-archive-keyring.gpg
cnnf="contrib non-free non-free-firmware"
grep ^deb $easl | while read a b c d
do [ -f $easl.d/$c.sources ] || echo "Types: $a 
URIs: $b
Suites: $c $c-updates
Components: $d $cnnf
Signed-By: $dakr

Types: $a
URIs: http://security.debian.org/debian-security
Suites: $c-security
Components: $d $cnnf
Enabled: yes
Signed-By: $dakr" > $easl.d/$c.sources
sed -i '/^deb/s/^/#/' $easl
done # reform sources.list from debootstrap into stable.sources recommended by Debian
type eatmydata && emd=eatmydata
$emd apt update
$emd apt install eatmydata locales fakeroot initramfs-tools sudo systemd-resolved systemd-cron
$emd dpkg-reconfigure locales tzdata
type eatmydata && emd=eatmydata

# set up fstab
fgrep /boot  /etc/fstab || echo /host/linux/boot      /boot     none  bind     0 0 >> /etc/fstab
grep ^efivar /proc/mounts && ! fgrep /boot/efi /etc/fstab &&
                           echo /host                 /boot/efi none  bind     0 0 >> /etc/fstab
fgrep /home. /etc/fstab || echo /host/linux/home.loop /home     auto  loop     0 0 >> /etc/fstab
fgrep /var.  /etc/fstab || echo /host/linux/var.loop  /var      auto  loop     0 0 >> /etc/fstab
fgrep /swap. /etc/fstab || echo /host/linux/swap.loop none      swap  sw       0 0 >> /etc/fstab
fgrep /tmp   /etc/fstab || echo tmpfs                 /tmp      tmpfs defaults 0 0 >> /etc/fstab

# install and set up grub

gdev=$(awk '$2=="/host"{print $1}' /proc/mounts | sort -u)

if grep ^efivar /proc/mounts
then $emd apt install grub-efi-amd64
     $emd grub-install
else $emd apt install grub-pc
     $emd grub-install $gdev
fi

bgup=/boot/grub/unicode.pf2
gfb=GRUB_FONT=$bgup
edg=/etc/default/grub
[ -f $bgup ] && ! fgrep $gfb $edg && echo $gfb >> $edg # to help update-grub find unicode.pf2
gdgdev=GRUB_DEVICE=$gdev
fgrep $gdgdev $edg || echo $gdgdev >> $edg # to help update-grub find vmlinux&initrd
UUID=$(blkid $gdev -s UUID -o value)
ruu=root=UUID=$UUID
grep $ruu $edg || echo GRUB_CMDLINE_LINUX_DEFAULT=\"$ruu loop=linux/root.loop rw\" >> $edg

# set up initramfs-tools

ekic=/etc/kernel-img.conf
dsln="do_symlinks = no"
fgrep "$dsln" $ekic || echo "$dsln" >> $ekic

( cd /etc/initramfs-tools/
  FSTYPE=$(blkid $gdev -s TYPE -o value) # should be vfat
  fgrep -w $FSTYPE modules || echo $FSTYPE >> modules
  fgrep -w vfat modules && { # add vfat modules
   for i in cp437 ascii 
   do fgrep -w nls_$i modules || echo nls_$i >> modules
   done
  }
  ( cd scripts/local-premount/
    [ -f hostloop-premount ] || { sed 's/^X//' << 'SHAR_EOF' > 'hostloop-premount' &&
SHAR_EOF
     chmod -v +x hostloop-premount
    } )

  ( cd scripts/local-bottom/
    [ -f hostloop-bottom ] || { sed 's/^X//' << 'SHAR_EOF' > 'hostloop-bottom' &&
SHAR_EOF
     chmod -v +x hostloop-bottom
    } ) )

$emd apt install linux-image-amd64 || fakeroot $emd apt -f install # workaround for vfat volume mounted with non-root uid

[ -d /etc/systemd/network/ ] && ( 
 cd /etc/systemd/network/ 
 for i in en wl # initialize simplest config for systemd-networkd
 do [ -f $i.network ] || cat << EOF1 > $i.network
[Match]
Name=$i*
[Network]
DHCP=ipv4
EOF1
 done 
 systemctl is-enabled systemd-networkd || systemctl enable systemd-networkd ) 

$emd apt remove ifupdown apparmor 

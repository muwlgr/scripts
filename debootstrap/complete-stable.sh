# run this script by including it into your current session using "."

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
time $emd apt install eatmydata locales fakeroot initramfs-tools sudo systemd-resolved systemd-cron wget iw rfkill wireless-tools wireless-regdb wpasupplicant
$emd dpkg-reconfigure locales tzdata
type eatmydata && emd=eatmydata
$emd apt install console-setup
$emd dpkg-reconfigure console-setup

loopimg=$(df -P / | { read none
                      read a b
                      losetup $a | { read a b c
                                     echo $c | sed 's/^(//;s/)$//'
                                   }
                    } ) # loop image file path in the uplevel filesystem

instdir=$(dirname $loopimg)
inst=$(basename $instdir) # should be "linux"

fgrep /boot  /etc/fstab || echo /host/$inst/boot      /boot     none  bind     0 0 >> /etc/fstab # set up fstab
grep ^efivar /proc/mounts && ! fgrep /boot/efi /etc/fstab &&
                           echo /host                 /boot/efi none  bind     0 0 >> /etc/fstab
fgrep /swap. /etc/fstab || echo /host/$inst/swap.loop none      swap  sw       0 0 >> /etc/fstab
fgrep /tmp   /etc/fstab || echo tmpfs                 /tmp      tmpfs defaults 0 0 >> /etc/fstab

cat /etc/fstab

edgd=/etc/default/grub.d # prepare to install grub
[ -d $edgd ] || mkdir $edgd
echo 'GRUB_FONT=/boot/grub/fonts/unicode.pf2
GRUB_DEVICE=$GRUB_DEVICE_BOOT
GRUB_DEVICE_UUID=$GRUB_DEVICE_BOOT_UUID
GRUB_CMDLINE_LINUX_DEFAULT="loop='$inst'/root.loop rw"' >> $edgd/hostloop.cfg

dn=$(dirname $instdir) # should be /media/someone/ESD-USB
ddn=$(dirname $dn)
[ -d $ddn ] || mkdir -pv $ddn # dirty hack to satisfy grub-probe
( cd $ddn
  ln -sfv /host $(basename $dn) ) # recreate the same path for $loopimg as we have in the uplevel

$emd apt install grub-pc #install grub-pc first to gain bios/csm bootability

if grep ^efivar /proc/mounts # then if we have efivarfs mounted,
then $emd apt remove grub-pc-bin
     $emd apt install grub-efi-amd64 # replace it with grub-efi
     $emd grub-install # install into default EFI folder under /boot/efi/
fi

ekic=/etc/kernel-img.conf # set up initramfs-tools
dsln="do_symlinks = no"
fgrep "$dsln" $ekic || echo "$dsln" >> $ekic

( cd /etc/initramfs-tools
  FSTYPE=$(blkid $(df /host | { read none
                                read a b
                                echo $a
                              } ) -s TYPE -o value) # should be vfat
  fgrep -w $FSTYPE modules || echo $FSTYPE >> modules
  fgrep -w vfat modules && { 
   for i in cp437 ascii # add vfat codepages
   do fgrep -w nls_$i modules || echo nls_$i >> modules 
   done
  }
  ghms=https://raw.githubusercontent.com/muwlgr/scripts/refs/heads/main
  ghir=$ghms/initramfs
  for i in premount bottom # add host/loop handling scripts
  do ( cd scripts/local-$i
       hli=hostloop-$i
       [ -f $hli ] || { wget $ghir/$hli
                        chmod -v +x $hli
                      } )
  done )

fakeroot $emd apt install linux-image-amd64 # workaround for vfat volume mounted with non-root uid
$emd apt remove apparmor dhcpcd-base fakeroot ifupdown os-prober
$emd apt autoremove 
$emd apt clean 

ls -d /media/* | xargs -r rm -rv # remove dirty hack folders

esn=/etc/systemd/network
sdnd=systemd-networkd
[ -d $esn ] && ( cd $esn
 for i in en wl # initialize simplest config for systemd-networkd
 do inw=$i.network
[ -f $inw ] || cat << EOF1 > $inw
[Match]
Name=$i*
[Network]
DHCP=ipv4
EOF1
 done 
 systemctl is-enabled $sdnd || systemctl enable $sdnd )

#configure interface-specific wpa_supplicant to be started from udev
$ghwpa=$ghms/wpa
cd /etc/udev/rules.d
wget $ghwpa/99-wpa-wl.rules
cd /root
wget $ghwpa/wpa-networkd.sh

df -h /
GREEN=$(tput setaf 2) # green text
RESET=$(tput sgr0) # reset text color
echo 'your system is configured.
now please add the first user and give him/her sudo rights like this :
'$GREEN'u=user ; adduser $u ; adduser $u sudo'$RESET

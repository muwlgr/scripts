base=$(cd .. && pwd)
target=$(mktemp -d)
sudo mount -o loop,defaults root.loop $target/
for i in home var
do ti=$target/$i
   [ -d $ti ] || sudo mkdir -pv $ti
   sudo mount -o loop,defaults $i.loop $ti
done
tb=$target/boot
sudo mount --bind boot $tb
cd $target
[ -d $base/EFI ] && sudo mount --bind $base $tb/efi
[ -d host ] && sudo mount --bind $base $target/host
df -h | grep $target
sudo ls -l $target/root/runme.sh
echo sudo bash $target/root/runme.sh

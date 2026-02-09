base=$(df -P $0 | awk 'NR>1{print $NF}')
cd $(dirname $(realpath $0))
target=$(mktemp -d)
sudo mount -o loop,defaults root.loop $target/
tb=$target/boot
sudo mount --bind boot $tb
cd $target
[ -d $base/EFI ] && sudo mount --bind $base $tb/efi
[ -d host ] && sudo mount --bind $base $target/host
df -h | grep $target
sudo ls -l $target/root/runme.sh
echo run this : sudo sh $target/root/runme.sh

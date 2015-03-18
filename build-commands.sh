#Not a script!!
echo "Copy and paste the bits you need, don't run this as a script"
exit;

#Centos installation and preperation
yum -y update
yum -y groupinstall 'Development tools'
yum -y install wget bc
reboot

#Environment variables
export SRC=/barebones/source
export BLD=/barebones/build

#Create directory structure
mkdir -p $BLD
mkdir -p $BLD/{lib,proc,sys,dev,etc/init.d,tmp}
mkdir -p $SRC
chmod 1777 $BLD/tmp
cd $SRC

#Get source and expand
wget https://www.kernel.org/pub/linux/kernel/v3.0/linux-3.19.tar.gz
wget http://www.busybox.net/downloads/busybox-1.22.1.tar.bz2
tar xf busybox-1.22.1.tar.bz2
tar xf linux-3.19.tar.gz

#Compile sources
cd $SRC/linux-3.19
make defconfig && make 
cp arch/x86/boot/bzImage $BLD/boot/vmlinuz

cd $SRC/busybox-1.22.1
make defconfig && make
make install
chmod 4755 _install/bin/busybox
cp -a _install/* $BLD/
cd $BLD

#Configuration
cat << EOF > $BLD/etc/init.d/rcS
#!/bin/sh
mount -a 
/sbin/mdev -s
/bin/hostname -F /etc/hostname
/sbin/ifconfig lo 127.0.0.1 up
EOF

cat << EOF > $BLD/etc/fstab
proc            /proc        proc    defaults          0       0
sysfs           /sys         sysfs   defaults          0       0
devpts          /dev/pts     devpts  defaults          0       0
tmpfs           /dev/shm     tmpfs   defaults          0       0
EOF

echo 'localhost' > $BLD/etc/hostname

echo "root:x:0:0:root:/root:/bin/sh" > $BLD/etc/passwd
echo "root::10:0:0:0:::" > $BLD/etc/shadow
echo "root:x:0:" > $BLD/etc/group

chmod 640 $BLD/etc/shadow
chmod +x $BLD/etc/init.d/rcS

rm $BLD/linuxrc
ln -s bin/busybox init

cp /lib/{libcrypt.so.1,libm.so.6,libc.so.6} lib/
cp /lib/ld-linux.so.2 lib/

find . -print | cpio -o -H newc | gzip -9 > $BLD/boot/initrd.img
cd /barebones

cfdisk /dev/sdb #remove all partitions, make new partition, bootable
mkfs.ext2 /dev/sdb1
mkdir /barebones/flashdrive
mount  /dev/sdb1 /barebones/flashdrive
rsync -varh /barebones/build/ /barebones/flashdrive/
grub-install --root-directory=/barebones/flashdrive /dev/sdb

cat << EOF > $BLD/boot/grub/grub.cfg
menuentry "Standard boot" {
    set root=(hd0,msdos1)
        linux /boot/vmlinuz
        initrd /boot/initrd.img
}
menuentry "Debug boot" {
    set root=(hd0,msdos1)
        linux /boot/vmlinuz debug
        initrd /boot/initrd.img
}
menuentry "Pre-mount break boot" {
    set root=(hd0,msdos1)
        linux /boot/vmlinuz debug break=y
        initrd /boot/initrd.img
}
EOF

umount /barebones/flashdrive

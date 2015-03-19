# barebones-linux
Table of Contents
=======
* Introduction
* History of Linux
* Our Goals
* Before We Start
* Some Microlinux Examples
* Building the Environment
* Downloading the Software
* Explaining What We Just Downloaded
* Uncompressing the sources
* Building the sources
* Initialization Configuration
* Library requirements
* Create your initrd
* Putting it onto a flash drive
* Copyright CC-BY

TL;DR
=======
If you don't feel like reading through the guide to understand what is going on, you can see the commands for the complete process here: https://github.com/boardstretcher/barebones-linux/blob/master/build-commands.sh

That is NOT a script. You will have to copy and paste and modify the commands to suit your environment. If you don't feel comfortable using that code and debugging it, then please read on.

Summary
=======
There are so many people out there interested in Linux and how it all comes together, but so few resources to explain just that. Sure there is Linux From Scratch but that is an entire distribution with all kinds of extra programs added in. There is also the Fedora and Debian tools to make smaller and lighter versions of those distributions. 

But those tools keep so much hidden and automate so much.

A basic Linux system need be no more than a boot loader and a kernel. That is what I would like to explore. How to make your own barebones Linux installation.

I will be terse. There are plenty of resources out there to reference for more information on a command or a package.

Barebones Linux
=======
## History of Linux

Just kidding.

If you would like to know about the history of Linux, then I suggest you get on the internet and read any of the millions of articles written on the subject. There is no reason for me to reiterate the HoL yet again.

## Our Goals

At the end of this pamphlet I would like to have a working build that can be written onto a USB stick that is capable of booting into a barebones Linux environment. The environment should have these things:

* Linux Kernel
* Bootloader (grub)
* Basic Utilities (busybox)

I will consider the build a success if the build can boot on a couple of spare laptops. 

## Before We Start

Here are some things that are needed:

* Computer/virtual machine running Centos 6.5 32bit
* 512M+ USB Stick

All of these commands will be issued as root, if you don't want to do this, you can use sudo, but you might have a different experience.

## Some Microlinux Examples

These are similar examples of what we are about to build. Ours will be much smaller though, and have much less flotsam in the build.

* ttylinux - http://ttylinux.net/
* tomsrtbt - http://www.toms.net/rb/
* tinycore - http://tinycorelinux.net/
* slitaz - http://www.slitaz.org/en/

## Building the Environment
We will have to make sure that we have some special utilities and programs available to build the sources. Additionally we will make a working directory to do our work in.

To reiterate: I am executing all of these commands as root on a development machine. 

**Make sure all needed packages are installed**
```
yum -y update
yum -y groupinstall 'Development tools'
yum -y install wget bc
reboot
```

**Create the initial working directory structure and environment**
```
export SRC=/barebones/source
export BLD=/barebones/build
mkdir -p $BLD
mkdir -p $BLD/lib $BLD/proc $BLD/sys $BLD/dev $BLD/etc/init.d $BLD/tmp
mkdir -p $SRC
chmod 1777 $BLD/tmp
cd $SRC
```

## Downloading the Software
Here we will download the Kernel and busybox sources. 

**Download all of the required packages into /barebones/source**
```
wget https://www.kernel.org/pub/linux/kernel/v3.0/linux-3.19.tar.gz
wget http://www.busybox.net/downloads/busybox-1.22.1.tar.bz2
```

## Explaining What We Just Downloaded
linux-3.19.tar.gz is the latest kernel as of this writing. We are downloading the sources to the kernel so that we can configure it and compile it.

busybox-1.22.1.tar.bz2 is a collection of utilities to make a Linux system usable, such as 'init', 'ls', 'free', 'cd' and so on. It is actually a single binary called 'busybox' with symlinks created to point back to it. All of those utilities are 'baked in' to the busybox binary. Its very small and very efficient.

## Uncompressing the Sources
First we have to uncompress the archives we have downloaded.

**Uncompress**
```
tar xf busybox-1.22.1.tar.bz2
tar xf linux-3.19.tar.gz
```

## Building the Sources
You can spend a lot of time reading up on how to tweak a kernel config. But, luckily, you do not absolutely have to do that anymore. You can build the kernel with a 'default' configuration that works fine in most instances.

**Configure and compile the kernel**
```
cd $SRC/linux-3.19
make defconfig && make 
```

This process has made a kernel image for you called 'arch/x86/boot/bzImage' which you can copy to your build directory. This is the kernel you will be booting from when you are done building.

**Copy kernel to build directory**
```
cp arch/x86/boot/bzImage $BLD/boot/vmlinuz
```

Now for busybox. It requires us to compile it as well.

**Configure and compile busybox**
```
cd $SRC/busybox-1.22.1
make defconfig && make
make install
```

This process here compiled busybox and made a binary in the _install directory, along with symlinks that point back to the busybox binary. We need to chmod the busybox binary so it is executable, and copy all of the symlinks to our build directory. It also creates 'linuxrc' which isn't needed, so it should be removed. Finally, set up a symlink to point /init to busybox.

**Make busybox executable, copy symlinks to build directory**
```
chmod 4755 _install/bin/busybox
cp -a _install/* $BLD/
```

**Remove linuxrc and create an /init symlink**
```
rm $BLD/linuxrc
cd $BLD
ln -s bin/busybox init
```

## Initialization Configuration
When the new kernel boots up, it mounts the initrd image, then it looks for an 'init' to fire off. 'init' then runs configuration files located in /etc/init.d/ such as this one that we are going to make here. This 'rcS' file is executable and will:

* mount everything in the fstab
* populate the /dev directory
* set the hostname from /etc/hostname
* bring up the loopback interface

Finally, we will make sure that the file is exectuable by init.

**Create /etc/init.d/rcS**
```
cd $BLD
cat << EOF > $BLD/etc/init.d/rcS
#!/bin/sh
mount -a
/sbin/mdev -s
/bin/hostname -F /etc/hostname
/sbin/ifconfig lo 127.0.0.1 up
EOF

chmod +x $BLD/etc/init.d/rcS
```

'mount -a' will require an /etc/fstab file for it to work. It should contain names and types of the default mount points - proc, sysfs, devpts and tmpfs. 

**Create /etc/fstab**
```
cat << EOF > $BLD/etc/fstab
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devpts /dev/pts devpts defaults 0 0
tmpfs /dev/shm tmpfs defaults 0 0
EOF
```

This is the file that is polled for the machine's hostname.

**Create /etc/hostname**
```
echo 'localhost' > $BLD/etc/hostname
```

You can get away without having a user, but some utilities might have a hard time running. It is best to have a root user created which requires 3 files:

* /etc/passwd
* /etc/group
* /etc/shadow

/etc/shadow is the file that passwords are stored in, so its permissions should be modified to be less permissive.
```
echo "root:x:0:0:root:/root:/bin/sh" > $BLD/etc/passwd
echo "root::10:0:0:0:::" > $BLD/etc/shadow
echo "root:x:0:" > $BLD/etc/group
chmod 640 $BLD/etc/shadow
```

##Library requirements
Grab the libraries that you need from your host OS. In a typical build, we would have made a toochain and built our own libraries, but for a barebones linux there is no need.

**Copy libraries to build**
```
cp /lib/{libcrypt.so.1,libm.so.6,libc.so.6} $BLD/lib/
cp /lib/ld-linux.so.2 $BLD/lib/
```

##Create your initrd
The final step, and the one that causes the most problems, is building your own initrd.img file. This file will be uncompressed by Linux and used as it's operating environment.

**Compress initrd.img file**
```
cd $BLD
find . -print | cpio -o -H newc | gzip -9 > $BLD/boot/initrd.img
```

##Putting it onto a flash drive
We have to partition and format a flash drive, put all of these files onto it, and finally, configure grub the bootloader. You will have to partition the drive by hand!

**Partition and format your flash drive**
```
## We will assume your flashdrive is /dev/sdb, if not, 
## substitute sdb with whatever yours is configured as.

#remove all partitions, make new partition, bootable, write
cfdisk /dev/sdb 
mkfs.ext2 /dev/sdb1
```

**Mount flashdrive and copy build files to it**
```
mkdir /barebones/flashdrive
mount /dev/sdb1 /barebones/flashdrive
rsync -varh /barebones/build/ /barebones/flashdrive/
```

**Install grub bootloader onto flash drive**
```
grub-install --root-directory=/barebones/flashdrive /dev/sdb
```

**Configure grub further**
```
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
```

**Unmount your flash drive**
```
umount /barebones/flashdrive
```

**CONGRATS**
You now have a bootable Linux flash drive.

Copyright
=======
Copyright: CC-BY 2.0 - Steve Zornes 2015

https://creativecommons.org/licenses/by/2.0/

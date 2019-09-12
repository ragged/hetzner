#!/bin/bash


if [[ -a ~/hetzner.cfg ]]
then
    # There should be a config which includes two parameter
    # HE_PUBKEY - your ssh pubkey
    # HE_IP - your IPv6 subnet provided by Hetzner ending with ::
    source ~/hetzner.cfg
else
    echo "~/hetzner.cfg is missing. Exiting..."
    exit 1
fi


if [[ $# -eq 0 ]]
then
        echo './hetzner_vm.sh --hostname VM_HOSTNAME --last_octett LAST_IPV6_OCTETT --disk_size DISK_SIZE_GB'
        exit 1
fi

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --hostname)
        GUEST="$2"
        shift
    ;;
    --disk_size)
        DISKSIZE="$2"
        shift
    ;;
    --last_octett)
        LAST="$2"
        shift
    ;;
    --help)
        echo './hetzner_vm.sh --hostname VM_HOSTNAME --last_octett LAST_IPV6_OCTETT --disk_size DISK_SIZE_GB'
        exit 1
        shift
    ;;
esac
    shift
done

IPV6="${HE_IP}${LAST}"
UUID=`uuidgen`
MAC=$(echo $GUEST|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')
MAC2=$(echo $MAC|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')

echo "> VM Hostname=${GUEST}"
echo "> Last Octett=${LAST}"
echo "> MAC Address=${MAC}"
echo "> MAC Address=${MAC2}"
echo "> IPv6=${IPV6}"



echo "Do you wish to create the VM?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done


echo ">> Setup LVM"
lvcreate -n $GUEST -L${DISKSIZE}G vg0

echo ">> Add Filesystem"
mkfs.xfs /dev/vg0/${GUEST}

echo ">> Mounting LVM"
mount /dev/vg0/${GUEST} /mnt

echo ">> Install Debian Stable"
debootstrap --include=openssh-server,vim,htop,openssl,ca-certificates,locales-all stable /mnt http://deb.debian.org/debian/

echo ">> Set Hostname"
echo ${GUEST} > /mnt/etc/hostname

echo ">> Set Interfaces"
echo "auto lo
iface lo inet6 loopback

auto ens2
iface ens2 inet6 static
address ${IPV6}
netmask 64
gateway ${HE_IP}3

auto ens5
iface ens5 inet dhcp" > /mnt/etc/network/interfaces

echo ">> Set fstab"
echo "proc /proc proc defaults 0 0
/dev/vda1 / xfs defaults 0 1" > /mnt/etc/fstab

echo ">> Set Repositories"
echo "deb http://http.debian.net/debian buster main contrib non-free
deb http://http.debian.net/debian/ buster-updates main contrib non-free
deb http://security.debian.org/ buster/updates main contrib non-free
deb http://ftp.debian.org/debian buster-backports main" > /mnt/etc/apt/sources.list

echo ">> Add IPv6 DNS"
echo "nameserver 2a01:4f8:0:a111::add:9898
nameserver 2a01:4f8:0:a0a1::add:1010
nameserver 2a01:4f8:0:a102::add:9999" > /mnt/etc/resolv.conf

echo ">> Add SSH credentials"
mkdir /mnt/root/.ssh
echo "${HE_PUBKEY}" > /mnt/root/.ssh/authorized_keys

echo ">> Add qemu VM definition"
echo "<domain type='kvm'>
  <name>${GUEST}</name>
  <uuid>${UUID}</uuid>
  <memory unit='KiB'>2097152</memory>
  <currentMemory unit='KiB'>2097152</currentMemory>
  <vcpu placement='static'>2</vcpu>
  <os>
    <type arch='x86_64' machine='pc-i440fx-2.1'>hvm</type>
    <kernel>/vmlinuz</kernel>
    <initrd>/initrd.img</initrd>
    <cmdline>root=/dev/vda console=ttyS0 init=/sbin/init rootflags=allocsize=64k elevator=noop</cmdline>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic eoi='on'/>
    <hap/>
  </features>
  <cpu mode='custom' match='exact'>
    <model fallback='allow'>SandyBridge</model>
  </cpu>
  <clock offset='utc' adjustment='reset'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/kvm</emulator>
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw' cache='none' io='native'/>
      <source dev='/dev/vg0/${GUEST}'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </disk>
    <controller type='pci' index='0' model='pci-root'/>
    <controller type='usb' index='0' model='none'/>
    <controller type='virtio-serial' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </controller>
    <interface type='bridge'>
      <mac address='${MAC}'/>
      <source bridge='br0'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </interface>
    <interface type='bridge'>
      <mac address='${MAC2}'/>
      <source bridge='virbr0'/>
      <model type='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </interface>

    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <memballoon model='none'/>
  </devices>
</domain>" > /etc/libvirt/qemu/${GUEST}.xml

echo ">> Add .bashrc"
echo 'PS1="\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;32m\]\h \[\033[01;33m\]\w \[\033[01;35m\]\$ \[\033[00m\]"
umask 022

# You may uncomment the following lines if you want "ls" to be colorized:
 export LS_OPTIONS="--color=auto"
 eval "`dircolors`"
 alias ls="ls $LS_OPTIONS"
 alias ll="ls $LS_OPTIONS -l"
 alias l="ls $LS_OPTIONS -lA"' > /mnt/root/.bashrc

echo ">> Unmount VM"
umount /mnt

echo ">> Define and start VM"
virsh define /etc/libvirt/qemu/${GUEST}.xml
virsh start ${GUEST}

echo ">> FIN <<"

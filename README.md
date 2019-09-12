# hetzner
Simple scripts for managing Hetzner root server

# Why this repo
If you ever rented a root-server from Hetzners Serverbörse, you get a quite
plain machine, where you have one IPv4 IP and a /64 IPv6 subnet.
As you usually don't want to pay more money for IPv4 addresses you might want
to get IPv6 tunneled throught the dom0 and make all your VMs available via IPv6

I stumbled over a lot of explanations, and tutorials but it was quite hard in
the beginning to get it running. So now i just put everything together to
simply execute the script and get a new VM.

I don't know if this is the best way to achieve my goals, but its working.
You can simply clone the repo, execute the script and get a new VM running in
minutes.

# Dom0
First you need to configure setup your dom0.

In the basic rescue system from Hetzner, just execute this.
(Note that you should add your pubkey before)

	installimage -K /root/pubkey -p /boot:ext3:1024M,lvm:vg0:all -v vg0:root:/:xfs:20G,vg0:swap:swap:swap:2G

Boot the system and install updates + some more packages

	aptitude install libvirt-bin qemu qemu-kvm uuid-runtime vim htop debootstrap

Add your bridge interface for libvirt/qemu

	/etc/libvirt/qemu/networks # vim br0.xml
	<network>
	  <name>br0</name>
	  <uuid>ce4dc4fe-dcf6-11e6-bf26-cec0c932ce01</uuid>
	  <forward dev='eth0' mode='route'>
		<interface dev='eth0'/>
	  </forward>
	  <bridge name='br0' stp='on' delay='0'/>
	  <mac address='50:46:5d:a1:a0:9a'/>
	  <ip address='88.88.88.145' netmask='255.255.255.255'>
	  </ip>
	  <ip family='ipv6' address='2a01:dead:dead:beef::3' prefix='64'>
	  </ip>
	</network>

Add also correct interface settings

	auto lo
	iface lo inet loopback
	iface lo inet6 loopback

	auto eth0
	iface eth0 inet static
	  address 88.88.88.145
	  netmask 255.255.255.255
	  gateway 88.88.88.129
	  pointopoint 88.88.88.129

	iface eth0 inet6 static
	  address 2a01:dead:dead:beef::2
	  netmask 128
	  gateway fe80::1

Some last tasks

	virsh net-define br0.xml
	virsh net-start br0
	virsh net-autostart br0


As you can see your dom0 will get ::2 at the end, and the bridge becomes ::3,
you will meet it again if you look into the vm setup script, ::3 will become
your gateway for the VMs.

As you can imagine, you have now a working configuration to get your IPv6
addresses available. But, imagine one thing, you want to download this script
from github within your vm. *zonk*
You cannot reach anything IPv4 related. Therefore you need to configure your
dom0 to NAT your VMs to the outside, this way they can reach them via IPv6,
and they can reach the whole internet via your dom0's IPv4.

    <network>
      <name>virbr0</name>
      <uuid>da15327c-3e33-46a2-a61c-daef9b5f3b52</uuid>
      <forward dev='enp2s0' mode='nat'>
        <interface dev='enp2s0'/>
      </forward>
      <bridge name='virbr0' stp='on' delay='0'/>
      <mac address='52:54:00:4f:da:9b'/>
	  <ip address='88.88.88.145' netmask='255.255.255.255'>
      </ip>
      <ip family='ipv4' address='192.168.122.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.122.2' end='192.168.122.254'/>
        </dhcp>
      </ip>
    </network>


# VM Setup

First you need to add the configfile "hetzner.cfg" to your users home

    touch ~/hetzner.cfg

Add two parameter for your pubkey and your IPv6 subnet

    HE_PUBKEY="ssh-rsa 123456"
    HE_IP="2a01:dead:dead:beef::"


After you added the config it should be possible to execute hetzner_vm.sh

    ./hetzner_vm.sh --hostname foo --last_octett 4 --disk_size 20

This will create a new VM called foo with the ip 2a01:dead:dead:beef::4

# Credits

Thanks to the guy behind http://blog.alexdpsg.net/898/. This Blogpost helped
me a lot with setting up everything on my hetzner host.



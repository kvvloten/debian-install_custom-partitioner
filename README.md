# Debian-installer custom-partitioner

WARNING: USE OF THIS CODE IS AT YOUR OWN RISK.

ITS PURPOSE IS TO CLEAR AND PARTITION THE DISKS OF A MACHINE AND LOOSE EVERYTHING ON IT !! 


This is an alternative to the default partition-tools available in Debian-installer. 

It is useful for preseed installs, in particular when run from PXE. 
Any distribution that makes use of the Debian-installer code-base can use the custom-partitioner.

Code is tested in a similar setup as the preseed_example with Debian Bullseye and Bookworm.


## Build the udeb package

- Build the udeb package:

```shell
apt-get install build-essential fakeroot dh-make
make all
# Output is stored in the 'build' directory
```

The package `build/custom-partitioner_<VERSION>_all.udeb` should be downloaded in the preseed early phase after 
unpacking it will get triggered by the preseed installer.

Supported partition items:
- physical devices with device names as: `/dev/sd[a-z]`, `/dev/nvme[0-9]`, `/dev/mmcblk[0-9]` 
- mdadm raid levels: 0, 1, 5, 6, 10 and on raid-1 setup with missing disk
- luks encryption: luks1_boot, luks2
- lvm: vg, lv 
- filesystems: ext4, xfs, jfs, swap
- fstab setup

Example partition-layouts are in `preseed_example/d-i/partition-layouts`

A partition-layout has a partition template `partition.tmpl` and a script to customize the template for the machine. named `mk_partitions_conf.sh`. 
The latter processes the template and outputs `partition.conf`. This in turn is the input for the custom-partitioner.


A full-blown preseed setup with custom-partitioner is described in the next section.


## Example preseed setup

### tftp, ipxe, dhcp-server setup

Setup tftp and ipxe:

```shell
TFTP_ROOT="<TFTP_ROOT>"
TFTP_IP="<TFTP_LISTENER_IPADDRESS>"
HOST_FQDN="$(hostname -f)"

apt-get -y install tftpd-hpa

cat << EOF > /etc/default/tftpd-hpa
# /etc/default/tftpd-hpa

TFTP_USERNAME="tftp"
TFTP_DIRECTORY="${TFTP_ROOT}"
TFTP_ADDRESS="${TFTP_IP}:69"
TFTP_OPTIONS="-m /etc/tftpd.remap -vvv --blocksize 1468"
EOF

cat << EOF > /etc/tftpd.remap
# This file has three fields: operation, regex, remapping
#
# The operation is a combination of the following letters:
#
# r - rewrite the matched string with the remapping pattern
# i - case-insensitive matching
# g - repeat until no match (used with "r")
# e - exit (with success) if we match this pattern, do not process
#     subsequent rules
# s - start over from the first rule if we match this pattern
# a - abort (refuse the request) if we match this rule
# G - this rule applies to TFTP GET requests only
# P - this rule applies to TFTP PUT requests only
#
# The regex is a regular expression in the style of egrep(1).
#
# The remapping is a pattern, all characters are verbatim except \
# \0 copies the full string that matched the regex
# \1..\9 copies the 9 first (..) expressions in the regex
# \\ is an escaped \
#
# "#" begins a comment, unless \-escaped
#
rg      \\              /               # Convert backslashes to slashes
r       ^[^/]           ${TFTP_ROOT}/tftp/\0    # Convert non-absolute files
r       ^/grub          ${TFTP_ROOT}/tftp\0
EOF

mkdir -p ${TFTP_ROOT}
curl http://boot.ipxe.org/undionly.kpxe > ${TFTP_ROOT}/ipxe.legacy
curl http://boot.ipxe.org/snponly.efi > ${TFTP_ROOT}/ipxe.efi

cat << EOF > ${TFTP_ROOT}/autoexec.ipxe
#!ipxe

# exit goes to the next item in the chain
# exit 1

dhcp
chain http://${HOST_FQDN}/deploy/ipxe/start.ipxe
EOF

systemctl restart tftpd-hpa
```

Install and configure isc-dhcp-server to serve addresses on your network.

Then add this to the config file:

```shell
TFTP_ROOT="<TFTP_ROOT>"
TFTP_IP="<TFTP_LISTENER_IPADDRESS>"
WEBSERVER_IP="${TFTP_IP}"
HOST_FQDN="$(hostname -f)"

cat << EOF >> /etc/dhcp/dhcpd.conf
include "/etc/dhcp/ipxe-option-space.conf";
group {
    #
    # PXE-boot capable host
    #
    allow booting;
    allow bootp;
    get-lease-hostnames true;
    option ipxe.no-pxedhcp 1;

    if exists user-class and option user-class = "iPXE" {
        filename "http://${WEBSERVER_IP}/deploy/ipxe/start.ipxe";
    } elsif option arch = 00:00 {
        # Legacy
        filename "ipxe.legacy";
    } elsif option arch = 00:07 or option arch = 00:09 {
        # UEFI
        filename "ipxe.efi";
    }
    next-server ${TFTP_IP};
    option pxelinux.pathprefix "${TFTP_ROOT}/";
    
    # For each host add the following section:
    host <HOSTNAME1> {
        hardware ethernet     <HOST_MAC_ADDRESS>;
        fixed-address         <HOST_IP_ADDRESS>;
    }
}
EOF

cat << EOF >> /etc/dhcp/ipxe-option-space.conf
# Declare the iPXE/gPXE/Etherboot option space
option space ipxe;
option ipxe-encap-opts code 175 = encapsulate ipxe;

# iPXE options, can be set in DHCP response packet
option ipxe.priority         code   1 = signed integer 8;
option ipxe.keep-san         code   8 = unsigned integer 8;
option ipxe.skip-san-boot    code   9 = unsigned integer 8;
option ipxe.syslogs          code  85 = string;
option ipxe.cert             code  91 = string;
option ipxe.privkey          code  92 = string;
option ipxe.crosscert        code  93 = string;
option ipxe.no-pxedhcp       code 176 = unsigned integer 8;
option ipxe.bus-id           code 177 = string;
option ipxe.san-filename     code 188 = string;
option ipxe.bios-drive       code 189 = unsigned integer 8;
option ipxe.username         code 190 = string;
option ipxe.password         code 191 = string;
option ipxe.reverse-username code 192 = string;
option ipxe.reverse-password code 193 = string;
option ipxe.version          code 235 = string;
option iscsi-initiator-iqn   code 203 = string;

# iPXE feature flags, set in DHCP request packet
option ipxe.pxeext    code 16 = unsigned integer 8;
option ipxe.iscsi     code 17 = unsigned integer 8;
option ipxe.aoe       code 18 = unsigned integer 8;
option ipxe.http      code 19 = unsigned integer 8;
option ipxe.https     code 20 = unsigned integer 8;
option ipxe.tftp      code 21 = unsigned integer 8;
option ipxe.ftp       code 22 = unsigned integer 8;
option ipxe.dns       code 23 = unsigned integer 8;
option ipxe.bzimage   code 24 = unsigned integer 8;
option ipxe.multiboot code 25 = unsigned integer 8;
option ipxe.slam      code 26 = unsigned integer 8;
option ipxe.srp       code 27 = unsigned integer 8;
option ipxe.nbi       code 32 = unsigned integer 8;
option ipxe.pxe       code 33 = unsigned integer 8;
option ipxe.elf       code 34 = unsigned integer 8;
option ipxe.comboot   code 35 = unsigned integer 8;
option ipxe.efi       code 36 = unsigned integer 8;
option ipxe.fcoe      code 37 = unsigned integer 8;
option ipxe.vlan      code 38 = unsigned integer 8;
option ipxe.menu      code 39 = unsigned integer 8;
option ipxe.sdi       code 40 = unsigned integer 8;
option ipxe.nfs       code 41 = unsigned integer 8;

# Other useful general options
# http://www.ietf.org/assignments/dhcpv6-parameters/dhcpv6-parameters.txt
option arch code 93 = unsigned integer 16;

option space pxelinux;
option pxelinux.pathprefix      code 210 = text;
EOF

systemctl restart isc-dhcp-server
```

### Webserver

- Install a webserver e.g. Apache, configure it for http on port 80.
- Make a directory for the deploy code available via a webserver at `http://<HOST-FQDN>/deploy`.
- Copy the directory structure in `preseed_example` in the webdirectory, the picture below provides some details per file or directory.

```
<WEBROOT>  # web-root must be reachable at http://<HOST-FQDN>/deploy
  |
  + ipxe
  |  +-- start.ipxe  # ipxe file loaded from dhcp settings  
  |
  + d-i
     |
     +-- domain_info         # domain-wide envvars for preseed, check this file for sample content
     +-- hosts               # per host envvars for preseed, check example files for variables      
     |     +-- <HOSTNAME-1>     
     |     +-- <HOSTNAME-1>
     |
     +-- distro
     |     +-- debian-bullseye   # netboot image files for bullseye
     |     |     +-- initrd.gz
     |     |     +-- linux
     |     +-- debian-bookworm   # netboot image files for bookworm
     |           +-- initrd.gz
     |           +-- linux
     |
     +-- customer-partitioner
     |     +-- customer-partitioner.version  # Put the current version-number of the udeb in this file
     |     +-- customer-partitioner_<VERSION>_all.udeb
     |
     +-- partition-layouts
     |     +-- 1hd-lvm                    # layout for machine with 1 disk, partitioned with lvm 
     |     |     +-- mk_partions_conf.sh  #   shell script to customize the template for the machine
     |     |     +-- partitions.tmpl      #   partition template
     |     +-- 2hd-raid1-lvm              # layout for machine with 2 disks, put in raid1 array and partitioned with lvm 
     |           +-- mk_partions_conf.sh  #   shell script to customize the template for the machine
     |           +-- partitions.tmpl      #   partition template
     |     
     +-- preseed
           | 
           +-- classes
                 +-- distro               # per distro preseed files
                 |     +-- debian         # preseed specific for debian (e.g. repo urls)
                 +-- info                 # download domain_info and the hosts/<HOSTNAME> files
                 +-- partitioner          # download and run custom-partitioner and configure grub
                 +-- system               # system settings, check domain_info file for options
```

### Netboot image preparation

One time setup: create the add_firmware_to script:

- Create a direcotry `netboot`
- Copy `scripts/add_firmware_to` to `netboot`
- Make it executable: `chmod +x netboot/add_firmware_to` 


Repeat this step for every new dot release of the distro:

Download the netboot images e.g. for Bookworm and add firmware:

```shell
RELEASE="bookworm"
OUTPUT_PATH="<WEBROOT>/d-i/distro/debian-${RELEASE}"

mkdir -p ${OUTPUT_PATH}
cd netboot

curl http://ftp.nl.debian.org/debian/dists/${RELEASE}/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz > initrd.gz
./add_firmware_to initrd.gz ${OUTPUT_PATH}/initrd.gz ${RELEASE}

curl http://ftp.nl.debian.org/debian/dists/${RELEASE}/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux > ${OUTPUT_PATH}/linux
```


## References
Debian preseed [documentation](https://www.debian.org/releases/buster/amd64/apbs04.en.html#preseed-bootloader)

The preseed framework is taken from ["Hands-off" Debian Installation](http://hands.com/d-i/) 

Inspiration was taken from [preseed-custom-partitioner](https://github.com/BrandwatchLtd/preseed-custom-partitioner)

## Debian-install relevant technical background

The custom-partitioner runs in preseed at a point identified as `XB-Installer-Menu-Item` in `debian/control`

A basic list of numbers is [here](http://ftp.gnome.org/pub/debian-meetings/2006/debconf6/slides/Debian_installer_workshop-Frans_Pop/paper/index.html)

Technical detail on how debian-installer communicates with `parted_server` can be found in [Partition management for Debian-installer](http://iks.cs.ovgu.de/~elkner/tmp/partman/index.html#contents)

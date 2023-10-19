#!/bin/sh
# boot = 1G
# swap = memsize+2GB
# root = 20G
# home = rest
#
# Variables in definition to replace:
#  DISK
#  PART
#  VG_NAME
#  SWAP_SIZE
#  LVM_CRYPT_PASSWORD

NAME="$0"
PARTITION_DEF="$1"
PARTITION_CONF="$2"
DISKS="$3"
VG_NAME="$(cat /etc/hostname)_vg"
[[ ! -e /tmp/domain_info ]] && return 1
. /tmp/domain_info

[[ ! -e "/tmp/get_luks_pw.sh" ]] && return 1
LUKS_PASSWORD_PLAIN="$(sh /tmp/get_luks_pw.sh)"
[[ -z "${LUKS_PASSWORD_PLAIN}" ]] && return 1

NDISKS=$(echo "${DISKS}" | wc -w)
[[ ${NDISKS} -ne 1 ]] && logger "${NAME} Error: Number of disks is ${NDISKS}, supported is 1" && exit 1
DISK=$(echo "${DISKS}" | sed 's/ //g')

SWAP_SIZE=$(grep MemTotal /proc/meminfo | sed 's/ [ ]*/ /g' | cut -d ' ' -f 2)
SWAP_SIZE="$((SWAP_SIZE / 1024 + 2048))M"

# shellcheck disable=SC2086
debconf-set grub-installer/bootdev ${DISK}

logger "$NAME number of disks: ${NDISKS}"
logger "$NAME use disk: ${DISK}"
logger "$NAME volume-group: ${VG_NAME}"
logger "$NAME swap partition: ${SWAP_SIZE}M"

# Remove '/dev/'
REGEX_DISK="$(echo "${DISK}" | sed -e 's/^\/dev\///')"

sed -e "s/@{DISK}/${REGEX_DISK}/g" \
    -e "s/@{VG_NAME}/${VG_NAME}/g" \
    -e "s/@{LUKS_PASSWORD}/${LUKS_PASSWORD_PLAIN}/g" \
    -e "s/@{SWAP_SIZE}/${SWAP_SIZE}/g" \
    "${PARTITION_DEF}" >"${PARTITION_CONF}"

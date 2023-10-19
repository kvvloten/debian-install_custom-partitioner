#!/bin/sh
# boot = 1G
# swap = memsize+2GB
# root = 20G
#
# Variables in definition to replace:
#  VG_NAME
#  SWAP_SIZE

NAME="$0"
PARTITION_DEF="$1"
PARTITION_CONF="$2"
DISKS="$3"
VG_NAME="$(cat /etc/hostname)_vg"
[[ ! -e /tmp/domain_info ]] && return 1
. /tmp/domain_info
[[ -z "${PART_2HD_RAID1_LVM_ROOT_LV_SIZE}" ]] && return 1

NDISKS=$(echo "${DISKS}" | wc -w)
[[ ${NDISKS} -ne 1 ]] && [[ ${NDISKS} -ne 2 ]] && logger "${NAME} Error: Number of disks is ${NDISKS}, supported is 1 or 2" && exit 1

SWAP_SIZE=$(grep MemTotal /proc/meminfo | sed 's/ [ ]*/ /g' | cut -d ' ' -f 2)
SWAP_SIZE="$((SWAP_SIZE / 1024 + 2048))"
[[ ${SWAP_SIZE} -gt 8000 ]] && SWAP_SIZE="8000"
SWAP_SIZE="${SWAP_SIZE}M"

# shellcheck disable=SC2086
debconf-set grub-installer/bootdev ${DISKS}

logger "$NAME number of disks: ${NDISKS}"
logger "$NAME use disks: ${DISKS}"
logger "$NAME volume-group: ${VG_NAME}"
logger "$NAME swap partition: ${SWAP_SIZE}M"


MD0="md 1 raid"
MD1="md 1 raid"
for DISK in ${DISKS}; do
    MD0="$MD0 ${DISK}{part#1}"
    MD1="$MD1 ${DISK}{part#2}"
done
# shellcheck disable=SC2031
if [[ ${NDISKS} -eq 1 ]]; then
    MD0="$MD0 missing"
    MD1="$MD1 missing"
fi

# Dynamically add commands on physical disks because the second disk can be missing
echo "# START lines generated by $NAME" > "${PARTITION_CONF}"
for DISK in ${DISKS}; do
    cat >> "${PARTITION_CONF}" << EOF
clear_part_table ${DISK}
part ${DISK} 2000M
part ${DISK} rest
EOF
done
cat >> "${PARTITION_CONF}" << EOF
$MD0
$MD1
# END lines generated by $NAME
EOF

sed -e "s/@{VG_NAME}/${VG_NAME}/g" \
    -e "s/@{SWAP_SIZE}/${SWAP_SIZE}/g" \
    -e "s/@{ROOT_LV_SIZE}/${PART_2HD_RAID1_LVM_ROOT_LV_SIZE}/g" \
    "${PARTITION_DEF}" >> "${PARTITION_CONF}"

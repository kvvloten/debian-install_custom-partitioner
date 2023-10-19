#!/bin/sh
NAME="$0"
[[ ! -e /tmp/domain_info ]] && return 1
. /tmp/domain_info
[[ -z "${PART_1HD_LUKS_CRYPT_PASSWORD}" ]] && return 1

LUKS_PASSWORD_PLAIN="${PART_1HD_LUKS_CRYPT_PASSWORD}"
if [[ -z "${LUKS_PASSWORD_PLAIN}" ]]; then
    logger "$NAME Error: failed to get LVM_CRYPT_PASSWORD"
    exit 1
fi
echo "${LUKS_PASSWORD_PLAIN}"

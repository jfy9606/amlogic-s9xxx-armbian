#!/bin/bash
#==================================================================================
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of the Rebuild Armbian
# https://github.com/jfy9606/amlogic-s9xxx-armbian
#
# Description: Generate uInitrd in chroot environment
#
#==================================================================================

kernel_outname="${1}"

echo -e "Start generating uInitrd for [ ${kernel_outname} ] in chroot environment..."

# Set compress format
compress_format="xz"
compress_initrd_file="/etc/initramfs-tools/initramfs.conf"
if [[ -f "${compress_initrd_file}" ]]; then
    sed -i "s|^COMPRESS=.*|COMPRESS=${compress_format}|g" ${compress_initrd_file}
    echo -e "Set compress format to [ ${compress_format} ]"
fi

# Enable update_initramfs
initramfs_conf="/etc/initramfs-tools/update-initramfs.conf"
[[ -f "${initramfs_conf}" ]] && sed -i "s|^update_initramfs=.*|update_initramfs=yes|g" ${initramfs_conf}

# Generate initrd.img and uInitrd
cd /boot
update-initramfs -c -k ${kernel_outname}

# Disable update_initramfs
[[ -f "${initramfs_conf}" ]] && sed -i "s|^update_initramfs=.*|update_initramfs=no|g" ${initramfs_conf}

# Create uInitrd
if [[ -f "initrd.img-${kernel_outname}" ]]; then
    mkimage -A arm64 -O linux -T ramdisk -C gzip -n uInitrd -d initrd.img-${kernel_outname} uInitrd-${kernel_outname}
    echo -e "Successfully created uInitrd-${kernel_outname}"
else
    echo -e "ERROR: initrd.img-${kernel_outname} not found"
    exit 1
fi

# Create header package from kernel source tree
echo -e "Creating header package..."
mkdir -p /opt/header

# The kernel source tree is at /opt/linux-kernel
if [[ -d "/opt/linux-kernel" ]]; then
    cd /opt/linux-kernel
    tar -czf /opt/header/header-${kernel_outname}.tar.gz .
    echo -e "Successfully created header package from /opt/linux-kernel"
else
    echo -e "ERROR: Kernel source tree /opt/linux-kernel not found"
    exit 1
fi

echo -e "All done in chroot environment."

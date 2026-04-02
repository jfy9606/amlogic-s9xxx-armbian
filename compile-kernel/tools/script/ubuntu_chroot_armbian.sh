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
SRC_ARCH="arm64"

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

kernel_src="/opt/linux-kernel"
if [[ -d "${kernel_src}" ]]; then
    cd ${kernel_src}
    
    header_tmp="/tmp/header_${kernel_outname}"
    mkdir -p ${header_tmp}
    
    # Set headers files list
    head_list="$(mktemp)"
    (
        find . arch/${SRC_ARCH} -maxdepth 1 -name Makefile\*
        find include scripts -type f -o -type l
        find arch/${SRC_ARCH} -name Kbuild.platforms -o -name Platform
        find $(find arch/${SRC_ARCH} -name include -o -name scripts -type d) -type f
    ) >${head_list}

    # Set object files list
    obj_list="$(mktemp)"
    {
        [[ -n "$(grep "^CONFIG_OBJTOOL=y" include/config/auto.conf 2>/dev/null)" ]] && echo "tools/objtool/objtool"
        find arch/${SRC_ARCH}/include Module.symvers include scripts -type f
        [[ -n "$(grep "^CONFIG_GCC_PLUGINS=y" include/config/auto.conf 2>/dev/null)" ]] && find scripts/gcc-plugins -name \*.so
    } >${obj_list}

    # Install related files to the specified directory
    tar --exclude '*.orig' -c -f - -C ${kernel_src} -T ${head_list} | tar -xf - -C ${header_tmp}
    tar --exclude '*.orig' -c -f - -T ${obj_list} | tar -xf - -C ${header_tmp}

    # Copy the necessary files to the specified directory
    cp -af include/config "${header_tmp}/include"
    cp -af include/generated "${header_tmp}/include"
    cp -af arch/${SRC_ARCH}/include/generated "${header_tmp}/arch/${SRC_ARCH}/include"
    cp -af .config Module.symvers ${header_tmp}

    # Delete temporary files
    rm -f ${head_list} ${obj_list}

    # Create header package
    cd ${header_tmp}
    tar -czf /opt/header/header-${kernel_outname}.tar.gz .
    rm -rf ${header_tmp}
    
    echo -e "Successfully created header package from ${kernel_src}"
else
    echo -e "ERROR: Kernel source tree ${kernel_src} not found"
    exit 1
fi

echo -e "All done in chroot environment."

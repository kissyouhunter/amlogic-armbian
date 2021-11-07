#!/bin/bash
#=========================================================================
# Description: Build armbian for amlogic s9xxx
# Copyright (C) 2021 https://github.com/ophub/amlogic-s9xxx-armbian
#=========================================================================

#===== Do not modify the following parameter settings, Start =====
make_path=${PWD}
armbian_outputpath=${make_path}/build/output/images
amlogic_path=${make_path}/amlogic-s9xxx
armbian_path=${amlogic_path}/amlogic-armbian
dtb_path=${amlogic_path}/amlogic-dtb
kernel_path=${amlogic_path}/amlogic-kernel
uboot_path=${amlogic_path}/amlogic-u-boot
configfiles_path=${amlogic_path}/common-files
tmp_outpath=${make_path}/tmp_out
tmp_armbian=${make_path}/tmp_armbian
tmp_build=${make_path}/tmp_build
tmp_aml_image=${make_path}/tmp_aml_image

kernel_library="https://github.com/kissyouhunter/kernel_N1/tree/main/kernel"
#kernel_library="https://github.com/ophub/flippy-kernel/trunk/library"

build_armbian=("s905d")
build_kernel=("default")
change_kernel="no"
#===== Do not modify the following parameter settings, End =======

# Specify Amlogic soc
if [ -n "${1}" ]; then
    unset build_armbian
    oldIFS=$IFS
    IFS=_
    build_armbian=(${1})
    IFS=$oldIFS
fi

# Set whether to replace the kernel
if [ -n "${2}" ]; then
    auto_kernel="${3}"
    change_kernel="yes"
    unset build_kernel
    oldIFS=$IFS
    IFS=_
    build_kernel=(${2})
    IFS=$oldIFS

    # Convert kernel library address to svn format
    if [[ ${kernel_library} == http* && $(echo ${kernel_library} | grep "tree/main") != "" ]]; then
        kernel_library=${kernel_library//tree\/main/trunk}
    fi

    # Check the new version on the kernel library
    if [[ -z "${auto_kernel}" || "${auto_kernel}" != "false" ]]; then

        # Set empty array
        TMP_ARR_KERNELS=()

        # Convert kernel library address to API format
        SERVER_KERNEL_URL=${kernel_library#*com\/}
        SERVER_KERNEL_URL=${SERVER_KERNEL_URL//trunk/contents}
        SERVER_KERNEL_URL="https://api.github.com/repos/${SERVER_KERNEL_URL}"

        # Query the latest kernel in a loop
        i=1
        for KERNEL_VAR in ${build_kernel[*]}; do
            echo -e "(${i}) Auto query the latest kernel version of the same series for [ ${KERNEL_VAR} ]"
            MAIN_LINE_M=$(echo "${KERNEL_VAR}" | cut -d '.' -f1)
            MAIN_LINE_V=$(echo "${KERNEL_VAR}" | cut -d '.' -f2)
            MAIN_LINE_S=$(echo "${KERNEL_VAR}" | cut -d '.' -f3)
            MAIN_LINE="${MAIN_LINE_M}.${MAIN_LINE_V}"
            # Check the version on the server (e.g LATEST_VERSION="124")
            LATEST_VERSION=$(curl -s "${SERVER_KERNEL_URL}" | grep "name" | grep -oE "${MAIN_LINE}.[0-9]+"  | sed -e "s/${MAIN_LINE}.//g" | sort -n | sed -n '$p')
            if [[ "$?" -eq "0" && ! -z "${LATEST_VERSION}" ]]; then
                TMP_ARR_KERNELS[${i}]="${MAIN_LINE}.${LATEST_VERSION}"
            else
                TMP_ARR_KERNELS[${i}]="${KERNEL_VAR}"
            fi
            echo -e "(${i}) [ ${TMP_ARR_KERNELS[$i]} ] is latest kernel. \n"

            let i++
        done

        # Reset the kernel array to the latest kernel version
        unset build_kernel
        build_kernel=${TMP_ARR_KERNELS[*]}

    fi

    # Synchronization related kernel
    i=1
    for KERNEL_VAR in ${build_kernel[*]}; do
        if [ ! -d "${kernel_path}/${KERNEL_VAR}" ]; then
            echo -e "(${i}) [ ${KERNEL_VAR} ] Kernel loading from [ ${kernel_library}/${KERNEL_VAR} ]"
            svn checkout ${kernel_library}/${KERNEL_VAR} ${kernel_path}/${KERNEL_VAR} >/dev/null
            rm -rf ${kernel_path}/${KERNEL_VAR}/.svn >/dev/null && sync
        else
            echo -e "(${i}) [ ${KERNEL_VAR} ] Kernel is in the local directory."
        fi

        let i++
    done

    sync
fi

die() {
    echo -e " [\033[1;31m Error \033[0m] ${1}"
    exit 1
}

process() {
    echo -e " [\033[1;32m ${build_soc}${out_kernel} \033[0m] ${1}"
}

make_image() {
    cd ${make_path}

        rm -rf ${tmp_armbian} ${tmp_build} ${tmp_outpath} ${tmp_aml_image} 2>/dev/null && sync
        mkdir -p ${tmp_armbian} ${tmp_build} ${tmp_outpath} ${tmp_aml_image} && sync

        # Get armbian version and release
        armbian_image_name=$(ls ${armbian_outputpath}/*-trunk_*.img 2>/dev/null | awk -F "/Armbian_" '{print $2}')
        out_release=$(echo ${armbian_image_name} | awk -F "buster" '{print $1}' | grep -oE '[1-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}' 2>/dev/null)
        out_version=$(echo ${armbian_image_name} | awk -F "buster" '{print $NF}' | grep -oE '[1-9].[0-9]{1,3}.[0-9]{1,3}' 2>/dev/null)
        [[ -n "${out_release}" && -n "${out_version}" ]] || die "Invalid file: ${armbian_outputpath}/*-trunk_*.img"
        if [ -n "${new_kernel}" ]; then
            make_version=${new_kernel}
        else
            make_version=${out_version}
        fi

        # Make Amlogic s9xxx armbian
        build_image_file="${tmp_outpath}/Armbian_${out_release}_Aml_${build_soc}_buster_${make_version}_$(date +"%Y.%m.%d.%H%M").img"
        rm -f ${build_image_file}
        sync

        SKIP_MB=68
        BOOT_MB=256
        ROOT_MB=2748
        IMG_SIZE=$((SKIP_MB + BOOT_MB + ROOT_MB))

        dd if=/dev/zero of=${build_image_file} bs=1M count=${IMG_SIZE} conv=fsync >/dev/null 2>&1
        sync

        parted -s ${build_image_file} mklabel msdos 2>/dev/null
        parted -s ${build_image_file} mkpart primary fat32 $((SKIP_MB))M $((SKIP_MB + BOOT_MB -1))M 2>/dev/null
        parted -s ${build_image_file} mkpart primary ext4 $((SKIP_MB + BOOT_MB))M 100% 2>/dev/null
        sync

        loop_new=$(losetup -P -f --show "${build_image_file}")
        [ ${loop_new} ] || die "losetup ${build_image_file} failed."

        mkfs.vfat -n "BOOT" ${loop_new}p1 >/dev/null 2>&1
        mke2fs -F -q -t ext4 -L "ROOTFS" -m 0 ${loop_new}p2 >/dev/null 2>&1
        sync
}

extract_armbian() {
    cd ${make_path}

        armbian_image_file="${tmp_aml_image}/armbian_${build_soc}_${make_version}.img"
        rm -f ${armbian_image_file} 2>/dev/null && sync
        cp -f $( ls ${armbian_outputpath}/*-trunk_*.img 2>/dev/null | head -n 1 ) ${armbian_image_file}
        sync && sleep 3

        loop_old=$(losetup -P -f --show "${armbian_image_file}")
        [ ${loop_old} ] || die "losetup ${armbian_image_file} failed."

        if ! mount ${loop_old}p1 ${tmp_armbian}; then
            die "mount ${loop_old}p1 failed!"
        fi

    cd ${tmp_armbian}
        # Delete soft link (ln -sf TrueFile Link)
        rm -rf bin lib sbin tmp var/sbin
        sync
}

replace_kernel() {
    # Replace if specified
    if [[ "${change_kernel}" == "yes" ]]; then
        cd ${make_path}

            build_boot=$( ls ${kernel_path}/${new_kernel}/boot-${new_kernel}-*.tar.gz 2>/dev/null | head -n 1 )
            build_dtb=$( ls ${kernel_path}/${new_kernel}/dtb-amlogic-${new_kernel}-*.tar.gz 2>/dev/null | head -n 1 )
            build_modules=$( ls ${kernel_path}/${new_kernel}/modules-${new_kernel}-*.tar.gz 2>/dev/null | head -n 1 )

            # 01 For /boot five files
            ( cd ${tmp_armbian}/boot && rm -rf *-${out_version}-* uInitrd zImage dtb* 2>/dev/null && sync )
            tar -xzf ${build_boot} -C ${tmp_armbian}/boot && sync
            [ "$( ls ${tmp_armbian}/boot/*-${new_kernel}-* -l 2>/dev/null | grep "^-" | wc -l )" -ge "4" ] || die "boot/ 5 files is missing."

            # 02 For dtb files
            mkdir -p ${tmp_armbian}/boot/dtb/amlogic && sync
            tar -xzf ${build_dtb} -C ${tmp_armbian}/boot/dtb/amlogic && sync

            # 03 For usr/lib/modules/*
            ( cd ${tmp_armbian}/usr/lib/modules && rm -rf * 2>/dev/null && sync )
            tar -xzf ${build_modules} -C ${tmp_armbian}/usr/lib/modules && sync
            ( cd ${tmp_armbian}/usr/lib/modules/*/ && echo "build source" | xargs rm -f && sync )
            if [ "$(ls ${tmp_armbian}/usr/lib/modules/${new_kernel}* -l 2>/dev/null | grep "^d" | wc -l)" -ne "1" ]; then
                die "${tmp_armbian}/usr/lib/modules/${new_kernel}-* kernel folder is missing."
            fi

            sync
    fi
}

copy_files() {
    cd ${tmp_armbian}

        #Check if writing to EMMC is supported
        MODULES_NOW=$(ls usr/lib/modules/ 2>/dev/null)
        VERSION_NOW=$(echo ${MODULES_NOW} | grep -oE '^[1-9].[0-9]{1,3}' 2>/dev/null)
        #echo -e "This Kernel [ ${VERSION_NOW} ]"

        k510_ver=$(echo "${VERSION_NOW}" | cut -d '.' -f1)
        k510_maj=$(echo "${VERSION_NOW}" | cut -d '.' -f2)
        if  [ "${k510_ver}" -eq "5" ];then
            if  [ "${k510_maj}" -ge "10" ];then
                K510="1"
            else
                K510="0"
            fi
        elif [ "${k510_ver}" -gt "5" ];then
            K510="1"
        else
            K510="0"
        fi
        #echo -e "K510: [ ${K510} ]"

        case "${build_soc}" in
            s905x3 | x96 | hk1 | h96 | ugoosx3)
                FDTFILE="meson-sm1-x96-max-plus-100m.dtb"
                UBOOT_OVERLOAD="u-boot-x96maxplus.bin"
                MAINLINE_UBOOT="/lib/u-boot/x96maxplus-u-boot.bin.sd.bin"
                ANDROID_UBOOT="/lib/u-boot/hk1box-bootloader.img"
                AMLOGIC_SOC="s905x3"
                ;;
            s905x2 | x96max4g | x96max2g)
                FDTFILE="meson-g12a-x96-max.dtb"
                UBOOT_OVERLOAD="u-boot-x96max.bin"
                MAINLINE_UBOOT="/lib/u-boot/x96max-u-boot.bin.sd.bin"
                ANDROID_UBOOT=""
                AMLOGIC_SOC="s905x2"
                ;;
            s905x | hg680p | b860h)
                FDTFILE="meson-gxl-s905x-p212.dtb"
                UBOOT_OVERLOAD="u-boot-p212.bin"
                MAINLINE_UBOOT=""
                ANDROID_UBOOT=""
                AMLOGIC_SOC="s905x"
                ;;
            s905w | x96mini | tx3mini)
                FDTFILE="meson-gxl-s905w-tx3-mini.dtb"
                UBOOT_OVERLOAD="u-boot-s905x-s912.bin"
                MAINLINE_UBOOT=""
                ANDROID_UBOOT=""
                AMLOGIC_SOC="s905w"
                ;;
            s905d | n1)
                FDTFILE="meson-gxl-s905d-phicomm-n1.dtb"
                UBOOT_OVERLOAD="u-boot-n1.bin"
                MAINLINE_UBOOT=""
                ANDROID_UBOOT="/lib/u-boot/u-boot-2015-phicomm-n1.bin"
                AMLOGIC_SOC="s905d"
                ;;
            s912 | h96proplus | octopus)
                FDTFILE="meson-gxm-octopus-planet.dtb"
                UBOOT_OVERLOAD="u-boot-zyxq.bin"
                MAINLINE_UBOOT=""
                ANDROID_UBOOT=""
                AMLOGIC_SOC="s912"
                ;;
            s922x | belink | belinkpro | ugoos)
                FDTFILE="meson-g12b-gtking-pro.dtb"
                UBOOT_OVERLOAD="u-boot-gtkingpro.bin"
                MAINLINE_UBOOT="/lib/u-boot/gtkingpro-u-boot.bin.sd.bin"
                ANDROID_UBOOT=""
                AMLOGIC_SOC="s922x"
                ;;
            s922x-n2 | odroid-n2 | n2)
                FDTFILE="meson-g12b-gtking-pro-rev_a.dtb"
                UBOOT_OVERLOAD="u-boot-odroid-n2.bin"
                MAINLINE_UBOOT="/lib/u-boot/odroid-n2-u-boot.bin.sd.bin"
                ANDROID_UBOOT=""
                AMLOGIC_SOC="s922x-n2"
                ;;
            *)
                die "Have no this soc: [ ${build_soc} ]"
                ;;
        esac

    cd ${make_path}

        # Write the specified bootloader
        if  [[ "${MAINLINE_UBOOT}" != "" && -f "${tag_rootfs}/usr${MAINLINE_UBOOT}" ]]; then
            dd if=${tag_rootfs}/usr${MAINLINE_UBOOT} of=${loop_new} bs=1 count=444 conv=fsync 2>/dev/null
            dd if=${tag_rootfs}/usr${MAINLINE_UBOOT} of=${loop_new} bs=512 skip=1 seek=1 conv=fsync 2>/dev/null
            #echo -e "For [ ${build_soc} ] write Mainline bootloader: ${MAINLINE_UBOOT}"
        elif [[ "${ANDROID_UBOOT}" != ""  && -f "${tag_rootfs}/usr${ANDROID_UBOOT}" ]]; then
            dd if=${tag_rootfs}/usr${ANDROID_UBOOT} of=${loop_new} bs=1 count=444 conv=fsync 2>/dev/null
            dd if=${tag_rootfs}/usr${ANDROID_UBOOT} of=${loop_new} bs=512 skip=1 seek=1 conv=fsync 2>/dev/null
            #echo -e "For [ ${build_soc} ] write Android bootloader: ${ANDROID_UBOOT}"
        fi
        sync

        # Reorganize the /boot partition
        mkdir -p ${tmp_build}/boot
        # Copy the original boot core file
        cp -rf ${tmp_armbian}/boot/*-${make_version}-* ${tmp_build}/boot && sync
        ( cd ${tmp_build}/boot && cp -f uInitrd-* uInitrd && cp -f vmlinuz-* zImage && chmod +x * && sync )
        # Unzip the relevant files
        tar -xzf "${armbian_path}/boot-common.tar.gz" -C ${tmp_build}/boot
        tar -xzf "${armbian_path}/root-common.tar.gz" -C ${tmp_armbian}
        # Complete the u-boot file to facilitate the booting of the 5.10+ kernel
        cp -f ${uboot_path}/* ${tmp_build}/boot && sync
        # Complete the dtb file
        cp -rf ${dtb_path}/* ${tmp_build}/boot/dtb/amlogic && sync
        cp -rf ${tmp_armbian}/boot/dtb/amlogic/* ${tmp_build}/boot/dtb/amlogic && sync
        chmod +x ${tmp_build}/boot/dtb/amlogic/*

        # Create a dual-partition general directory
        tag_bootfs="${tmp_outpath}/bootfs"
        tag_rootfs="${tmp_outpath}/rootfs"
        mkdir -p ${tag_bootfs} ${tag_rootfs} && sync

        if ! mount ${loop_new}p2 ${tag_rootfs}; then
            die "mount ${loop_new}p2 failed!"
        fi
        if ! mount ${loop_new}p1 ${tag_bootfs}; then
            die "mount ${loop_new}p1 failed!"
        fi

        # Copy boot files
        cp -rf ${tmp_build}/boot/* ${tag_bootfs} && sync

        # Copy rootfs files
        rm -rf ${tmp_armbian}/boot/* 2>/dev/null
        cp -rf ${tmp_armbian}/* ${tag_rootfs} && sync
        # Complete file for ${root}: [ /etc ], [ /usr/lib/u-boot ] etc.
        if [ "$(ls ${configfiles_path}/files 2>/dev/null | wc -w)" -ne "0" ]; then
            cp -rf ${configfiles_path}/files/* ${tag_rootfs} && sync
        fi
        
    cd ${tag_bootfs}

        # Add u-boot.ext for 5.10 kernel
        if [[ -n "${UBOOT_OVERLOAD}" && -f "${UBOOT_OVERLOAD}" ]]; then
            cp -f ${UBOOT_OVERLOAD} u-boot.ext && sync
            chmod +x u-boot.ext
        fi

        # Edit the uEnv.txt
        if [  ! -f "uEnv.txt" ]; then
           die "The uEnv.txt File does not exist"
        else
           old_fdt_dtb="meson-gxl-s905d-phicomm-n1.dtb"
           sed -i "s/${old_fdt_dtb}/${FDTFILE}/g" uEnv.txt
        fi

        sync

    cd ${tag_rootfs}

        # Replace the boot directory with the latest file
        rm -rf boot/* 2>/dev/null && sync

        ( cd usr/lib/firmware && mv *.hcd brcm/ )

        # Add soft connection
        ln -sf usr/bin bin
        ln -sf usr/lib lib
        ln -sf usr/sbin sbin
        ln -sf var/tmp tmp
        ln -sf usr/share/zoneinfo/Asia/Shanghai etc/localtime
        chmod 777 var/tmp
        chown man:root var/cache/man -R
        chmod g+s var/cache/man -R

        # Delete related files
        rm -f etc/apt/sources.list.save 2>/dev/null
        rm -f etc/apt/*.gpg~ 2>/dev/null
        rm -f etc/systemd/system/basic.target.wants/armbian-resize-filesystem.service 2>/dev/null
        rm -f var/lib/dpkg/info/linux-image* 2>/dev/null

        # Add firmware information to the etc/armbian-aml-release
        echo "FDTFILE='${FDTFILE}'" >> etc/armbian-aml-release 2>/dev/null
        echo "U_BOOT_EXT='${K510}'" >> etc/armbian-aml-release 2>/dev/null
        echo "UBOOT_OVERLOAD='${UBOOT_OVERLOAD}'" >> etc/armbian-aml-release 2>/dev/null
        echo "MAINLINE_UBOOT='${MAINLINE_UBOOT}'" >> etc/armbian-aml-release 2>/dev/null
        echo "ANDROID_UBOOT='${ANDROID_UBOOT}'" >> etc/armbian-aml-release 2>/dev/null
        echo "KERNEL_VERSION='${KERNEL_VERSION}'" >> etc/armbian-aml-release 2>/dev/null
        echo "SOC='${AMLOGIC_SOC}'" >> etc/armbian-aml-release 2>/dev/null
        echo "K510='${K510}'" >> etc/armbian-aml-release 2>/dev/null
        
        # Custom banner name
        sed -i "s|BOARD_NAME=.*|BOARD_NAME=\"Aml ${AMLOGIC_SOC}\"|g" etc/armbian-release

        # remove linux-image-current-meson64
        sudo chroot ${tag_rootfs} && apt update && apt upgrade –y && apt remove linux-image-current-meson64 -y && exit

        sync

    cd ${make_path}

        umount -f ${tmp_armbian} 2>/dev/null

        umount -f ${tag_rootfs} 2>/dev/null
        umount -f ${tag_bootfs} 2>/dev/null

        losetup -D 2>/dev/null
        sync
}

clean_tmp() {
    cd ${tmp_outpath}
        gzip *.img && sync && mv -f *.img.gz ${armbian_outputpath}
        sync

    cd ${make_path}
        rm -rf ${tmp_armbian} ${tmp_build} ${tmp_outpath} ${tmp_aml_image} 2>/dev/null
        sync
}

[ $(id -u) = 0 ] || die "please run this script as root: [ sudo ./make ]"
echo -e "Welcome to build armbian for amlogic s9xxx STB! \n"
echo -e "Server space usage before starting to compile: \n$(df -hT ${PWD}) \n"
echo -e "Ready, start build armbian... \n"

# Start loop compilation
k=1
for b in ${build_armbian[*]}; do

    i=1
    for x in ${build_kernel[*]}; do
        {
            echo -n "(${k}.${i}) Start build armbian [ ${b} - ${x} ]. "
            now_remaining_space=$(df -hT ${PWD} | grep '/dev/' | awk '{print $5}' | sed 's/.$//')
            if  [[ "${now_remaining_space}" -le "2" ]]; then
                echo "Remaining space is less than 2G, exit this packaging. \n"
                break
            else
                echo "Remaining space is ${now_remaining_space}G."
            fi

            build_soc="${b}"
            if [ "${x}" == "default" ]; then
                new_kernel=""
                out_kernel=""
            else
                new_kernel="${x}"
                out_kernel=" - ${x}"
            fi

            process " (1/5) make new armbian image."
            make_image
            process " (2/5) extract old armbian files."
            extract_armbian
            process " (3/5) replace kernel for armbian."
            replace_kernel
            process " (4/5) copy files to new image."
            copy_files
            process " (5/5) clear temp files."
            clean_tmp

            echo -e "(${k}.${i}) Build successfully. \n"
            let i++
        }
    done

    let k++
done

echo -e "Server space usage after compilation: \n$(df -hT ${PWD}) \n"
sync
exit 0


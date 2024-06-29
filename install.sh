#!/bin/bash

echo "
██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗███████╗
██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██╔════╝
██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║█████╗  
██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██╔══╝  
╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗
 ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝
                                                              
"
main() {
    echo "Checking internet connection"
    ping -c 3 archlinux.org >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo "You are not connected to internert. Please connect and try angain later."
        exit 2
    fi
    echo "Updating pacman db"
    timedatectl set-ntp true
    sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
    echo -e "ILoveCandy\nColor" >>/etc/pacman.conf
    pacman -S --noconfirm --needed reflector
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.old
    reflector -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Syy

    read -p "Mount point: " mount
    echo "${mount}"
    if findmnt /mnt/efi >/dev/null 2>&1; then
        echo "efi partition does not exist."
        exit 1
    fi
    echo "Install base system"
    pacstrap -K /mnt base base-devel linux linux-lts linux-headers linux-lts-headers vim nano git wget curl linux-firmware intel-ucode dosfstools ntfs-3g networkmanager man texinfo terminus-font --noconfirm --needed

    echo "Generating fstab"
    genfstab -U /mnt >>/mnt/etc/fstab

    while true; do
        read -p "Chroot to continue instalation? (y,n) " archroot
        case "${archroot,,}" in
        "yes" | "y")
            system_install
            break
            ;;
        "no" | "n")
            echo "exit."
            exit 0
            ;;
        *)
            echo "Invalid input."
            ;;
        esac
    done
}

system_install() {
    echo "Chrooting..."
    arch-chroot /mnt
    regions=($(ls /usr/share/zoneinfo/))
    PS3="Please select your region: "

    select region in "${regions[@]}"; do
        if [ -n "$region" ]; then
            echo "You selected: $region"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done

    cities=($(ls /usr/share/zoneinfo/${region}/))
    PS3="Please select your region: "

    select city in "${cities[@]}"; do
        if [ -n "$city" ]; then
            echo "You selected: $city"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done

    ln -sf /usr/share/zoneinfo/${region}/${city} /etc/localtime
    hwclock --systohc
    echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
    locale-gen

    echo -e "LANG=en_US.UTF-8\nFONT=ter-v22b" >/etc/locale.conf

    echo "KEYMAP=fr" >/etc/vconsole.conf

    read -p "Enter hostname: " host_name
    echo "${host_name}" >/etc/hostname

    echo -e "127.0.0.1\tlocalhost\n::1\t\t\tlocalhost ip6-localhost ip6-loopback\nff02::1\t\tip6-allnodes\nff02::2\t\tip6-allrouters\n172.0.1.1\t${host_name}" >>/etc/hosts
    systemctl enable NetworkManager.service

    echo "Creating initramfs"
    mkinitcpio -P

    echo "Set root password"
    passwd

    echo "Setup the bootloader"
    pacman -S grub efibootmgr os-prober --noconfirm --needed
    # TODO: Add mounting other system to detect them by brub for multibooting
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Arch
    echo "GRUB_DISABLE_OS_PROBER=false" >>/etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg

    echo "Creating a user"
    read "User name: " usrname
    useradd -m -g users -G wheel "${usrname}"
    passwd "${usrname}"

    echo "
██████╗  ██████╗ ███╗   ██╗███████╗
██╔══██╗██╔═══██╗████╗  ██║██╔════╝
██║  ██║██║   ██║██╔██╗ ██║█████╗  
██║  ██║██║   ██║██║╚██╗██║██╔══╝  
██████╔╝╚██████╔╝██║ ╚████║███████╗
╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝
                                   
"
}

if [[ $# -gt 1 ]]; then
    echo "Usage: ./install.sh [install]"
    exit 3
elif [[ $# -eq 1 && $1 == "install" ]]; then
    system_install
else
    main
fi

exit 0

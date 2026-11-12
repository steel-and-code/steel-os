#!/usr/bin/bash
# Based on Bazzite (github.com/ublue-os/bazzite), Apache-2.0. Modified for Steel OS by Steel & Code (STEEL-35).
#
# Runs when the live session desktop starts. In order:
#   1. Refuse to continue on an old BIOS (CSM/Legacy) start; Steel OS needs UEFI.
#   2. Warn and stop if the PC has too little memory to install.
#   3. Warn if another Linux boot loader is on the disk (dual boot with another
#      Linux is not supported).
#   4. Tell NVIDIA owners what to expect from this edition.
#   5. Welcome: Install Steel OS, Try it first, or Repair the startup menu.
# Plain English, no links to documentation the user cannot reach yet.

conky -c /usr/share/conky/conky.conf &
# Offers "Restart now" once an install has finished and the installer is closed.
/usr/bin/steel-os-install-done &
# Explains a failed install in plain English, over the installer's own box.
/usr/bin/steel-os-install-failed &
# The session clock shows local time: a guess from the location service, then
# the time zone chosen in the installer.
/usr/bin/steel-os-live-clock &

shutdown_now() {
    systemctl poweroff || shutdown -h now || true
}

# 1. UEFI only
if [[ ! -d /sys/firmware/efi ]]; then
    yad --undecorated --on-top --timeout=0 --button="Shut down:0" \
        --text="<b>This PC started in old BIOS (CSM/Legacy) mode.</b>\n\nSteel OS needs UEFI. Open your PC's firmware settings (often F2 or Del at start-up),\nturn off CSM or Legacy mode, then start from the USB stick again." || true
    shutdown_now
fi

# 2. Memory
block_low_memory_install() {
    local memory gb_memory
    memory=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
    gb_memory=$(awk '/^MemTotal/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo)
    [[ -z "$memory" || "$memory" -eq 0 ]] && return 0
    [[ "$memory" -ge 5000000 ]] && return 0
    while true; do
        yad --undecorated --on-top --timeout=0 --warning --buttons-layout=center --text-align=center \
            --title="Not enough memory" --button="Shut down:0" \
            --text="Steel OS needs <b>at least 8 GB of memory</b> to install.\nWith 4 GB or less the installation will almost certainly fail.\n\nThis PC has: $gb_memory"
        [[ $? -eq 0 ]] && { shutdown_now; break; }
    done
}
block_low_memory_install

# 3. Another Linux boot loader on the disk
efi="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
declare -A mount
while read -r device path; do
    mount["$device"]="-o bind,ro $path"
done < <(lsblk -o PATH,MOUNTPOINTS -nQ 'PARTTYPE=="'$efi'" && MOUNTPOINTS' 2> /dev/null || true)
for device in $(lsblk -o PATH -nQ 'PARTTYPE=="'$efi'" && !MOUNTPOINTS' 2> /dev/null || true); do
    mount["$device"]="-o ro -t vfat $device"
done
mnt=$(mktemp -d)
export mnt
trap 'rmdir "$mnt"' EXIT
for device in "${!mount[@]}"; do
    export device
    msg=$(sudo -E unshare -m sh -c '
        mount '"${mount[$device]} '$mnt'"' 2> /dev/null || exit 0
        shopt -s nullglob nocaseglob
        for dir in "$mnt"/EFI/*; do
            [ -d "$dir" ] || continue
            base=$(basename "$dir" | tr "[:upper:]" "[:lower:]")
            [[ "$base" == "fedora" || "$base" == "boot" ]] && continue
            grub=("$dir"/grub*.efi)
            (( ! ${#grub[@]} )) && continue
            echo "Another Linux system seems to be installed on $device (${dir#$mnt}).\n\nSteel OS cannot share a disk with another Linux system. Installing to this disk\nwhile keeping that system will fail.\n\nInstall Steel OS to a different disk, or choose <b>Use entire disk</b> to replace\neverything on this one. Make sure you have a backup first."
        done
    ' || true)
    [ "$msg" ] || continue
    yad --image=dialog-warning --button=OK --buttons-layout=center \
        --title="Another Linux system found" --text="$msg"
done

# 4. NVIDIA graphics
nvidia_notice() {
    lspci -nn 2>/dev/null | grep -E '\[03[0-9]{2}\]' | grep -qi 'nvidia' || return 0
    yad --info --buttons-layout=center --text-align=center --title="NVIDIA graphics card found" \
        --button="Continue:0" --button="Shut down:1" \
        --text="This PC has an <b>NVIDIA graphics card</b>.\n\nInstall as normal. After the first start, with the internet connected, Steel OS\ndownloads the edition with NVIDIA's own driver by itself and asks you to restart once.\n\nVery old NVIDIA cards (before the GTX 900 series) keep the open-source driver."
    [[ $? -eq 1 ]] && shutdown_now
    return 0
}
nvidia_notice

# 5. Welcome
welcome_dialog() {
    local choice
    while true; do
        yad --no-escape --on-top --buttons-layout=center --text-align=center \
            --title="Welcome to Steel OS" \
            --image=steel-os \
            --text="<big><b>Welcome to Steel OS</b></big>\n\n<b>Nothing on this computer has been changed yet.</b>\nSteel OS is running in a live session.\n\nInstall it now, or look around first. The installer is also on the desktop." \
            --button="Install Steel OS:10" \
            --button="Try Steel OS first:0" \
            --button="Repair the startup menu:20"
        choice=$?
        case $choice in
        10) liveinst & disown $!; return ;;
        20) /usr/bin/bootloader_restore & disown $!; return ;;
        0) return ;;
        esac
    done
}
welcome_dialog

#!/usr/bin/env bash
# ==============================================================================
#  NEXA Power & Battery Management Script
#  Target: AMD Ryzen APU + Realtek Wi-Fi / Linux (Arch Linux)
# ==============================================================================

set -e

# Needs root for writing to /sys, auto-elevate with sudo if not root
elevate_if_needed() {
    if [ "$EUID" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            exec sudo "$0" "$@"
        else
            echo "Error: This script requires root privileges (sudo)." >&2
            exit 1
        fi
    fi
}

optimize_pci() {
    echo "[*] Optimizing PCIe Runtime Power Management..."
    for dev in /sys/bus/pci/devices/*; do
        if [ -f "$dev/power/control" ]; then
            echo auto > "$dev/power/control" 2>/dev/null || true
        fi
    done
}

optimize_aspm() {
    echo "[*] Setting PCIe ASPM policy to powersupersave..."
    if [ -f /sys/module/pcie_aspm/parameters/policy ]; then
        echo powersupersave > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || \
        echo powersave > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true
    fi
}

optimize_sata() {
    echo "[*] Setting SATA Link Power Management to med_power_with_dipm..."
    for host in /sys/class/scsi_host/host*; do
        if [ -f "$host/link_power_management_policy" ]; then
            echo med_power_with_dipm > "$host/link_power_management_policy" 2>/dev/null || true
        fi
    done
}

optimize_usb() {
    echo "[*] Configuring USB autosuspend (excluding keyboards, mice & HID devices)..."
    for d in /sys/bus/usb/devices/*; do
        if [ -f "$d/power/control" ]; then
            # Protect all HID input devices (keyboards, mice, controllers: class 03)
            is_hid=false
            for iface_class in "$d"/*/bInterfaceClass; do
                if [ -f "$iface_class" ] && [ "$(cat "$iface_class" 2>/dev/null)" = "03" ]; then
                    is_hid=true
                    break
                fi
            done

            if [ "$is_hid" = true ]; then
                echo on > "$d/power/control" 2>/dev/null || true
                continue
            fi

            # Also explicitly protect known keyboard/mouse IDs
            if [ -f "$d/idVendor" ] && [ -f "$d/idProduct" ]; then
                vid=$(cat "$d/idVendor" 2>/dev/null)
                pid=$(cat "$d/idProduct" 2>/dev/null)
                if [ "$vid:$pid" = "17ef:60ac" ] || [ "$vid:$pid" = "3151:5002" ]; then
                    echo on > "$d/power/control" 2>/dev/null || true
                    continue
                fi
            fi

            echo auto > "$d/power/control" 2>/dev/null || true
        fi
    done
}

optimize_audio() {
    echo "[*] Enabling audio power save..."
    if [ -f /sys/module/snd_hda_intel/parameters/power_save ]; then
        echo 1 > /sys/module/snd_hda_intel/parameters/power_save 2>/dev/null || true
    fi
    if [ -f /sys/module/snd_hda_intel/parameters/power_save_controller ]; then
        echo Y > /sys/module/snd_hda_intel/parameters/power_save_controller 2>/dev/null || true
    fi
}

optimize_vm() {
    echo "[*] Adjusting VM dirty writeback buffering (reducing disk wakeups)..."
    if [ -f /proc/sys/vm/dirty_writeback_centisecs ]; then
        echo 6000 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null || true
    fi
}

optimize_wifi() {
    echo "[*] Ensuring Wi-Fi power save is active..."
    if command -v iw >/dev/null 2>&1; then
        for iface in $(iw dev | awk '$1=="Interface"{print $2}'); do
            iw dev "$iface" set power_save on 2>/dev/null || true
        done
    fi
}

show_status() {
    echo "=================================================="
    echo "            NEXA Power & Battery Status           "
    echo "=================================================="
    if command -v upower >/dev/null 2>&1; then
        bat=$(upower -e | grep BAT | head -n 1)
        if [ -n "$bat" ]; then
            upower -i "$bat" | grep -E "state:|energy-rate:|percentage:|time to empty:|capacity:"
        fi
    fi
    echo "--------------------------------------------------"
    if [ -f /sys/module/pcie_aspm/parameters/policy ]; then
        echo "PCIe ASPM Policy: $(cat /sys/module/pcie_aspm/parameters/policy)"
    fi
    if [ -f /sys/bus/pci/devices/0000:02:00.0/power/control ]; then
        echo "Realtek Wi-Fi (02:00.0) Runtime PM: $(cat /sys/bus/pci/devices/0000:02:00.0/power/control)"
    fi
    if [ -f /sys/bus/pci/devices/0000:01:00.0/power/control ]; then
        echo "Realtek Ethernet (01:00.0) Runtime PM: $(cat /sys/bus/pci/devices/0000:01:00.0/power/control)"
    fi
    for d in /sys/bus/usb/devices/*; do
        if [ -f "$d/idVendor" ] && [ -f "$d/idProduct" ]; then
            vid=$(cat "$d/idVendor" 2>/dev/null)
            pid=$(cat "$d/idProduct" 2>/dev/null)
            prod=$(cat "$d/product" 2>/dev/null)
            if [ "$vid:$pid" = "17ef:60ac" ] || [ "$vid:$pid" = "3151:5002" ]; then
                echo "$prod ($vid:$pid) PM: $(cat "$d/power/control" 2>/dev/null) (protected)"
            fi
        fi
    done
    echo "=================================================="
}

install_service() {
    elevate_if_needed "$@"
    echo "[*] Creating /etc/systemd/system/nexa-power-tune.service..."
    cat << 'EOF' > /etc/systemd/system/nexa-power-tune.service
[Unit]
Description=NEXA System Power & Battery Optimization
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "/home/shnx/.config/nexa/scripts/power.sh optimize"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now nexa-power-tune.service
    echo "[✔] nexa-power-tune.service installed and enabled successfully."
}

case "${1:-optimize}" in
    optimize|apply)
        elevate_if_needed "$@"
        optimize_pci
        optimize_aspm
        optimize_sata
        optimize_usb
        optimize_audio
        optimize_vm
        optimize_wifi
        echo "[✔] NEXA Power optimizations applied successfully."
        ;;
    status)
        show_status
        ;;
    install)
        install_service "$@"
        ;;
    *)
        echo "Usage: $0 [optimize|status|install]"
        exit 1
        ;;
esac


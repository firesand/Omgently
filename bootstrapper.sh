#!/bin/bash
# GENTOO-OMARCHY BOOTSTRAPPER (TUI)
set -euo pipefail
HISTFILE=/dev/null
set +H
umask 077
YAML_FILE="$(mktemp /tmp/omarchy_vars.XXXXXX.yml)"
cleanup() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ]; then
        echo "⚠️  Proses gagal. File konfigurasi disimpan untuk debugging: $YAML_FILE"
        echo "   Hapus manual setelah selesai: rm -f \"$YAML_FILE\""
    else
        rm -f "$YAML_FILE"
    fi
}
trap cleanup EXIT

# === OPINIONATED DEFAULTS (Edit di sini jika ingin mengubah) ===
DOAS_INSTEAD_OF_SUDO=true
DEFAULT_TERMINAL="ghostty"
DEFAULT_BROWSER="brave"
INSTALL_DOTFILES=true

clear
echo "🚀 Memulai Pre-flight Checks..."

# 1. JARINGAN
while ! ping -c 2 8.8.8.8 &> /dev/null; do
    if whiptail --title "Internet Terputus" --yesno "Koneksi internet tidak terdeteksi.\nApakah Anda ingin mengatur Wi-Fi sekarang?" 10 60; then
        if command -v nmtui &> /dev/null; then nmtui;
        elif command -v iwctl &> /dev/null; then echo "Ketik 'station wlan0 connect <WiFi>' lalu 'exit'."; sleep 3; iwctl;
        else echo "Alat jaringan tidak ditemukan. Hubungkan manual."; exit 1; fi
    else exit 1; fi
done
echo "✅ Internet terhubung."

# 2. WAKTU
echo "⏳ Menyinkronkan waktu sistem (NTP)..."
if command -v chronyd &> /dev/null; then chronyd -q 'server pool.ntp.org iburst' &> /dev/null || true;
elif command -v ntpd &> /dev/null; then ntpd -qg &> /dev/null || true; fi

# 3. WHIPTAIL HELPERS
if ! command -v whiptail &> /dev/null; then
    echo "⚠️  whiptail tidak ditemukan. Mencoba memasang otomatis..."
    if command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm libnewt
    elif command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y whiptail
    elif command -v emerge &> /dev/null; then
        emerge --oneshot dev-libs/newt
    else
        echo "❌ Tidak ada package manager yang dikenali untuk memasang whiptail."
        exit 1
    fi
fi
# Gunakan "--" agar nilai default yang diawali '-' (contoh: -j8 -l8) tidak diparsing sebagai opsi whiptail.
ask_input() { whiptail --title "$1" --inputbox "$2" 10 60 -- "$3" 3>&1 1>&2 2>&3; }
ask_menu() { whiptail --title "$1" --menu "$2" 15 70 5 "${@:3}" 3>&1 1>&2 2>&3; }
ask_yesno() { whiptail --title "$1" --yesno "$2" 10 60; }
yaml_quote() {
    local escaped
    escaped="$(printf "%s" "$1" | sed "s/'/''/g")"
    printf "'%s'" "$escaped"
}
ask_input_validated() {
    local title="$1"
    local prompt="$2"
    local default="$3"
    local regex="$4"
    local invalid_msg="$5"
    local value

    while true; do
        value="$(ask_input "$title" "$prompt" "$default")" || exit 1
        if [[ "$value" =~ $regex ]]; then
            printf "%s" "$value"
            return 0
        fi
        whiptail --title "Input Tidak Valid" --msgbox "$invalid_msg" 10 70
    done
}

# 4. PENGUMPULAN DATA
HOSTNAME=$(ask_input_validated "Hostname" "Masukkan hostname sistem:" "omarchy-gentoo" '^[a-zA-Z0-9._-]+$' "Gunakan hanya huruf, angka, titik, underscore, atau strip.")
TIMEZONE=$(ask_input_validated "Timezone" "Masukkan timezone Anda:" "Asia/Jakarta" '^[A-Za-z0-9_+./-]+$' "Format timezone tidak valid. Contoh: Asia/Jakarta")
SYSTEM_LOCALE=$(ask_input_validated "Locale" "Masukkan locale default sistem:" "en_US.UTF-8" '^[a-z]{2}_[A-Z]{2}\.[A-Za-z0-9_-]+$' "Format locale tidak valid. Gunakan format seperti: en_US.UTF-8")

if ask_yesno "Dual-Boot" "Apakah mesin ini dual-boot (macOS/Windows)?\n(hwclock akan dikunci ke UTC)"; then HWCLOCK="UTC"; else HWCLOCK="local"; fi

CORES=$(nproc)
MAKEOPTS=$(ask_input "Kompilasi (MAKEOPTS)" "Jumlah thread CPU terdeteksi: $CORES" "-j$CORES -l$CORES")
MARCH=$(ask_input "Kompilasi (CFLAGS)" "Arsitektur target (-march):" "native")
CPU_VENDOR=$(awk -F: '/vendor_id/{gsub(/^[ \t]+/, "", $2); print tolower($2); exit}' /proc/cpuinfo)
if [[ "$CPU_VENDOR" == *"intel"* ]]; then CPU_VENDOR="intel";
elif [[ "$CPU_VENDOR" == *"amd"* ]]; then CPU_VENDOR="amd";
else CPU_VENDOR="generic"; fi

DISKS=$(lsblk -d -n -p -o NAME,SIZE,MODEL,TYPE | awk '$4=="disk" {desc=$2; for(i=3; i<NF; i++) desc=desc "_" $i; print $1 " " desc}')
DISK_MENU=(); while read -r dev desc; do DISK_MENU+=("$dev" "$(echo "$desc" | tr '_' ' ')"); done <<< "$DISKS"
TARGET_DISK=$(ask_menu "Partisi Disk" "Pilih drive instalasi (AKAN DIHAPUS):" "${DISK_MENU[@]}")
if [ -z "$TARGET_DISK" ]; then exit 1; fi

PART_LAYOUT=$(ask_menu "Skema Partisi" "Pilih struktur direktori:" "flat" "Hanya /boot/efi dan / (Menyatu)" "separate_home" "/boot/efi, /, dan /home terpisah")
if [ "$PART_LAYOUT" == "separate_home" ]; then
    ROOT_SIZE=$(ask_input_validated "Ukuran Root" "Ukuran / (Root) dalam GB:" "50" '^[1-9][0-9]*$' "Ukuran root harus angka bulat positif (GB).")
else
    ROOT_SIZE="0"
fi
SWAP_SIZE=$(ask_input_validated "Ukuran Swap" "Ukuran partisi swap dalam GB:" "8" '^[1-9][0-9]*$' "Ukuran swap harus angka bulat positif (GB).")
if [ "$SWAP_SIZE" -gt 128 ]; then
    whiptail --title "Peringatan Swap Besar" --yesno "Swap ${SWAP_SIZE}GB terdeteksi.\nIni cukup besar dan bisa jadi typo.\n\nTetap lanjut?" 12 70 || exit 1
fi

FILESYSTEM=$(ask_menu "Filesystem" "Pilih format Root:" "btrfs" "Modern, snapshot, zstd" "ext4" "Klasik, stabil" "xfs" "Performa tinggi")
INIT_SYS=$(ask_menu "Init System" "Pilih Init System:" "systemd" "Modern (Disarankan untuk Wayland)" "openrc" "Klasik")
GPU_VENDOR=$(ask_menu "GPU (Wayland Base)" "Pilih GPU utama:" "nvidia" "NVIDIA Proprietary" "amd" "AMD Radeon" "intel" "Intel Graphics")
DEVICE_TYPE=$(ask_menu "Tipe Perangkat" "Jenis mesin ini:" "laptop" "Laptop / Portable (WiFi, Baterai, Bluetooth)" "desktop" "Desktop PC / Workstation")
KEYWORD_PROFILE=$(ask_menu "Portage Keywords" "Pilih profile paket:" "stable" "ACCEPT_KEYWORDS=amd64 (stabil)" "testing" "ACCEPT_KEYWORDS=~amd64 (lebih baru, lebih berisiko)")
if [ "$KEYWORD_PROFILE" == "testing" ]; then
    ACCEPT_KEYWORDS="~amd64"
else
    ACCEPT_KEYWORDS="amd64"
fi
LICENSE_MODE=$(ask_menu "Mode Lisensi" "Pilih mode lisensi package:" "standard" "ACCEPT_LICENSE=* (praktis, termasuk non-free)" "strict_foss" "ACCEPT_LICENSE=@FREE (hanya lisensi bebas)")
if [ "$LICENSE_MODE" == "strict_foss" ]; then
    ACCEPT_LICENSE="@FREE"
else
    ACCEPT_LICENSE="*"
fi
if [ "$ACCEPT_KEYWORDS" == "~amd64" ] && [ "$ACCEPT_LICENSE" == "@FREE" ]; then
    whiptail --title "Peringatan Kombinasi" --yesno "Anda memilih Testing (~amd64) + Strict FOSS.\n\nKombinasi ini dapat menyebabkan konflik dependensi,\nterutama untuk driver GPU proprietary dan firmware.\n\nTetap lanjut?" 14 70 || exit 1
fi
KERNEL_TYPE=$(ask_menu "Tipe Kernel" "Pilih instalasi kernel:" "bin" "gentoo-kernel-bin (Cepat)" "source" "Kompilasi manual")

if [ "$INIT_SYS" == "systemd" ]; then
    BOOTLOADER=$(ask_menu "Bootloader" "Pilih Bootloader:" "systemd-boot" "Cepat & Minimalis" "limine" "Elegan (Multi-OS)" "grub" "Klasik" "efistub" "Ekstrem (Tanpa Bootloader)")
else
    BOOTLOADER=$(ask_menu "Bootloader" "Pilih Bootloader:" "limine" "Elegan (Multi-OS)" "grub" "Klasik" "efistub" "Ekstrem (Tanpa Bootloader)")
fi

LOGIN_STYLE=$(ask_menu "Gaya Login" "Pilih sesi masuk:" "dm" "Greetd (TUI elegan, otomatis ke Hyprland)" "tty" "TTY murni")

USERNAME=$(ask_input_validated "User Setup" "Masukkan username utama:" "koki" '^[a-z_][a-z0-9_-]{0,31}$' "Username harus lowercase, diawali huruf/underscore, maks 32 karakter.")
if [ "$USERNAME" == "root" ]; then
    echo "❌ Tidak bisa menggunakan 'root' sebagai username utama."
    exit 1
fi
# Hardening: pastikan xtrace mati sebelum input rahasia.
set +x
PASSWORD=$(whiptail --title "User Password" --passwordbox "Password untuk $USERNAME:" 10 60 3>&1 1>&2 2>&3)
if [ -z "$PASSWORD" ]; then
    echo "❌ Password tidak boleh kosong."
    exit 1
fi
PASSWORD_CONFIRM=$(whiptail --title "Konfirmasi Password" --passwordbox "Ulangi password untuk $USERNAME:" 10 60 3>&1 1>&2 2>&3)
if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "❌ Konfirmasi password tidak cocok."
    exit 1
fi
unset PASSWORD_CONFIRM
DOTFILES_URL=$(ask_input_validated "Dotfiles Repo" "URL repositori dotfiles Anda:" "https://github.com/firesand/Omgently.git" '^https?://[A-Za-z0-9._~:/?#\[\]@!$&()*+,;=%-]+$' "URL dotfiles tidak valid.")
GENTOO_MIRROR=$(ask_input_validated "Gentoo Mirror" "Base URL mirror Gentoo:" "https://distfiles.gentoo.org" '^https?://[A-Za-z0-9._~:/?#\[\]@!$&()*+,;=%-]+$' "URL mirror tidak valid.")
if ! command -v curl &> /dev/null; then
    echo "❌ curl tidak ditemukan. Install curl terlebih dahulu."
    exit 1
fi
if ! command -v sgdisk &> /dev/null; then
    echo "❌ utilitas 'sgdisk' tidak ditemukan. Install paket gdisk terlebih dahulu."
    exit 1
fi
if ! command -v ansible-playbook &> /dev/null; then
    echo "⚠️ ansible-playbook tidak ditemukan. Mencoba memasang otomatis..."
    if command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm ansible
    elif command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y ansible
    elif command -v emerge &> /dev/null; then
        emerge --oneshot app-admin/ansible
    else
        echo "❌ Tidak ada package manager yang dikenali untuk memasang Ansible."
        exit 1
    fi
    if ! command -v ansible-playbook &> /dev/null; then
        echo "❌ Instalasi Ansible gagal. Silakan install manual lalu jalankan ulang bootstrapper."
        exit 1
    fi
fi
if ! curl -fsSL "${GENTOO_MIRROR%/}/releases/amd64/autobuilds/latest-stage3-amd64-${INIT_SYS}.txt" >/dev/null; then
    echo "❌ Mirror tidak valid atau tidak bisa diakses: $GENTOO_MIRROR"
    exit 1
fi
if command -v git &> /dev/null; then
    if ! git ls-remote "$DOTFILES_URL" &>/dev/null; then
        whiptail --title "Peringatan Dotfiles" --yesno "Repo dotfiles tidak bisa diverifikasi:\n$DOTFILES_URL\n\nLanjutkan tetap?" 12 70 || exit 1
    fi
fi

if lsblk -nrpo NAME,MOUNTPOINT "$TARGET_DISK" | awk '$2 != "" {found=1} END {exit !found}'; then
    whiptail --title "Peringatan Mount Aktif" --yesno "Disk $TARGET_DISK memiliki partisi yang sedang di-mount.\nMelanjutkan bisa merusak data.\n\nTetap lanjut?" 12 70 || exit 1
fi

whiptail --title "Konfirmasi Destruktif" --yesno "Ringkasan Instalasi:\n\nDisk Target  : $TARGET_DISK (AKAN DIHAPUS)\nFilesystem   : $FILESYSTEM\nSwap (GB)    : $SWAP_SIZE\nInit System  : $INIT_SYS\nBootloader   : $BOOTLOADER\nGPU          : $GPU_VENDOR\nDevice Type  : $DEVICE_TYPE\nKeywords     : $ACCEPT_KEYWORDS\nLicense      : $ACCEPT_LICENSE\nUsername     : $USERNAME\nDoas         : $DOAS_INSTEAD_OF_SUDO\nTerminal     : $DEFAULT_TERMINAL\nBrowser      : $DEFAULT_BROWSER\nDotfiles     : $INSTALL_DOTFILES\n\nPassword yang dimasukkan akan dipakai untuk user dan root.\n\nLanjutkan instalasi?" 24 74 || exit 0

PASS_HASH=$(openssl passwd -6 "$PASSWORD")
unset PASSWORD

# 5. EXPORT YAML
cat <<EOF > "$YAML_FILE"
---
system_hostname: $(yaml_quote "$HOSTNAME")
timezone: $(yaml_quote "$TIMEZONE")
system_locale: $(yaml_quote "$SYSTEM_LOCALE")
hwclock: $(yaml_quote "$HWCLOCK")
makeopts: $(yaml_quote "$MAKEOPTS")
cpu_threads: $(yaml_quote "$CORES")
march_target: $(yaml_quote "$MARCH")
cpu_vendor: $(yaml_quote "$CPU_VENDOR")
target_disk: $(yaml_quote "$TARGET_DISK")
partition_layout: $(yaml_quote "$PART_LAYOUT")
root_size_gb: $(yaml_quote "$ROOT_SIZE")
swap_size_gb: $(yaml_quote "$SWAP_SIZE")
filesystem: $(yaml_quote "$FILESYSTEM")
init_system: $(yaml_quote "$INIT_SYS")
gpu_vendor: $(yaml_quote "$GPU_VENDOR")
device_type: $(yaml_quote "$DEVICE_TYPE")
kernel_type: $(yaml_quote "$KERNEL_TYPE")
bootloader: $(yaml_quote "$BOOTLOADER")
login_style: $(yaml_quote "$LOGIN_STYLE")
accept_keywords: $(yaml_quote "$ACCEPT_KEYWORDS")
accept_license: $(yaml_quote "$ACCEPT_LICENSE")
username: $(yaml_quote "$USERNAME")
user_password_hash: $(yaml_quote "$PASS_HASH")
root_password_hash: $(yaml_quote "$PASS_HASH")
setup_doas_instead_of_sudo: $DOAS_INSTEAD_OF_SUDO
default_terminal: $(yaml_quote "$DEFAULT_TERMINAL")
default_browser: $(yaml_quote "$DEFAULT_BROWSER")
install_omarchy_dotfiles: $INSTALL_DOTFILES
dotfiles_repo_url: $(yaml_quote "$DOTFILES_URL")
gentoo_mirror: $(yaml_quote "$GENTOO_MIRROR")
EOF
chmod 600 "$YAML_FILE"

echo "✅ Konfigurasi disimpan. Menjalankan Ansible..."
ansible-playbook -i 'localhost,' -c local site.yml -e "@$YAML_FILE"

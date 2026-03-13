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
ask_radio() { whiptail --title "$1" --radiolist "$2\n\nGunakan SPASI untuk memilih, ENTER untuk konfirmasi." 18 76 8 "${@:3}" 3>&1 1>&2 2>&3; }
ask_yesno() { whiptail --title "$1" --yesno "$2" 10 60; }
ask_scroll_menu() {
    local title="$1"
    local prompt="$2"
    local height="${3:-20}"
    local items="${4:-10}"
    shift 4
    whiptail --title "$title" --menu "$prompt" "$height" 74 "$items" "$@" 3>&1 1>&2 2>&3
}
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
TZ_REGION=$(ask_scroll_menu "Timezone (1/2)" "Pilih region:" 20 12 \
    "Asia" "Jakarta, Tokyo, Shanghai, ..." \
    "Europe" "London, Berlin, Paris, ..." \
    "America" "New_York, Chicago, Los_Angeles, ..." \
    "Africa" "Cairo, Nairobi, Johannesburg, ..." \
    "Australia" "Sydney, Melbourne, Perth, ..." \
    "Pacific" "Auckland, Fiji, Honolulu, ..." \
    "Indian" "Maldives, Mauritius, ..." \
    "Atlantic" "Reykjavik, Azores, ..." \
    "Etc" "UTC, GMT, ..." \
    "Lainnya" "Ketik manual")
if [ "$TZ_REGION" == "Lainnya" ]; then
    TIMEZONE=$(ask_input_validated "Timezone" "Masukkan timezone lengkap:" "Asia/Jakarta" '^[A-Za-z0-9_+./-]+$' "Format timezone tidak valid.")
else
    TZ_CITIES=()
    if [ -d "/usr/share/zoneinfo/${TZ_REGION}" ]; then
        while IFS= read -r city; do
            short_name="$(basename "$city")"
            TZ_CITIES+=("${TZ_REGION}/${short_name}" "$short_name")
        done < <(find "/usr/share/zoneinfo/${TZ_REGION}" -maxdepth 1 -type f | sort)
    fi

    if [ "${#TZ_CITIES[@]}" -gt 0 ]; then
        TIMEZONE=$(ask_scroll_menu "Timezone (2/2)" "Pilih zona waktu di ${TZ_REGION}:" 20 12 "${TZ_CITIES[@]}")
    else
        TIMEZONE=$(ask_input_validated "Timezone" "Masukkan timezone lengkap:" "${TZ_REGION}/UTC" '^[A-Za-z0-9_+./-]+$' "Format timezone tidak valid.")
    fi
fi

SYSTEM_LOCALE=$(ask_scroll_menu "Locale" "Pilih locale default sistem:" 20 10 \
    "en_US.UTF-8" "English (United States)" \
    "id_ID.UTF-8" "Bahasa Indonesia" \
    "ja_JP.UTF-8" "Japanese" \
    "zh_CN.UTF-8" "Chinese (Simplified)" \
    "ko_KR.UTF-8" "Korean" \
    "de_DE.UTF-8" "German" \
    "fr_FR.UTF-8" "French" \
    "es_ES.UTF-8" "Spanish" \
    "pt_BR.UTF-8" "Portuguese (Brazil)" \
    "ru_RU.UTF-8" "Russian" \
    "Lainnya" "Ketik manual")
if [ "$SYSTEM_LOCALE" == "Lainnya" ]; then
    SYSTEM_LOCALE=$(ask_input_validated "Locale" "Masukkan locale (contoh: en_GB.UTF-8):" "en_US.UTF-8" '^[a-z]{2}_[A-Z]{2}\.[A-Za-z0-9_-]+$' "Format locale tidak valid.")
fi

HWCLOCK=$(ask_radio "Hardware Clock" "Pilih mode hardware clock:" \
    "UTC" "UTC (Disarankan, aman untuk dual-boot)" ON \
    "local" "Local Time (hanya jika single-boot)" OFF)

CORES=$(nproc)
MAKEOPTS=$(ask_input "Kompilasi (MAKEOPTS)" "Jumlah thread CPU terdeteksi: $CORES" "-j$CORES -l$CORES")
MARCH=$(ask_input "Kompilasi (CFLAGS)" "Arsitektur target (-march):" "native")
CPU_VENDOR_DETECTED=$(awk -F: '/vendor_id/{gsub(/^[ \t]+/, "", $2); print tolower($2); exit}' /proc/cpuinfo)
if [[ "$CPU_VENDOR_DETECTED" == *"intel"* ]]; then
    CPU_VENDOR_DETECTED="intel"
elif [[ "$CPU_VENDOR_DETECTED" == *"amd"* ]]; then
    CPU_VENDOR_DETECTED="amd"
else
    CPU_VENDOR_DETECTED="generic"
fi
CPU_VENDOR_INTEL="OFF"
CPU_VENDOR_AMD="OFF"
CPU_VENDOR_GENERIC="OFF"
if [ "$CPU_VENDOR_DETECTED" == "intel" ]; then
    CPU_VENDOR_INTEL="ON"
elif [ "$CPU_VENDOR_DETECTED" == "amd" ]; then
    CPU_VENDOR_AMD="ON"
else
    CPU_VENDOR_GENERIC="ON"
fi
CPU_VENDOR=$(ask_radio "CPU Vendor" "Pilih CPU vendor (terdeteksi: $CPU_VENDOR_DETECTED):" \
    "intel" "Intel" "$CPU_VENDOR_INTEL" \
    "amd" "AMD" "$CPU_VENDOR_AMD" \
    "generic" "Generic" "$CPU_VENDOR_GENERIC")

DISKS=$(lsblk -d -n -p -o NAME,SIZE,MODEL,TYPE | awk '$4=="disk" {desc=$2; for(i=3; i<NF; i++) desc=desc "_" $i; print $1 " " desc}')
DISK_MENU=(); while read -r dev desc; do DISK_MENU+=("$dev" "$(echo "$desc" | tr '_' ' ')"); done <<< "$DISKS"
TARGET_DISK=$(ask_menu "Partisi Disk" "Pilih drive instalasi (AKAN DIHAPUS):" "${DISK_MENU[@]}")
if [ -z "$TARGET_DISK" ]; then exit 1; fi

PART_LAYOUT=$(ask_radio "Skema Partisi" "Pilih struktur direktori:" \
    "flat" "Hanya /boot/efi dan / (Menyatu)" ON \
    "separate_home" "/boot/efi, /, dan /home terpisah" OFF)
if [ "$PART_LAYOUT" == "separate_home" ]; then
    ROOT_SIZE=$(ask_input_validated "Ukuran Root" "Ukuran / (Root) dalam GB:" "50" '^[1-9][0-9]*$' "Ukuran root harus angka bulat positif (GB).")
else
    ROOT_SIZE="0"
fi
SWAP_SIZE=$(ask_input_validated "Ukuran Swap" "Ukuran partisi swap dalam GB:" "8" '^[1-9][0-9]*$' "Ukuran swap harus angka bulat positif (GB).")
if [ "$SWAP_SIZE" -gt 128 ]; then
    whiptail --title "Peringatan Swap Besar" --yesno "Swap ${SWAP_SIZE}GB terdeteksi.\nIni cukup besar dan bisa jadi typo.\n\nTetap lanjut?" 12 70 || exit 1
fi

FILESYSTEM=$(ask_radio "Filesystem" "Pilih format Root (radio button):" \
    "btrfs" "Modern, snapshot, zstd" ON \
    "ext4" "Klasik, stabil" OFF \
    "xfs" "Performa tinggi" OFF)
INIT_SYS=$(ask_radio "Init System" "Pilih Init System (radio button):" \
    "systemd" "Modern (Disarankan untuk Wayland)" ON \
    "openrc" "Klasik" OFF)
GPU_VENDOR=$(ask_radio "GPU (Wayland Base)" "Pilih GPU utama (radio button):" \
    "nvidia" "NVIDIA Proprietary" ON \
    "amd" "AMD Radeon" OFF \
    "intel" "Intel Graphics" OFF)
DEVICE_TYPE=$(ask_radio "Tipe Perangkat" "Jenis mesin ini (radio button):" \
    "laptop" "Laptop / Portable (WiFi, Baterai, Bluetooth)" ON \
    "desktop" "Desktop PC / Workstation" OFF)
KEYWORD_PROFILE=$(ask_radio "Portage Keywords" "Pilih profile paket (radio button):" \
    "stable" "ACCEPT_KEYWORDS=amd64 (stabil)" ON \
    "testing" "ACCEPT_KEYWORDS=~amd64 (lebih baru, lebih berisiko)" OFF)
if [ "$KEYWORD_PROFILE" == "testing" ]; then
    ACCEPT_KEYWORDS="~amd64"
else
    ACCEPT_KEYWORDS="amd64"
fi
LICENSE_MODE=$(ask_radio "Mode Lisensi" "Pilih mode lisensi package (radio button):" \
    "standard" "ACCEPT_LICENSE=* (praktis, termasuk non-free)" ON \
    "strict_foss" "ACCEPT_LICENSE=@FREE (hanya lisensi bebas)" OFF)
if [ "$LICENSE_MODE" == "strict_foss" ]; then
    ACCEPT_LICENSE="@FREE"
else
    ACCEPT_LICENSE="*"
fi
if [ "$ACCEPT_KEYWORDS" == "~amd64" ] && [ "$ACCEPT_LICENSE" == "@FREE" ]; then
    whiptail --title "Peringatan Kombinasi" --yesno "Anda memilih Testing (~amd64) + Strict FOSS.\n\nKombinasi ini dapat menyebabkan konflik dependensi,\nterutama untuk driver GPU proprietary dan firmware.\n\nTetap lanjut?" 14 70 || exit 1
fi
KERNEL_TYPE=$(ask_radio "Tipe Kernel" "Pilih instalasi kernel (radio button):" \
    "bin" "gentoo-kernel-bin (Cepat)" ON \
    "source" "Kompilasi manual" OFF)

if [ "$INIT_SYS" == "systemd" ]; then
    BOOTLOADER=$(ask_radio "Bootloader" "Pilih Bootloader (radio button):" \
        "systemd-boot" "Cepat & Minimalis" ON \
        "limine" "Elegan (Multi-OS)" OFF \
        "grub" "Klasik" OFF \
        "efistub" "Ekstrem (Tanpa Bootloader)" OFF)
else
    BOOTLOADER=$(ask_radio "Bootloader" "Pilih Bootloader (radio button):" \
        "limine" "Elegan (Multi-OS)" ON \
        "grub" "Klasik" OFF \
        "efistub" "Ekstrem (Tanpa Bootloader)" OFF)
fi

LOGIN_STYLE=$(ask_radio "Gaya Login" "Pilih sesi masuk:" \
    "dm" "Greetd (TUI elegan, otomatis ke Hyprland)" ON \
    "tty" "TTY murni (manual start Hyprland)" OFF)
DEFAULT_TERMINAL=$(ask_menu "Default Terminal" "Pilih terminal default (gaya dropdown):" \
    "ghostty" "Ghostty (modern)" \
    "kitty" "Kitty" \
    "alacritty" "Alacritty")
DEFAULT_BROWSER=$(ask_menu "Default Browser" "Pilih browser default (gaya dropdown):" \
    "brave" "Brave" \
    "firefox" "Firefox")

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
GENTOO_MIRROR=$(ask_scroll_menu "Gentoo Mirror" "Pilih mirror Gentoo terdekat:" 18 8 \
    "https://distfiles.gentoo.org" "Default Global" \
    "https://kambing.ui.ac.id/gentoo" "Indonesia (UI Depok)" \
    "https://ftp.jaist.ac.jp/pub/Linux/Gentoo" "Jepang (JAIST)" \
    "https://ftp.riken.jp/Linux/gentoo" "Jepang (RIKEN)" \
    "https://mirrors.tuna.tsinghua.edu.cn/gentoo" "China (Tsinghua)" \
    "https://ftp.kaist.ac.kr/gentoo" "Korea (KAIST)" \
    "https://mirror.leaseweb.com/gentoo" "Eropa (LeaseWeb)" \
    "Lainnya" "Ketik URL manual")
if [ "$GENTOO_MIRROR" == "Lainnya" ]; then
    GENTOO_MIRROR=$(ask_input_validated "Gentoo Mirror" "Masukkan base URL mirror Gentoo:" "https://distfiles.gentoo.org" '^https?://[A-Za-z0-9._~:/?#\[\]@!$&()*+,;=%-]+$' "URL mirror tidak valid.")
fi
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

# 🎌 Omgently
**The Ultimate Opinionated Gentoo Bootstrapper for Hyprland**

![Gentoo](https://img.shields.io/badge/OS-Gentoo-purple.svg?style=for-the-badge&logo=gentoo)
![Hyprland](https://img.shields.io/badge/WM-Hyprland-00a8f3.svg?style=for-the-badge)
![Ansible](https://img.shields.io/badge/Built_with-Ansible-ee0000.svg?style=for-the-badge&logo=ansible)

**Omgently** adalah sebuah *provisioning tool* tingkat lanjut berbasis Ansible dan skrip TUI (*Text User Interface*) interaktif. Alat ini dirancang untuk mengotomatisasi instalasi Gentoo Linux dari nol hingga menjadi *desktop* Wayland (Hyprland) bergaya "High-Performance Elegance" tanpa mengorbankan filosofi kebebasan absolut Gentoo.

Proyek ini mengatasi hampir semua keluhan klasik instalasi Gentoo: kompilasi lama, *dependency hell* di X11, konfigurasi NVIDIA Wayland yang rumit, dan *setup* audio yang membingungkan.

---
## 🛠️ Struktur Direktori/Repository

```text
Omgently/
├── bootstrapper.sh          # [FASE 0] Skrip TUI pembuka (Network, Time, Input User)
├── ansible.cfg              # Konfigurasi Ansible (pipelining, retries)
├── site.yml                 # Playbook utama (Entrypoint)
├── roles/
│   ├── 01-base-prep/        # [FASE 1] Partisi & Format
│   ├── 02-core-system/      # [FASE 2] make.conf, Git Sync, Overlay GURU
│   ├── 03-kernel-boot/      # [FASE 3] fstab, Firmware, Kernel, Bootloader
│   ├── 04-system-config/    # [FASE 4] Timezone, NetworkManager, User/Doas
│   ├── 05-wayland-gpu/      # [FASE 5] D-Bus, Nvidia DRM, Greetd/TTY
│   ├── 06-hyprland-de/      # [FASE 6] Pipewire, Polkit, Komponen GUI
│   └── 07-dotfiles-tools/   # [FASE 7] Nvim, Terminal, Browser, GNU Stow
└── dotfiles/                # Repositori terpisah untuk konfigurasi Omgently
   ├── hyprland/hyprland.conf
   ├── waybar/config & style.css
   ├── wofi/config & style.css
   └── nvim/init.lua
```


## ✨ Fitur Utama (The Omarchy Way)

* **🚀 Agnostik & Interaktif:** Jalankan dari LiveCD Linux apa pun (sangat disarankan menggunakan Arch Linux ISO untuk dukungan `iwctl` terbaru). Skrip TUI otomatis memverifikasi jaringan dan menyinkronkan waktu via NTP sebelum Ansible mengambil alih.
* **🧠 Optimasi Kompilasi Maksimal:** Otomatis meracik `make.conf` dengan `CFLAGS="-march=native"` dan injeksi `EMERGE_DEFAULT_OPTS` yang disetel seimbang antara kecepatan kompilasi dan stabilitas penggunaan memori.
* **💽 Storage & Partisi Adaptif:** Mendeteksi disk NVMe, SATA, atau eMMC secara akurat. Bebas memilih **BTRFS** (dilengkapi sistem *subvolume* cerdas `@portage` dan `@snapshots`), atau sistem klasik tinggi performa (**EXT4/XFS**).
* **🛡️ Bulletproof Wayland & NVIDIA:** Skrip ini 100% mematuhi panduan modern Gentoo untuk Nvidia. Otomatis menyuntikkan parameter kernel DRM (`nvidia-drm.modeset=1`), memuat modul di `modules-load.d`, dan menyetel *environment variables* krusial agar resolusi tinggi (1440p hingga 4K 120Hz) berjalan tanpa *tearing* atau *black screen*.
* **🖥️ Dynamic Display Resolution:** Konfigurasi Hyprland kini modular dengan `monitors.conf`. Default tetap auto-detect (`highrr, auto, 1`), dan user bisa menambah mapping multi-monitor desktop/laptop tanpa mengubah file inti.
* **⚡ Modern Booting Options:** Tinggalkan GRUB jika Anda mau. Pilih antara **Limine** (elegan & cerdas untuk *multi-boot*), **systemd-boot** (super cepat), GRUB klasik, atau konfigurasi ekstrem **EFISTUB** (tanpa bootloader).
* **🕰️ Multi-OS Ready:** Mengunci Hardware Clock (`hwclock`) ke UTC jika Anda memilih skenario *dual-boot* (sangat berguna untuk mesin yang bersanding dengan macOS atau Windows).
* **🎨 The Omarchy Ecosystem:** Menghadirkan ekosistem produktivitas penuh tanpa *bloatware*: Pipewire, Waybar, Wofi, Mako, Hyprlock, Hypridle, SwayOSD, Swappy, Ghostty/Alacritty, Neovim modern, serta integrasi *dotfiles* via GNU Stow.
* **💻 Desktop + Laptop Aware:** Bootstrapper memiliki opsi `device_type` (`desktop`/`laptop`) untuk mengaktifkan stack laptop (TLP, BlueZ, Blueman, wireless-regdb, lid-switch policy) secara otomatis.
* **🧩 OpenRC + systemd Friendly:** Flow provisioning menyesuaikan init system termasuk `elogind` untuk OpenRC agar fitur `loginctl`/lock/suspend tetap berfungsi.

---

## 🛠️ Persyaratan Sistem

1. Koneksi Internet aktif (Kabel atau Wi-Fi).
2. LiveCD Linux berbasis *ncurses*.
3. Setidaknya 30GB ruang penyimpanan kosong.

---

## 📂 Arsitektur Direktori Ansible

Proyek ini dibangun secara modular agar sangat mudah dibaca dan dimodifikasi:

* `01-base-prep`: Disk wiping, Partisi dinamis (sgdisk), Formatting dinamis, BTRFS Subvolumes.
* `02-core-system`: Chroot prep, Git Sync Portage, GURU overlay bootstrap, Dynamic `make.conf`.
* `03-kernel-boot`: Generate `fstab` UUID, Firmware/Microcode, Automasi Kernel (Bin/Source via `installkernel`), Bootloader setup.
* `04-system-config`: Timezone, HWClock (OpenRC/systemd-aware), Locale, NetworkManager, User creation, Doas/Sudo, dan lid-close behavior laptop (`HandleLidSwitch=suspend`) untuk systemd maupun elogind.
* `05-wayland-gpu`: D-Bus, Elogind+Seatd (OpenRC), XWayland, Nvidia configs, Greetd/TTY dengan perbaikan sesi `XDG_RUNTIME_DIR`.
* `06-hyprland-de`: Pipewire, policykit, XDG portal Hyprland, Waybar/Wofi/Mako/Hyprpaper, Hyprlock/Hypridle, SwayOSD, Swappy, serta stack laptop (TLP, BlueZ, Blueman, wireless-regdb).
* `07-dotfiles-tools`: Neovim, eza/ripgrep/fd/fzf/bat, browser/terminal pilihan, integrasi GNU Stow, validasi `monitors.conf`, binding terminal dinamis, dan normalisasi post-stow.

---

## 🚀 Panduan Instalasi (Quick Start)

1. **Boot** ke LiveCD pilihan Anda.
2. Unduh dan jalankan TUI Bootstrapper:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/firesand/Omgently/main/bootstrapper.sh)
   ```
3. Ikuti wizard TUI (termasuk pilihan `locale`, ukuran `swap`, `dotfiles_repo_url`, `gentoo_mirror`, profile `keywords`, dan mode lisensi) sampai file variabel sementara terbentuk.
4. Bootstrapper akan mengeksekusi:
   ```bash
   ansible-playbook -i 'localhost,' -c local site.yml -e "@<temp-vars-file>"
   ```

Contoh nilai `gentoo_mirror`:

- `https://distfiles.gentoo.org` (default global)
- `https://kambing.ui.ac.id/gentoo` (mirror lokal Indonesia)

---

## 🧾 Menjalankan tanpa TUI

Anda juga bisa menjalankan playbook manual dengan file vars sendiri:

```yaml
# example.vars.yml
system_hostname: "omgently-host"
timezone: "Asia/Jakarta"
system_locale: "en_US.UTF-8"
hwclock: "UTC"
makeopts: "-j8 -l8"
cpu_threads: "8"
march_target: "native"
cpu_vendor: "intel"
target_disk: "/dev/nvme0n1"
partition_layout: "flat"
root_size_gb: "0"
swap_size_gb: "8"
filesystem: "btrfs"
init_system: "systemd"
gpu_vendor: "intel"
device_type: "desktop"
kernel_type: "bin"
bootloader: "systemd-boot"
accept_keywords: "amd64"
accept_license: "*"
login_style: "dm"
username: "koki"
user_password_hash: "$6$examplehash..."
root_password_hash: "$6$examplehash..."
setup_doas_instead_of_sudo: true
default_terminal: "ghostty"
default_browser: "brave"
install_omarchy_dotfiles: true
dotfiles_repo_url: "https://github.com/firesand/Omgently.git"
gentoo_mirror: "https://distfiles.gentoo.org"
```

Lalu jalankan:

```bash
ansible-playbook -i 'localhost,' -c local site.yml -e "@example.vars.yml"
```

### Template Siap Pakai (di dalam repo)

Gunakan template berikut lalu sesuaikan nilai sensitif (`target_disk`, `username`, `user_password_hash`, `root_password_hash`):

- `examples/vars/desktop-openrc-btrfs-nvidia-limine.vars.yml`
- `examples/vars/laptop-systemd-btrfs-amd-limine.vars.yml`

Contoh eksekusi:

```bash
ansible-playbook -i 'localhost,' -c local site.yml -e "@examples/vars/desktop-openrc-btrfs-nvidia-limine.vars.yml"
```

```bash
ansible-playbook -i 'localhost,' -c local site.yml -e "@examples/vars/laptop-systemd-btrfs-amd-limine.vars.yml"
```

Contoh generate hash password:

```bash
openssl passwd -6
```

---

## 🧪 Menjalankan dari clone lokal

Jika Anda sudah meng-clone repo ini di LiveCD:

```bash
cd Omgently
chmod +x bootstrapper.sh
./bootstrapper.sh
```

---

## ⚙️ Known Limitations / Tested Matrix

- Dirancang untuk firmware **UEFI** (bukan BIOS legacy).
- Arsitektur target saat ini: **amd64/x86_64**.
- GPU yang didukung di flow saat ini: **Intel / AMD / NVIDIA**.
- Fokus pada workflow **Wayland + Hyprland** (bukan desktop environment penuh X11).
- Asumsi koneksi internet aktif selama bootstrap dan sync Portage.
- Runtime boot test aktual masih wajib dilakukan setelah provisioning (greetd login flow, portal behavior, nm-applet tray di sesi nyata).
- Integrasi dotfiles custom tetap mengasumsikan struktur repo kompatibel dengan paket `stow`; playbook sudah fail-fast bila folder wajib tidak ditemukan.

### Tested Matrix (Current State)

| Area | Status |
|------|--------|
| Static lint/idempotency style antar role | ✅ Sudah dirapikan (become, FQCN, --noreplace, rerun-safe stow) |
| Boot/login runtime (DM/TTY) | ⏳ Perlu uji manual di mesin nyata |
| Portal/screencast/file picker runtime | ⏳ Perlu uji manual di sesi Hyprland |
| Tray app runtime (`nm-applet`) | ⏳ Perlu uji manual di sesi Hyprland |

### Runtime Test Checklist

Gunakan checklist ini setelah instalasi selesai dan mesin target reboot.

#### Skenario A: `systemd + nvidia + login_style=dm`

1. Login lewat `greetd` ke sesi Hyprland berhasil tanpa fallback ke TTY.
2. Konfirmasi service enable:
   - `systemctl is-enabled NetworkManager`
   - `systemctl is-enabled greetd`
3. Verifikasi proses user session:
   - `pgrep -a pipewire`
   - `pgrep -a wireplumber`
   - `pgrep -a nm-applet`
   - `pgrep -a lxqt-policykit-agent`
   - `pgrep -a hyprpaper`
   - `pgrep -a hypridle`
   - `pgrep -a swayosd-server`
4. Verifikasi portal tersedia:
   - `which xdg-desktop-portal`
   - Uji file picker dari aplikasi GUI (contoh browser/GTK app).
5. Verifikasi NVIDIA session env di Hyprland:
   - `grep -E 'LIBVA_DRIVER_NAME|GBM_BACKEND|__GLX_VENDOR_LIBRARY_NAME|AQ_NO_HARDWARE_CURSORS' ~/.config/hypr/hyprland.conf`
6. Validasi kursor terlihat normal dan tidak hilang saat berpindah window/workspace.
7. Uji fitur screenshot/record:
   - `omgently-screenshot region`
   - `omgently-screenrecord` (jalankan 2x untuk start/stop)

#### Skenario B: `openrc + amd/intel + login_style=dm` (atau `tty`)

1. Jika `login_style=dm`, login Hyprland via greetd berhasil.
2. Cek runlevel OpenRC:
   - `rc-update show default | grep -E 'dbus|elogind|seatd|NetworkManager|greetd'`
3. Verifikasi proses user session:
   - `pgrep -a pipewire`
   - `pgrep -a wireplumber`
   - `pgrep -a nm-applet`
   - `pgrep -a lxqt-policykit-agent`
   - `pgrep -a hyprpaper`
   - `pgrep -a hypridle`
   - `pgrep -a swayosd-server`
4. Verifikasi tidak ada env NVIDIA yang bocor:
   - `grep -E 'LIBVA_DRIVER_NAME|GBM_BACKEND|__GLX_VENDOR_LIBRARY_NAME|AQ_NO_HARDWARE_CURSORS' ~/.config/hypr/hyprland.conf`
   - Hasil untuk non-NVIDIA harus kosong.
5. Uji portal/file picker/screenshot (grim+slurp) dari sesi Hyprland.
6. Uji audio end-to-end:
   - `pavucontrol` terbuka normal.
   - Browser/app menghasilkan output audio ke Pipewire.
7. Untuk `device_type=laptop`, verifikasi stack laptop:
   - `which tlp bluetoothctl blueman-manager`
   - `test -f /usr/lib/firmware/regulatory.db`

---

## 🔧 Advanced Overrides

Untuk power user, beberapa parameter `Role 02` bisa dioverride lewat file vars manual:

- `portage_sync_uri` (default: `https://github.com/gentoo-mirror/gentoo.git`)
- `emerge_jobs` dan `emerge_load_average` (override `EMERGE_DEFAULT_OPTS`)
- `accept_license` (contoh strict mode: `@FREE`)
- `accept_keywords` (contoh testing: `~amd64`)

Contoh:

```yaml
portage_sync_uri: "rsync://rsync.gentoo.org/gentoo-portage"
emerge_jobs: 2
emerge_load_average: 8
accept_license: "@FREE"
accept_keywords: "amd64"
```

---

## ⚠️ Catatan penting

- Proses ini **destruktif**: disk target akan di-wipe total.
- Pastikan variabel `target_disk` benar sebelum lanjut.
- Re-run playbook kini lebih aman (idempotent) untuk service enable, dotfiles clone, dan beberapa langkah bootstrap.
- Proyek ini masih opinionated untuk workflow Hyprland + Wayland.

---

## 📜 Lisensi

Proyek ini menggunakan lisensi **GNU General Public License v3.0 (GPL-3.0)**. Detail lengkap tersedia pada file `LICENSE` di root repository.

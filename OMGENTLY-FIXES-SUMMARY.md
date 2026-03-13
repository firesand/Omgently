# Omgently Live Testing — Summary of All Fixes & Changes
**Date:** 13 Maret 2026  
**Environment:** CachyOS LiveCD → NVMe (AMD Ryzen 32-thread, AMD GPU)  
**Config:** BTRFS flat, systemd, Limine, Greetd, Ghostty/Firefox

---

## A. Bootstrapper (bootstrapper.sh)

### A1. NTP Hang [KRITIS]
**Problem:** `chronyd -q` dan `ntpd -qg` menunggu selamanya pada sistem yang sudah punya daemon NTP berjalan.  
**Fix:** Tambahkan `timeout 10` di depan kedua command.  
**File:** `bootstrapper.sh` baris 40-43

### A2. URL Regex Crash [KRITIS]
**Problem:** Regex `'^https?://[A-Za-z0-9._~:/?#\[\]@!$&()*+,;=%-]+$'` mengandung `$&()*` yang diinterpretasi bash sebagai variable expansion dan globbing.  
**Fix:** Sederhanakan menjadi `'^https?://.+$'` untuk Dotfiles URL dan Gentoo Mirror fallback.  
**File:** `bootstrapper.sh` baris 273, 284

### A3. Disk Tidak Terdeteksi [KRITIS]
**Problem:** `lsblk` dengan MODEL yang mengandung spasi (contoh: "Samsung SSD 970 EVO Plus") menyebabkan `awk '$4=="disk"'` gagal karena field bergeser.  
**Fix:** Gunakan `lsblk -P` (KEY="VALUE" format) dengan `awk -F'"'` untuk parsing yang aman.  
**File:** `bootstrapper.sh` baris 174

### A4. TUI Widgets Upgrade [ENHANCEMENT]
**Problem:** Semua pilihan binary menggunakan `--menu` yang kurang intuitif.  
**Fix:** Ganti 11 field ke `--radiolist` (filesystem, init system, GPU, device type, keywords, lisensi, kernel, bootloader, login style, hwclock, partition layout). Tambahkan 2-step timezone picker (region→city dari `/usr/share/zoneinfo`), scrollable locale menu (10 locale umum + "Lainnya"), dan scrollable mirror menu (7 mirror Asia-Pacific + "Lainnya").  
**File:** `bootstrapper.sh` — seluruh section PENGUMPULAN DATA

### A5. Auto-detect CPU Vendor [ENHANCEMENT]
**Problem:** CPU vendor radiolist tidak menunjukkan default berdasarkan hardware.  
**Fix:** Auto-detect via `/proc/cpuinfo` dan set `ON` pada vendor yang terdeteksi.  
**File:** `bootstrapper.sh` baris 147-168

---

## B. Ansible Config (ansible.cfg)

### B1. Callback Plugin Removed [KRITIS]
**Problem:** `stdout_callback = yaml` (community.general.yaml) sudah dihapus di Ansible 12.0.0+.  
**Fix:** Hapus baris tersebut, gunakan callback default bawaan.  
**File:** `ansible.cfg`

---

## C. Role 01 — Base Prep

### C1. Pre-cleanup Mount Lama [PENTING]
**Problem:** Re-run setelah gagal meninggalkan chroot bind mounts (proc, sys, dev) yang membuat `/mnt/gentoo` busy → umount gagal → Role 01 gagal.  
**Fix:** Tambahkan pre-cleanup task di awal role menggunakan `findmnt -R` + `sort -r` + `umount -l` untuk recursive lazy unmount.  
**File:** `roles/01-base-prep/tasks/main.yml` (task pertama)

### C2. Verbosity Indentation [SEDANG]
**Problem:** `verbosity: 1` ditulis di level task, bukan di dalam `ansible.builtin.debug`.  
**Fix:** Pindahkan `verbosity: 1` ke dalam blok `debug:` sejajar dengan `msg:`.  
**File:** `roles/01-base-prep/tasks/main.yml` baris 32

### C3. Bash Array di Jinja2 [KRITIS]
**Problem:** `${files[@]}` dan `${#files[@]}` di shell task diinterpretasi sebagai Jinja2 template syntax oleh Ansible.  
**Fix:** Sederhanakan deteksi kernel/initramfs dengan `ls -1t ... 2>/dev/null | head -n1 | xargs -n1 basename` tanpa bash array.  
**File:** `roles/03-kernel-boot/tasks/main.yml` baris 92+

---

## D. Role 02 — Core System

### D1. repos.conf Ordering [KRITIS]
**Problem:** `emerge-webrsync` gagal karena repos.conf sudah di-set ke `sync-type = git` sebelum webrsync dijalankan. Error: `Invalid sync-type attribute for 'gentoo' repo: 'git' (expected 'rsync' or 'webrsync')`.  
**Fix:** Tulis `sync-type = webrsync` dulu → `emerge-webrsync` → `emerge git` → switch ke `sync-type = git` → git sync. Rerun path terpisah yang langsung git sync.  
**File:** `roles/02-core-system/tasks/main.yml` section 3

### D2. GURU Overlay Enable/Sync [SEDANG]
**Problem:** `eselect repository enable guru` di-skip jika `guru` sudah ada di list (dari run sebelumnya), tapi `emaint sync -r guru` gagal karena repo belum ter-clone. Error: `The specified repo(s) were not found: guru`.  
**Fix:** Hapus skip condition pada `eselect repository enable` (idempotent by nature), tambahkan `retries: 2` pada sync task.  
**File:** `roles/02-core-system/tasks/main.yml` section 4

### D3. Hyproverlay Overlay [KRITIS]
**Problem:** Hyprland sudah dikeluarkan dari repositori utama Gentoo (Feb 2026) dan dipindahkan ke overlay `hyproverlay` di Codeberg.  
**Fix:** Tambahkan `eselect repository enable hyproverlay` + `emaint sync -r hyproverlay` di Role 02. Tambahkan `*/*::hyproverlay ~amd64` ke package.accept_keywords.  
**File:** `roles/02-core-system/tasks/main.yml` section 4b (baru)

### D4. Package Accept Keywords [KRITIS]
**Problem:** Banyak package masked (`~amd64`) tanpa keyword unmask.  
**Fix:** Buat file terpusat `package.accept_keywords/omgently` di akhir Role 02 dengan semua package yang dibutuhkan.  
**File:** `roles/02-core-system/tasks/main.yml` section 5 (baru)

**Konten file:**
```
# Core system
sys-boot/limine ~amd64
gui-apps/wf-recorder ~amd64

# Desktop
app-misc/nwg-look ~amd64
gui-apps/swayosd ~amd64
media-fonts/nerd-fonts ~amd64
www-client/brave-bin ~amd64

# GURU overlay
app-misc/cliphist ~amd64
app-misc/brightnessctl ~amd64

# Hyproverlay
*/*::hyproverlay ~amd64
>=dev-cpp/sdbus-c++-2.1.0 ~amd64
```

### D5. Package Unmask Hyprland [KRITIS]
**Problem:** Hyprland packages juga di-mask via `package.mask` di main repo (bukan hanya keyword).  
**Fix:** Tambahkan `package.unmask/hyprland` untuk gui-wm/hyprland dan semua Hypr* libraries.  
**File:** `roles/02-core-system/tasks/main.yml` section 5b (baru)

---

## E. Role 03 — Kernel & Boot

### E1. AMD Microcode Package Tidak Ada [KRITIS]
**Problem:** `sys-firmware/amd-ucode` tidak ada di Gentoo — ini nama Arch. AMD microcode sudah termasuk dalam `sys-kernel/linux-firmware`.  
**Fix:** Hapus seluruh task "Instal microcode AMD".  
**File:** `roles/03-kernel-boot/tasks/main.yml` baris 58

---

## F. Role 04 — System Config

### F1. Locale Invalid Format [KRITIS]
**Problem:** `locale-gen` menolak `en_US.utf8 UTF-8` (lowercase). Gentoo hanya menerima `en_US.UTF-8 UTF-8`.  
**Fix:** Hapus baris varian `utf8` lowercase dari locale.gen content. Gunakan `system_locale` langsung (sudah UTF-8) untuk `eselect locale set`.  
**File:** `roles/04-system-config/tasks/main.yml` baris 32-45

---

## G. Role 05 — Wayland & GPU

### G1. USE Flags Hyprland Dependencies [KRITIS]
**Problem:** XWayland dan Hyprland membutuhkan USE flags pada dependensi yang belum di-set.  
**Fix:** Tambahkan `package.use/hyprland-deps`:
```
>=media-libs/libepoxy-1.5.10-r3 X
>=media-libs/libglvnd-1.7.0 X
>=media-libs/mesa-25.3.6 X
>=media-libs/freetype-2.14.1-r1 harfbuzz
```
**File:** `roles/05-wayland-gpu/tasks/main.yml` (sebelum install Hyprland)

### G2. USE Flags AMD XWayland [KRITIS]
**Problem:** `xf86-video-amdgpu` membutuhkan USE flags tambahan pada xorg-server dan libdrm.  
**Fix:** Tambahkan `package.use/xwayland-amd`:
```
>=x11-base/xorg-server-21.1.21 xorg
>=x11-libs/libdrm-2.4.131 video_cards_radeon
```
**File:** `roles/05-wayland-gpu/tasks/main.yml` (sebelum install amdgpu, conditional AMD)

---

## H. Role 06 — Hyprland Desktop

### H1. USE Flags Polkit/LXQt Dependencies [KRITIS]
**Problem:** `lxqt-policykit` membutuhkan USE flags pada kde-frameworks, Qt, xmlto, libxkbcommon, dan systemd.  
**Fix:** Tambahkan `package.use/polkit-deps`:
```
>=kde-frameworks/kwindowsystem-6.23.0 X
>=dev-qt/qtbase-6.10.2 X
>=app-text/xmlto-0.0.28-r11 text
>=x11-libs/libxkbcommon-1.13.1 X
>=sys-apps/systemd-259.3-r1 policykit
```
**File:** `roles/06-hyprland-de/tasks/main.yml` (sebelum install polkit)

### H2. USE Flags wf-recorder [SEDANG]
**Problem:** `wf-recorder` membutuhkan ffmpeg dengan USE flag `x264`.  
**Fix:** Tambahkan `package.use/wf-recorder`:
```
>=media-video/ffmpeg-8.0.1 x264
```
**File:** `roles/06-hyprland-de/tasks/main.yml` (sebelum install wf-recorder)

### H3. USE Flags nm-applet [KRITIS]
**Problem:** `nm-applet` gagal compile karena missing `gdk/gdkx.h` header + dependency USE flags.  
**Fix:** Tambahkan ke `package.use/nm-applet`:
```
gnome-extra/nm-applet appindicator -modemmanager
>=dev-libs/libdbusmenu-16.04.0-r4 gtk3
>=app-crypt/gcr-3.41.2-r2:0 gtk
>=x11-libs/gtk+-3.24.51 X
```
**Note:** GTK3 perlu di-rebuild dengan USE `X` sebelum nm-applet bisa compile.  
**File:** `roles/06-hyprland-de/tasks/main.yml` (sebelum install nm-applet)

---

## I. Package Name Corrections (Arch → Gentoo)

| Nama Salah (Arch-style) | Nama Benar (Gentoo) | Role |
|--------------------------|---------------------|------|
| `gui-apps/ghostty` | `x11-terms/ghostty` | 07 |
| `gui-apps/greetd` | `gui-libs/greetd` | 05 |
| `x11-misc/cliphist` | `app-misc/cliphist` | 06 |
| `sys-power/brightnessctl` | `app-misc/brightnessctl` | 06 |
| `sys-firmware/amd-ucode` | **Hapus** (sudah di `linux-firmware`) | 03 |

---

## J. Status Progres Live Testing

| Role | Status | Catatan |
|------|--------|---------|
| 01 - Base Prep | ✅ PASS | Partisi, format, BTRFS subvolumes, mount semua OK |
| 02 - Core System | ✅ PASS | Stage3, chroot, webrsync→git, GURU, hyproverlay OK |
| 03 - Kernel Boot | ✅ PASS | fstab, firmware, kernel-bin, Limine OK |
| 04 - System Config | ✅ PASS | Timezone, locale, NM, user, doas OK |
| 05 - Wayland GPU | ✅ PASS | D-Bus, Hyprland v0.54.2, XWayland, AMD GPU OK |
| 06 - Hyprland DE | 🔄 IN PROGRESS | Polkit ✅, XDG Portal ✅, wf-recorder ✅, nm-applet ⏳ (GTK3 rebuild needed) |
| 07 - Dotfiles Tools | ⏳ PENDING | Menunggu Role 06 selesai |

---

## K. Pelajaran untuk Installer Gentoo

1. **USE flags adalah tantangan terbesar** — setiap package bisa membutuhkan USE flags pada dependensinya yang tidak terdokumentasi di ebuild metadata. Solusi: pre-set semua USE flags yang diketahui di awal (Role 02).

2. **Hyprland pindah dari main repo** — per Feb 2026, Hyprland ecosystem dipindahkan ke `hyproverlay` overlay di Codeberg. Ini perubahan besar yang mengharuskan penambahan overlay baru.

3. **Package naming Arch ≠ Gentoo** — beberapa package ada di kategori berbeda (`gui-apps` vs `gui-libs`, `x11-misc` vs `app-misc`). Selalu verifikasi dengan `emerge -s`.

4. **`package.accept_keywords` dan `package.unmask`** perlu dipisah — keyword `~amd64` saja tidak cukup jika package juga di-mask via `profiles/package.mask`.

5. **Idempotency pada mount operations** — re-run setelah gagal membutuhkan pre-cleanup recursive unmount. Ansible `mount` module tidak menangani ini secara otomatis.

---

*Total fixes: 20+ across 7 roles + bootstrapper*  
*Live testing duration: ~4+ jam kompilasi*

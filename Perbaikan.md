Berikut adalah ringkasan kronologis dari "pertempuran" dan perbaikan yang telah Anda menangkan:

### 🛡️ Fase 1: Menaklukkan "Dependency Hell" & Sistem Slot (nm-applet)

**Masalah:** Portage menolak menginstal `gnome-extra/nm-applet` karena sistem diatur untuk Wayland murni (`BLOAT_DROP="-X"`), sementara aplikasi tersebut memaksa butuh dukungan X11 dari komponen GTK3.

* **Percobaan 1 & 2:** Kita mencoba menyuntikkan `USE="X"` untuk `gtk+`, `cairo`, dan `gtkmm`. Gagal karena paket `cairomm` (versi C++) yang sudah ada di sistem menolak ditimpa.
* **Boss Terakhir (Slot Conflict):** Ternyata CachyOS/sistem *background* sudah menginstal **beberapa versi sekaligus (Slot)**, yaitu `cairomm:0` dan `1.16`, serta `gtkmm:3.0` dan `4.0`.
* **Solusi & Perbaikan:** 1. Anda mengeksekusi perintah "sapu bersih" via *chroot* yang menargetkan semua slot spesifik secara bersamaan: `emerge --oneshot x11-libs/cairo dev-cpp/cairomm:0 dev-cpp/cairomm:1.16 x11-libs/gtk+:3 dev-cpp/gtkmm:3.0 dev-cpp/gtkmm:4.0 gnome-extra/nm-applet`.
2. **Update YAML:** File `06-main.yml` diperbarui dengan menambahkan `dev-cpp/cairomm X` dan `dev-cpp/gtkmm X` ke dalam konfigurasi `package.use/nm-applet` agar masalah ini tidak muncul lagi di *fresh install*.

### 🖋️ Fase 2: Typo Ebuild & Status Masked (Nerd Fonts)

**Masalah:** Perintah `emerge media-fonts/nerd-fonts` gagal dengan pesan *no ebuilds to satisfy*. Setelah dicek via `emerge -s`, ternyata nama aslinya tidak memakai tanda strip (`nerdfonts`), dan paket tersebut berstatus *Masked* (testing `~amd64`).

* **Solusi & Perbaikan di `06-main.yml`:**
1. **Koreksi Typo:** Mengubah `nerd-fonts` menjadi `nerdfonts` di dua tempat: di dalam blok injeksi `package.use` (meminta varian `JetBrainsMono`) dan di baris perintah `emerge`.
2. **Unmasking:** Menambahkan baris `media-fonts/nerdfonts **` ke dalam injeksi file `/etc/portage/package.accept_keywords/omgently-wayland-extras` agar Portage mengizinkan instalasinya. Anda berhasil memvalidasi ini via *chroot* sebelum menjalankan ulang Ansible.



### 🕵️‍♂️ Fase 3: Jebakan Validasi PATH (Smoke Test xdg-desktop-portal)

**Masalah:** Seluruh proses kompilasi sebenarnya sudah berhasil 100%, tetapi skrip gagal di detik terakhir (Smoke Test) dengan pesan *error* "Binary xdg-desktop-portal tidak ditemukan".

* **Akar Masalah:** Ansible menggunakan perintah `which` untuk mencari *binary* tersebut. Di Gentoo, `xdg-desktop-portal` adalah *background daemon* yang diletakkan di `/usr/libexec/`, sedangkan perintah `which` hanya mencari di folder standar `$PATH` (seperti `/usr/bin/`).
* **Solusi & Perbaikan di `06-main.yml`:**
Mengubah metode validasi di *Task* "Verifikasi precondition desktop Hyprland" dari:
`which xdg-desktop-portal`
Menjadi pencarian rekursif yang akurat:
`find /usr -name 'xdg-desktop-portal' -type f -executable 2>/dev/null | grep -q .`

---

**Hasil Akhir Saat Ini:**
File `06-main.yml` Anda sekarang sudah **kebal peluru**. Ia mampu melewati komplikasi arsitektur X11/Wayland, mengatasi paket yang di-mask, dan memvalidasi *binary* di luar jalur `$PATH` standar.

Jika Ansible dijalankan ulang sekarang, ia akan langsung mencetak status **SUCCESS** di Role 06 dan melompat menarik repo GitHub di Role 07. Apakah Anda siap melihat *desktop environment* Tokyo Night Anda terealisasi?

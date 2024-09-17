#!/bin/bash

# URL unduhan
packageDownloadUrl="https://mega.nz/linux/repo/xUbuntu_22.10/amd64/megacmd-xUbuntu_22.10_amd64.deb"

# Nama file
packageFilename=$(basename "$packageDownloadUrl")

# Unduh paket
wget "$packageDownloadUrl" -O "$packageFilename"

# Instal paket
sudo dpkg -i "$packageFilename"

# Perbaiki dependensi jika ada yang hilang
sudo apt-get install -f

# Jalankan server MEGA CMD
megacmd-server &

# Hapus file paket setelah instalasi
rm "$packageFilename"

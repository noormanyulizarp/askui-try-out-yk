#!/bin/bash

# Fungsi untuk mengkonfigurasi pCloud
configure_pcloud() {
    if [ ! -f ~/.pcloud/config.db ]; then
        echo "Mengkonfigurasi pCloud..."
        pcloud login
    fi
}

# Fungsi untuk mengkonfigurasi MEGA
configure_mega() {
    if ! mega-whoami; then
        echo "Mengkonfigurasi MEGA..."
        read -p "Masukkan email MEGA: " mega_email
        read -s -p "Masukkan password MEGA: " mega_password
        mega-login $mega_email $mega_password
    fi
}

# Fungsi untuk me-mount pCloud
mount_pcloud() {
    if ! mountpoint -q /workspace/pcloud; then
        echo "Mounting pCloud..."
        mkdir -p /workspace/pcloud
        pcloud mount /workspace/pcloud
    fi
}

# Fungsi untuk me-mount MEGA
mount_mega() {
    if ! mountpoint -q /workspace/mega; then
        echo "Mounting MEGA..."
        mkdir -p /workspace/mega
        mega-mount /workspace/mega
    fi
}

# Jalankan konfigurasi dan mounting
configure_pcloud
configure_mega
mount_pcloud
mount_mega

echo "pCloud dan MEGA telah di-mount dan siap digunakan."
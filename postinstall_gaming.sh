#!/bin/bash
set -euo pipefail

# === Автоматическая подготовка Arch Linux для игр ===
# Определяет видеокарту и ставит только нужные драйверы и компоненты

# Проверка root
if [[ $EUID -ne 0 ]]; then
  echo "Этот скрипт нужно запускать от root!"
  exit 1
fi

# 1. Включаем multilib
if ! grep -q '\[multilib\]' /etc/pacman.conf; then
  echo 'Добавление multilib-репозитория...'
  echo -e '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist' >> /etc/pacman.conf
fi
sed -i '/\[multilib\]/,/Include/ s/^#//' /etc/pacman.conf
pacman -Syu --noconfirm

# 2. Определяем видеокарту
GPU_VENDOR="unknown"
GPU_INFO=$(lspci | grep -E 'VGA|3D')
if echo "$GPU_INFO" | grep -qi nvidia; then
  GPU_VENDOR="nvidia"
elif echo "$GPU_INFO" | grep -qi amd; then
  GPU_VENDOR="amd"
elif echo "$GPU_INFO" | grep -qi intel; then
  GPU_VENDOR="intel"
fi

echo "Обнаружена видеокарта: $GPU_VENDOR"

# 3. Устанавливаем драйверы
case "$GPU_VENDOR" in
  nvidia)
    echo "Установка драйверов NVIDIA..."
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils
    ;;
  amd)
    echo "Установка драйверов AMD..."
    pacman -S --noconfirm mesa xf86-video-amdgpu vulkan-radeon lib32-mesa lib32-vulkan-radeon
    ;;
  intel)
    echo "Установка драйверов Intel..."
    pacman -S --noconfirm mesa xf86-video-intel vulkan-intel lib32-mesa lib32-vulkan-intel
    ;;
  *)
    echo "Видеокарта не определена. Установите драйверы вручную!"
    ;;
esac

# 4. Установка Steam, Lutris, Wine, Proton, Gamemode
pacman -S --noconfirm steam lutris gamemode wine-staging winetricks protontricks

# 5. Pipewire (звук)
pacman -S --noconfirm pipewire pipewire-alsa pipewire-pulse wireplumber pavucontrol

# 6. Мониторинг и утилиты
pacman -S --noconfirm htop nvtop gparted

# 7. Контроллеры
pacman -S --noconfirm steam-devices

# 8. OBS Studio (запись/стриминг)
pacman -S --noconfirm obs-studio

# 9. AUR helper (yay)
if ! command -v yay &>/dev/null; then
  echo "Установка yay (AUR helper)..."
  pacman -S --noconfirm --needed git base-devel
  sudo -u $(logname) bash -c 'cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm'
fi

echo "\n=== Геймерский набор установлен! ==="
echo "Рекомендуется перезагрузить систему перед запуском Steam или игр." 
#!/bin/bash
set -euo pipefail

# -- Параметры --
HOSTNAME="arch"
TIMEZONE="Europe/Moscow"
LOCALE="ru_RU.UTF-8"
KEYMAP="us"
MIRRORS=(
  "http://mirror.yandex.ru/archlinux/$repo/os/$arch"
  "https://mirror.yandex.ru/archlinux/$repo/os/$arch"
  "http://ru.mirrors.cicku.me/archlinux/$repo/os/$arch"
  "https://ru.mirrors.cicku.me/archlinux/$repo/os/$arch"
  "http://mirror.truenetwork.ru/archlinux/$repo/os/$arch"
  "https://mirror.truenetwork.ru/archlinux/$repo/os/$arch"
)
KERNELS="linux-zen"
USERNAME="pinya"

# Простые пароли (замените на свои)
ROOT_PASSWORD="root"
USER_PASSWORD="root"

# Диск для установки
DISK="/dev/nvme0n1"
ESP_SIZE=1024

ROOT_PART="${DISK}p2"
ESP_PART="${DISK}p1"


echo "=== Установка Arch Linux на один NVMe диск ==="
echo "Диск: $DISK"
echo ""
echo "ПАРОЛИ:"
echo "  Root: $ROOT_PASSWORD"
echo "  User ($USERNAME): $USER_PASSWORD"
echo ""

### 1. Очистка и подготовка диска

echo "1. Очистка диска..."
wipefs -a "$DISK" || true
sgdisk --zap-all "$DISK" || true

### 2. Создание разделов

echo "2. Создание разделов..."
parted --script "$DISK" mklabel gpt
# ESP раздел (1-1024 MiB)
parted --script "$DISK" mkpart primary fat32 1MiB "${ESP_SIZE}MiB"
parted --script "$DISK" set 1 boot on
parted --script "$DISK" set 1 esp on
# Основной раздел (остальное место)
parted --script "$DISK" mkpart primary "${ESP_SIZE}MiB" 100%

### 3. Форматирование разделов

echo "3. Форматирование ESP..."
mkfs.fat -F32 "$ESP_PART"
echo "4. Форматирование основного раздела..."
mkfs.btrfs -f "$ROOT_PART"

### 5. Монтирование и создание субволюмов

echo "5. Создание Btrfs субволюмов..."
mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
umount /mnt

echo "6. Монтирование субволюмов..."
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@ "$ROOT_PART" /mnt
mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,.snapshots}
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@home "$ROOT_PART" /mnt/home
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@log "$ROOT_PART" /mnt/var/log
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@pkg "$ROOT_PART" /mnt/var/cache/pacman/pkg
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@snapshots "$ROOT_PART" /mnt/.snapshots

# Монтируем ESP
mkdir -p /mnt/boot
mount "$ESP_PART" /mnt/boot

### 7. Настройка зеркал

echo "7. Настройка зеркал..."
cat > /etc/pacman.d/mirrorlist <<EOF
$(for mirror in "${MIRRORS[@]}"; do echo "Server = $mirror"; done)
EOF

### 8. Установка базовой системы

echo "8. Установка базовой системы..."
pacstrap /mnt base base-devel $KERNELS linux-firmware btrfs-progs networkmanager sudo vim

### 9. Генерация fstab

echo "9. Генерация fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

### 10. Chroot и настройка системы

echo "10. Настройка системы..."
arch-chroot /mnt /bin/bash -e <<EOF
# Локаль
sed -i 's/^#\?ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
( echo "LANG=ru_RU.UTF-8" > /etc/locale.conf )
( echo "KEYMAP=us" > /etc/vconsole.conf )
locale-gen

# Временная зона
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Имя хоста
echo "$HOSTNAME" > /etc/hostname

# Настройка mkinitcpio для Btrfs
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Установка systemd-boot
bootctl install --esp-path=/boot

# Создание загрузочной записи для Arch
cat > /boot/loader/entries/arch.conf <<BOOTENTRY
title   Arch Linux
linux   /vmlinuz-$KERNELS
initrd  /initramfs-$KERNELS.img
options root=UUID=$(blkid -s UUID -o value $ROOT_PART) rw rootflags=subvol=@
BOOTENTRY

cat > /boot/loader/loader.conf <<LOADERCONF
default arch
timeout 3
editor  no
LOADERCONF

systemctl enable NetworkManager

echo "root:$ROOT_PASSWORD" | chpasswd
useradd -m -G wheel "$USERNAME"
echo "$USERNAME:$USER_PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
pacman -S --noconfirm --needed git base-devel
EOF

echo "11. Завершение установки..."
umount -R /mnt
swapoff -a

echo ""
echo "=== Установка завершена! ==="
echo "Система установлена на диск: $DISK"
echo "Используется systemd-boot для загрузки"
echo ""
echo "ПАРОЛИ ДЛЯ ВХОДА:"
echo "  Root: $ROOT_PASSWORD"
echo "  User ($USERNAME): $USER_PASSWORD"
echo ""
echo "ВАЖНО: Убедитесь, что в BIOS/UEFI:"
echo "1. Включен UEFI режим"
echo "2. Отключен Secure Boot (если есть проблемы)"
echo "3. В приоритете загрузки выбран UEFI Hard Disk"
echo ""
echo "Перезагрузите систему и извлеките установочный носитель."

exit 0 
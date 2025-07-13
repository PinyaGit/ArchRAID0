#!/bin/bash
set -euo pipefail

# -- Параметры --
HOSTNAME="arch"
TIMEZONE="Europe/Moscow"
LOCALE="ru_RU.UTF-8"
KEYMAP="us"
MIRRORS=(
  "http://mirror.yandex.ru/archlinux/\$repo/os/\$arch"
  "https://mirror.yandex.ru/archlinux/\$repo/os/\$arch"
  "http://ru.mirrors.cicku.me/archlinux/\$repo/os/\$arch"
  "https://ru.mirrors.cicku.me/archlinux/\$repo/os/\$arch"
  "http://mirror.truenetwork.ru/archlinux/\$repo/os/\$arch"
  "https://mirror.truenetwork.ru/archlinux/\$repo/os/\$arch"
)
KERNELS="linux-zen"
USERNAME="pinya"

# Простые пароли (замените на свои)
ROOT_PASSWORD="root"
USER_PASSWORD="root"

# Диски для RAID0
DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
RAID_DEVICE="/dev/md0"

# Размер ESP (в МиБ)
ESP_SIZE=1024

echo "=== Установка Arch Linux с RAID0 (ИСПРАВЛЕННАЯ ВЕРСИЯ) ==="
echo "Диски: ${DISKS[*]}"
echo "RAID устройство: $RAID_DEVICE"
echo ""
echo "ПАРОЛИ:"
echo "  Root: $ROOT_PASSWORD"
echo "  User ($USERNAME): $USER_PASSWORD"
echo ""

### 1. Очистка и подготовка дисков

echo "1. Очистка дисков..."
for disk in "${DISKS[@]}"; do
  echo "  Очистка $disk"
  wipefs -a "$disk" || true
  sgdisk --zap-all "$disk" || true
done

### 2. Создание разделов на каждом диске

echo "2. Создание разделов на дисках..."
for i in "${!DISKS[@]}"; do
  disk="${DISKS[$i]}"
  echo "  Разметка $disk"
  
  # Создаем GPT
  parted --script "$disk" mklabel gpt
  
  # ESP раздел (1-1024 MiB)
  parted --script "$disk" mkpart primary fat32 1MiB "${ESP_SIZE}MiB"
  parted --script "$disk" set 1 boot on
  parted --script "$disk" set 1 esp on
  
  # RAID раздел (остальное место)
  parted --script "$disk" mkpart primary "${ESP_SIZE}MiB" 100%
  parted --script "$disk" set 2 raid on
done

### 3. Форматирование ESP разделов

echo "3. Форматирование ESP разделов..."
for i in "${!DISKS[@]}"; do
  disk="${DISKS[$i]}"
  esp_part="${disk}p1"
  echo "  Форматирование $esp_part"
  mkfs.fat -F32 "$esp_part"
done

### 4. Создание RAID0 массива

echo "4. Создание RAID0 массива..."
raid_parts=()
for disk in "${DISKS[@]}"; do
  raid_parts+=("${disk}p2")
done

mdadm --create --verbose "$RAID_DEVICE" --level=0 --raid-devices="${#DISKS[@]}" "${raid_parts[@]}"

# Создаем mdadm конфигурацию
mkdir -p /etc/mdadm
mdadm --detail --scan > /etc/mdadm/mdadm.conf

### 5. Форматирование RAID раздела

echo "5. Форматирование RAID раздела..."
mkfs.btrfs -f "$RAID_DEVICE"

### 6. Монтирование и создание субволюмов

echo "6. Создание Btrfs субволюмов..."
mount "$RAID_DEVICE" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots

umount /mnt

# Монтируем субволюмы с правильными опциями
echo "7. Монтирование субволюмов..."
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@ "$RAID_DEVICE" /mnt
mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,.snapshots}
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@home "$RAID_DEVICE" /mnt/home
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@log "$RAID_DEVICE" /mnt/var/log
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@pkg "$RAID_DEVICE" /mnt/var/cache/pacman/pkg
mount -o rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=@snapshots "$RAID_DEVICE" /mnt/.snapshots

# Монтируем ESP (используем первый диск)
mkdir -p /mnt/boot
mount "${DISKS[0]}p1" /mnt/boot

### 8. Настройка зеркал

echo "8. Настройка зеркал..."
cat > /etc/pacman.d/mirrorlist <<EOF
$(for mirror in "${MIRRORS[@]}"; do echo "Server = $mirror"; done)
EOF

### 9. Установка базовой системы

echo "9. Установка базовой системы..."
pacstrap /mnt base base-devel $KERNELS linux-firmware btrfs-progs mdadm networkmanager sudo vim

### 10. Генерация fstab

echo "10. Генерация fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

### 11. Chroot и настройка системы

echo "11. Настройка системы..."
arch-chroot /mnt /bin/bash -e <<EOF
# Локаль
# Корректно раскомментировать ru_RU.UTF-8 в /etc/locale.gen
sed -i 's/^#\?ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
# Записать LANG в locale.conf
( echo "LANG=ru_RU.UTF-8" > /etc/locale.conf )
( echo "KEYMAP=us" > /etc/vconsole.conf )
locale-gen

# Временная зона
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Имя хоста
echo "$HOSTNAME" > /etc/hostname

# Настройка mdadm
mkdir -p /etc/mdadm
mdadm --detail --scan > /etc/mdadm/mdadm.conf

# Настройка mkinitcpio для RAID и Btrfs
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block mdadm_udev filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Установка systemd-boot (как в вашей конфигурации)
bootctl install --esp-path=/boot

# Создание загрузочной записи для Arch
cat > /boot/loader/entries/arch.conf <<BOOTENTRY
title   Arch Linux
linux   /vmlinuz-$KERNELS
initrd  /initramfs-$KERNELS.img
options root=UUID=\$(blkid -s UUID -o value $RAID_DEVICE) rw rootflags=subvol=@
BOOTENTRY

# Настройка загрузчика
cat > /boot/loader/loader.conf <<LOADERCONF
default arch
timeout 3
editor  no
LOADERCONF

# Включаем NetworkManager
systemctl enable NetworkManager

# Root password (простой пароль)
echo "root:$ROOT_PASSWORD" | chpasswd

# Создаем пользователя
useradd -m -G wheel "$USERNAME"
echo "$USERNAME:$USER_PASSWORD" | chpasswd

# Настройка sudo для wheel
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Оптимизация сборки пакетов: использовать все ядра
CORES=$(nproc)
sed -i "s/^#\?MAKEFLAGS=.*/MAKEFLAGS=\"-j$CORES\"/" /etc/makepkg.conf

# Установка git и base-devel по умолчанию
pacman -S --noconfirm --needed git base-devel

EOF

### 12. Копирование ESP на второй диск

echo "12. Копирование ESP на второй диск..."
# Копируем содержимое ESP на второй диск
dd if="${DISKS[0]}p1" of="${DISKS[1]}p1" bs=4M status=progress

### 13. Завершение

echo "13. Завершение установки..."
umount -R /mnt
swapoff -a

echo ""
echo "=== Установка завершена! ==="
echo "Система установлена с RAID0 на дисках: ${DISKS[*]}"
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
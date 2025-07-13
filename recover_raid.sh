#!/bin/bash
set -euo pipefail

echo "=== Восстановление RAID0 системы ==="
echo ""

# Параметры
DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
RAID_DEVICE="/dev/md0"

echo "Диски: ${DISKS[*]}"
echo "RAID устройство: $RAID_DEVICE"
echo ""

### 1. Проверка наличия дисков

echo "1. Проверка дисков..."
for disk in "${DISKS[@]}"; do
  if [ ! -b "$disk" ]; then
    echo "ОШИБКА: Диск $disk не найден!"
    exit 1
  fi
  echo "  ✓ $disk найден"
done

### 2. Попытка сборки RAID

echo ""
echo "2. Попытка сборки RAID..."
if mdadm --assemble "$RAID_DEVICE" "${DISKS[0]}p2" "${DISKS[1]}p2"; then
  echo "  ✓ RAID успешно собран"
else
  echo "  ✗ Не удалось собрать RAID автоматически"
  echo "  Попытка принудительной сборки..."
  
  # Проверяем суперблоки
  for disk in "${DISKS[@]}"; do
    echo "  Проверка суперблока на ${disk}p2..."
    mdadm --examine "${disk}p2"
  done
  
  # Принудительная сборка
  if mdadm --assemble --force "$RAID_DEVICE" "${DISKS[0]}p2" "${DISKS[1]}p2"; then
    echo "  ✓ RAID собран принудительно"
  else
    echo "  ✗ Не удалось собрать RAID"
    echo "  Проверьте состояние дисков вручную"
    exit 1
  fi
fi

### 3. Проверка состояния RAID

echo ""
echo "3. Состояние RAID:"
mdadm --detail "$RAID_DEVICE"

### 4. Монтирование системы

echo ""
echo "4. Монтирование системы..."

# Создаем точки монтирования
mkdir -p /mnt/recovery

# Монтируем корневую файловую систему
if mount -o subvol=@ "$RAID_DEVICE" /mnt/recovery; then
  echo "  ✓ Корневая ФС смонтирована"
else
  echo "  ✗ Не удалось смонтировать корневую ФС"
  echo "  Попытка монтирования без субволюма..."
  if mount "$RAID_DEVICE" /mnt/recovery; then
    echo "  ✓ ФС смонтирована без субволюма"
    echo "  Доступные субволюмы:"
    btrfs subvolume list /mnt/recovery
  else
    echo "  ✗ Не удалось смонтировать ФС"
    exit 1
  fi
fi

# Монтируем ESP
if mount "${DISKS[0]}p1" /mnt/recovery/boot; then
  echo "  ✓ ESP смонтирован"
else
  echo "  ✗ Не удалось смонтировать ESP"
  echo "  Попытка монтирования второго ESP..."
  if mount "${DISKS[1]}p1" /mnt/recovery/boot; then
    echo "  ✓ Второй ESP смонтирован"
  else
    echo "  ✗ Не удалось смонтировать ESP"
  fi
fi

### 5. Проверка системы

echo ""
echo "5. Проверка системы..."

if [ -f /mnt/recovery/etc/os-release ]; then
  echo "  ✓ Arch Linux обнаружен"
  cat /mnt/recovery/etc/os-release | grep PRETTY_NAME
else
  echo "  ✗ Arch Linux не найден"
fi

if [ -d /mnt/recovery/boot/loader ]; then
  echo "  ✓ systemd-boot найден"
else
  echo "  ✗ systemd-boot не найден"
fi

### 6. Вход в систему

echo ""
echo "6. Система готова для восстановления"
echo ""
echo "Для входа в систему выполните:"
echo "  arch-chroot /mnt/recovery"
echo ""
echo "Полезные команды для восстановления:"
echo "  # Пересоздать initramfs"
echo "  mkinitcpio -P"
echo ""
echo "  # Обновить загрузчик"
echo "  bootctl install --esp-path=/boot"
echo ""
echo "  # Проверить RAID"
echo "  mdadm --detail /dev/md0"
echo ""
echo "  # Проверить файловые системы"
echo "  btrfs filesystem show"
echo ""

### 7. Интерактивный режим

read -p "Войти в систему сейчас? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Вход в систему..."
  arch-chroot /mnt/recovery /bin/bash
fi

echo ""
echo "=== Восстановление завершено ==="
echo "Система смонтирована в /mnt/recovery"
echo "Для размонтирования выполните: umount -R /mnt/recovery" 
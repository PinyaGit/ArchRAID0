#!/bin/bash

echo "=== Проверка состояния RAID0 ==="
echo ""

# Проверка RAID массива
echo "1. Состояние RAID массива:"
mdadm --detail /dev/md0
echo ""

# Проверка дисков
echo "2. Информация о дисках:"
for disk in /dev/nvme0n1 /dev/nvme1n1; do
  echo "Диск: $disk"
  lsblk "$disk"
  echo ""
done

# Проверка разделов
echo "3. Разделы на дисках:"
for disk in /dev/nvme0n1 /dev/nvme1n1; do
  echo "Разделы $disk:"
  parted "$disk" print
  echo ""
done

# Проверка монтирования
echo "4. Монтированные файловые системы:"
mount | grep -E "(md0|nvme)"
echo ""

# Проверка Btrfs
echo "5. Состояние Btrfs:"
btrfs filesystem show
echo ""

# Проверка субволюмов
echo "6. Субволюмы Btrfs:"
btrfs subvolume list /
echo ""

# Проверка загрузчика
echo "7. Проверка systemd-boot:"
bootctl status
echo ""

# Проверка ESP
echo "8. Содержимое ESP:"
ls -la /boot/
echo ""

echo "=== Проверка завершена ===" 
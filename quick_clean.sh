#!/bin/bash
set -euo pipefail

echo "=== Быстрая очистка RAID0 ==="

# Параметры
DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
RAID_DEVICE="/dev/md0"

echo "Очистка дисков: ${DISKS[*]}"

# Быстрая очистка без подтверждения
echo "Выполняется быстрая очистка..."

# Размонтируем все
umount -R /mnt/recovery 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
umount /boot 2>/dev/null || true

# Останавливаем RAID
mdadm --stop "$RAID_DEVICE" 2>/dev/null || true

# Очищаем суперблоки
for disk in "${DISKS[@]}"; do
    for partition in "${disk}p"*; do
        mdadm --zero-superblock "$partition" 2>/dev/null || true
    done
    mdadm --zero-superblock "$disk" 2>/dev/null || true
done

# Очищаем диски
for disk in "${DISKS[@]}"; do
    wipefs -a "$disk" 2>/dev/null || true
    sgdisk --zap-all "$disk" 2>/dev/null || true
done

# Очищаем конфигурацию
rm -f /etc/mdadm/mdadm.conf 2>/dev/null || true
rm -f /etc/mdadm.conf 2>/dev/null || true

sync

echo "✓ Быстрая очистка завершена"
echo "Диски готовы для установки" 
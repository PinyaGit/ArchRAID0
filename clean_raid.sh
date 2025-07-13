#!/bin/bash
set -euo pipefail

echo "=== Полная очистка RAID0 системы ==="
echo ""

# Параметры
DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
RAID_DEVICE="/dev/md0"

echo "Диски для очистки: ${DISKS[*]}"
echo "RAID устройство: $RAID_DEVICE"
echo ""

# Предупреждение
echo "⚠️  ВНИМАНИЕ: Этот скрипт полностью удалит все данные с дисков!"
echo "   Все разделы, RAID массивы и данные будут безвозвратно удалены."
echo ""

read -p "Вы уверены, что хотите продолжить? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Операция отменена."
    exit 0
fi

echo ""

### 1. Размонтирование всех связанных файловых систем

echo "1. Размонтирование файловых систем..."

# Размонтируем все точки монтирования
umount -R /mnt/recovery 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
umount /boot 2>/dev/null || true
umount /boot/efi 2>/dev/null || true

# Размонтируем все Btrfs субволюмы
for mount_point in /mnt/home /mnt/var/log /mnt/var/cache/pacman/pkg /mnt/.snapshots; do
    umount "$mount_point" 2>/dev/null || true
done

echo "  ✓ Файловые системы размонтированы"

### 2. Остановка RAID массива

echo ""
echo "2. Остановка RAID массива..."

# Проверяем, существует ли RAID массив
if [ -b "$RAID_DEVICE" ]; then
    echo "  Остановка $RAID_DEVICE..."
    
    # Останавливаем RAID массив
    mdadm --stop "$RAID_DEVICE" 2>/dev/null || true
    
    # Удаляем RAID массив из системы
    mdadm --remove "$RAID_DEVICE" 2>/dev/null || true
    
    echo "  ✓ RAID массив остановлен"
else
    echo "  RAID массив не найден, пропускаем"
fi

### 3. Очистка mdadm конфигурации

echo ""
echo "3. Очистка mdadm конфигурации..."

# Удаляем конфигурацию mdadm
rm -f /etc/mdadm/mdadm.conf 2>/dev/null || true
rm -f /etc/mdadm.conf 2>/dev/null || true

echo "  ✓ mdadm конфигурация очищена"

### 4. Очистка суперблоков RAID

echo ""
echo "4. Очистка RAID суперблоков..."

for disk in "${DISKS[@]}"; do
    echo "  Очистка суперблоков на $disk..."
    
    # Очищаем суперблоки на всех разделах диска
    for partition in "${disk}p"*; do
        if [ -b "$partition" ]; then
            echo "    Очистка $partition..."
            mdadm --zero-superblock "$partition" 2>/dev/null || true
        fi
    done
    
    # Очищаем суперблоки на самом диске
    mdadm --zero-superblock "$disk" 2>/dev/null || true
done

echo "  ✓ RAID суперблоки очищены"

### 5. Полная очистка дисков

echo ""
echo "5. Полная очистка дисков..."

for disk in "${DISKS[@]}"; do
    echo "  Очистка $disk..."
    
    # Очищаем все подписи файловых систем
    wipefs -a "$disk" 2>/dev/null || true
    
    # Очищаем GPT таблицы
    sgdisk --zap-all "$disk" 2>/dev/null || true
    
    # Дополнительная очистка начала диска
    dd if=/dev/zero of="$disk" bs=1M count=100 status=progress 2>/dev/null || true
    
    echo "  ✓ $disk очищен"
done

### 6. Очистка кэша и временных файлов

echo ""
echo "6. Очистка кэша..."

# Очищаем кэш mdadm
rm -rf /var/lib/mdadm/* 2>/dev/null || true

# Очищаем временные файлы
rm -rf /tmp/mdadm* 2>/dev/null || true

echo "  ✓ Кэш очищен"

### 7. Проверка результатов

echo ""
echo "7. Проверка результатов..."

# Проверяем, что RAID массив больше не существует
if [ ! -b "$RAID_DEVICE" ]; then
    echo "  ✓ RAID массив удален"
else
    echo "  ✗ RAID массив все еще существует"
fi

# Проверяем состояние дисков
for disk in "${DISKS[@]}"; do
    if [ -b "$disk" ]; then
        echo "  ✓ $disk доступен"
        echo "    Разделы:"
        lsblk "$disk" 2>/dev/null || echo "    Нет разделов"
    else
        echo "  ✗ $disk недоступен"
    fi
done

### 8. Финальная очистка

echo ""
echo "8. Финальная очистка..."

# Синхронизируем файловые системы
sync

# Очищаем кэш дисков
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

echo "  ✓ Система очищена"

### 9. Завершение

echo ""
echo "=== Очистка завершена! ==="
echo ""
echo "Диски полностью очищены и готовы для повторной установки."
echo ""
echo "Теперь можно запустить установку:"
echo "  ./install_raid0.sh"
echo ""
echo "Или проверить состояние дисков:"
echo "  lsblk"
echo "  parted /dev/nvme0n1 print"
echo "  parted /dev/nvme1n1 print"

exit 0 
#!/bin/bash
set -euo pipefail

echo "=== Смена паролей в Arch Linux ==="
echo ""

# Параметры
DISKS=("/dev/nvme0n1" "/dev/nvme1n1")
RAID_DEVICE="/dev/md0"
USERNAME="pinya"

# Новые пароли (замените на свои)
NEW_ROOT_PASSWORD="root123"
NEW_USER_PASSWORD="pinya123"

echo "Диски: ${DISKS[*]}"
echo "RAID устройство: $RAID_DEVICE"
echo ""
echo "НОВЫЕ ПАРОЛИ:"
echo "  Root: $NEW_ROOT_PASSWORD"
echo "  User ($USERNAME): $NEW_USER_PASSWORD"
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

### 2. Сборка RAID

echo ""
echo "2. Сборка RAID..."
if mdadm --assemble "$RAID_DEVICE" "${DISKS[0]}p2" "${DISKS[1]}p2"; then
  echo "  ✓ RAID собран"
else
  echo "  ✗ Не удалось собрать RAID"
  exit 1
fi

### 3. Монтирование системы

echo ""
echo "3. Монтирование системы..."

# Создаем точки монтирования
mkdir -p /mnt/passwd_change

# Монтируем корневую файловую систему
if mount -o subvol=@ "$RAID_DEVICE" /mnt/passwd_change; then
  echo "  ✓ Корневая ФС смонтирована"
else
  echo "  ✗ Не удалось смонтировать корневую ФС"
  exit 1
fi

# Монтируем ESP
if mount "${DISKS[0]}p1" /mnt/passwd_change/boot; then
  echo "  ✓ ESP смонтирован"
else
  echo "  ✗ Не удалось смонтировать ESP"
fi

### 4. Смена паролей

echo ""
echo "4. Смена паролей..."

arch-chroot /mnt/passwd_change /bin/bash -e <<EOF
# Смена пароля root
echo "root:$NEW_ROOT_PASSWORD" | chpasswd
echo "  ✓ Пароль root изменен"

# Смена пароля пользователя
echo "$USERNAME:$NEW_USER_PASSWORD" | chpasswd
echo "  ✓ Пароль пользователя $USERNAME изменен"

# Проверка пользователей
echo ""
echo "Пользователи в системе:"
cat /etc/passwd | grep -E "(root|$USERNAME)"
echo ""
EOF

### 5. Завершение

echo ""
echo "5. Завершение..."
umount -R /mnt/passwd_change

echo ""
echo "=== Смена паролей завершена! ==="
echo ""
echo "НОВЫЕ ПАРОЛИ ДЛЯ ВХОДА:"
echo "  Root: $NEW_ROOT_PASSWORD"
echo "  User ($USERNAME): $NEW_USER_PASSWORD"
echo ""
echo "Теперь можно перезагрузиться и войти в систему с новыми паролями."

exit 0 
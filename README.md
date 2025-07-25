# Arch Linux RAID0 Автоматическая Установка

Этот проект содержит скрипты для автоматической установки Arch Linux с RAID0 на двух NVMe дисках.

## Структура проекта

- `install_raid0.sh` — основной скрипт установки (RAID0)
- `install_single.sh` — установка Arch Linux на один диск без RAID
- `check_raid.sh` — диагностика RAID
- `recover_raid.sh` — восстановление системы
- `clean_raid.sh` — полная очистка RAID перед повторной установкой
- `quick_clean.sh` — быстрая очистка RAID (без подтверждения)
- `change_passwords.sh` — смена паролей в установленной системе

## Установка

Для запуска скриптов с LiveCD Arch Linux, выполните следующие шаги:

1.  **Обновите список пакетов:**
    ```bash
    pacman -Sy
    ```

2.  **Установите git:**
    ```bash
    pacman -S --noconfirm git
    ```

3.  **Клонируйте репозиторий:**
    ```bash
    git clone https://github.com/PinyaGit/ArchRAID0
    ```

4.  **Перейдите в директорию проекта:**
    ```bash
    cd ArchRAID0
    ```

После этого вы можете сделать любой скрипт исполняемым (`chmod +x <имя_скрипта>.sh`) и запустить его (`./<имя_скрипта>.sh`).

**Пример для основной установки:**

```bash
chmod +x install_raid0.sh
./install_raid0.sh
```

**Пароли по умолчанию (которые установит скрипт):**
- Root: `root`
- User (pinya): `root`

## Установка на один диск (без RAID)

Если вы хотите установить Arch Linux только на один NVMe-диск без RAID, используйте скрипт `install_single.sh`:

```bash
chmod +x install_single.sh
./install_single.sh
```

**Что делает install_single.sh:**
1. Очищает диск `/dev/nvme0n1`
2. Создаёт две раздела:
   - ESP (EFI System Partition) — 1GB
   - Основной раздел (Btrfs)
3. Форматирует ESP в FAT32, основной раздел в Btrfs
4. Создаёт субволюмы Btrfs: `@`, `@home`, `@log`, `@pkg`, `@snapshots`
5. Устанавливает Arch Linux с вашими настройками
6. Настраивает systemd-boot для загрузки
7. Автоматически устанавливает git и base-devel

**Структура файловых систем после установки:**

```
/dev/nvme0n1p2 (Btrfs)
├── @ (root)
├── @home
├── @log
├── @pkg
└── @snapshots

/dev/nvme0n1p1 (ESP)
```

**Примечание:** Все параметры (hostname, пользователь, пароли, зеркала, часовой пояс) можно изменить в начале скрипта.

## Что делает скрипт

1. **Очищает оба диска** от всех данных
2. **Создает разделы** на каждом диске:
   - ESP (EFI System Partition) — 1GB на каждом диске
   - RAID раздел — остальное место
3. **Создает RAID0 массив** из RAID разделов
4. **Форматирует файловые системы:**
   - ESP в FAT32
   - RAID в Btrfs с субволюмами
5. **Устанавливает Arch Linux** с вашими настройками
6. **Настраивает systemd-boot** для загрузки с RAID0
7. **Копирует ESP** на второй диск для резервирования
8. **Автоматически устанавливает git и base-devel**
9. **Оптимизирует makepkg для сборки на всех ядрах**

## После установки

1. **Перезагрузите систему**
2. **Извлеките установочный носитель**
3. **Проверьте загрузку**

## Диагностика

Если система не загружается, используйте скрипт проверки:

```bash
chmod +x check_raid.sh
./check_raid.sh
```

## Повторная установка

Если установка прошла неудачно и нужно начать заново:

### Полная очистка (рекомендуется)
```bash
chmod +x clean_raid.sh
./clean_raid.sh
```

### Быстрая очистка (экстренная)
```bash
chmod +x quick_clean.sh
./quick_clean.sh
```

После очистки можно запускать установку заново:
```bash
./install_raid0.sh
```

## Восстановление

В случае проблем с RAID:

1. **Загрузитесь с Live USB**
2. **Соберите RAID:**
   ```bash
   mdadm --assemble /dev/md0 /dev/nvme0n1p2 /dev/nvme1n1p2
   ```
3. **Смонтируйте систему:**
   ```bash
   mount -o subvol=@ /dev/md0 /mnt
   mount /dev/nvme0n1p1 /mnt/boot
   arch-chroot /mnt
   ```

## Смена паролей

Если пароли не работают, используйте скрипт смены паролей:

```bash
chmod +x change_passwords.sh
./change_passwords.sh
```

Этот скрипт установит новые пароли:
- Root: `root`
- User (pinya): `root`

## Структура файловых систем

```
/dev/md0 (RAID0)
├── @ (root)
├── @home
├── @log
├── @pkg
└── @snapshots

/dev/nvme0n1p1 (ESP)
/dev/nvme1n1p1 (ESP backup)
```

## Настройки системы

- **Хостнейм:** arch
- **Пользователь:** pinya (с sudo правами)
- **Ядро:** linux-zen
- **Загрузчик:** systemd-boot
- **Файловая система:** Btrfs с сжатием zstd
- **Локаль:** ru_RU.UTF-8
- **Часовой пояс:** Europe/Moscow

## Безопасность

- Все пароли по умолчанию: `root`
- Пользователь pinya имеет sudo права
- Root пароль установлен

## Резервное копирование

Для создания резервной копии системы используйте Timeshift:

```bash
sudo pacman -S timeshift
sudo timeshift --create --comments "Initial backup"
```

## Поддержка

При возникновении проблем:
1. Проверьте логи: `journalctl -xb`
2. Проверьте состояние RAID: `mdadm --detail /dev/md0`
3. Проверьте загрузчик: `bootctl status`

## Геймерская подготовка системы (postinstall_gaming.sh)

Для быстрой подготовки Arch Linux к запуску современных игр используйте скрипт `postinstall_gaming.sh`:

```bash
chmod +x postinstall_gaming.sh
sudo ./postinstall_gaming.sh
```

**Что делает скрипт:**
- Автоматически определяет вашу видеокарту (NVIDIA, AMD, Intel) и устанавливает только нужные драйверы
- Включает multilib-репозиторий
- Устанавливает:
  - Steam
  - Lutris
  - Wine (wine-staging), winetricks, protontricks
  - Gamemode
  - Pipewire (современная звуковая подсистема)
  - OBS Studio (запись/стриминг)
  - Мониторинг: htop, nvtop, gparted
  - Поддержку геймпадов (steam-devices)
  - yay (AUR helper)

**Примечание:**
Скрипт не ставит лишнего — драйверы и компоненты подбираются автоматически. После выполнения рекомендуется перезагрузить систему.

### Советы по оптимизации и настройке игр

- **Proton:**
  - В Steam включите поддержку Proton для всех игр: Настройки → Steam Play → Включить Steam Play для всех других игр.
  - Для нестабильных игр используйте Proton Experimental или Proton-GE (можно установить через yay: `yay -S proton-ge-custom`).
- **Gamemode:**
  - В Steam добавьте к запуску игры параметр `gamemoderun %command%` для автоматической оптимизации.
- **Vulkan:**
  - Для большинства современных игр рекомендуется использовать Vulkan-рендер (установлен с драйверами).
- **DXVK:**
  - DXVK (DirectX → Vulkan) уже включён в Proton, но для Wine-игр вне Steam можно установить через winetricks: `winetricks dxvk`.
- **Мониторинг:**
  - Используйте `htop`, `nvtop` для отслеживания загрузки CPU/GPU.
- **Btrfs snapshots:**
  - Для безопасных экспериментов с драйверами используйте Timeshift для создания снапшотов системы.

### FAQ для геймеров

**Q: Steam не запускается или не видит библиотеку игр?**
A: Проверьте, что multilib включён, и установлены все 32-битные библиотеки драйверов (см. скрипт).

**Q: Как установить Proton-GE?**
A: После установки yay выполните: `yay -S proton-ge-custom`. В Steam выберите версию Proton-GE для игры.

**Q: Как запускать Windows-игры вне Steam?**
A: Используйте Lutris или Wine. Для удобства настройки — winetricks и protontricks.

**Q: Как проверить, что драйвер видеокарты работает?**
A: Для NVIDIA — команда `nvidia-smi`, для AMD/Intel — `glxinfo | grep OpenGL`.

**Q: Как включить геймпад?**
A: Подключите контроллер, Steam обычно определяет его автоматически. Для Xbox-контроллеров можно установить `xboxdrv` или `xpad`.

**Q: Как записывать или стримить геймплей?**
A: Используйте OBS Studio (установлен скриптом).

**Q: Где искать помощь?**
A: Arch Wiki (https://wiki.archlinux.org/title/Gaming), ProtonDB (https://www.protondb.com/), форумы Steam и Lutris.

Подробнее о гейминге на Arch: [Arch Wiki Gaming](https://wiki.archlinux.org/title/Gaming)
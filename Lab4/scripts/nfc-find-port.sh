#!/bin/sh
set -e

echo "Подключи PN532/USB-модуль к Mac. Возможные порты:"
ls /dev/cu.* 2>/dev/null | grep -Ei 'usb|serial|uart|wch|slab|ch340|cp210|modem' || true

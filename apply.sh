#!/usr/bin/env bash
# apply.sh — применить (или обновить) конфигурацию Home Manager
#
# Первый запуск: скачивает и устанавливает все пакеты из конфига.
# Повторный запуск: синхронизирует окружение с текущим состоянием home.nix.
#
# Использование: ./apply.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Применяю конфигурацию Home Manager..."
echo "    Пользователь : $USER"
echo "    HOME         : $HOME"
echo "    Конфиг       : $SCRIPT_DIR"
echo ""

# Убедимся что flakes включены (на случай если nix.conf ещё не настроен)
NIX_CONF="$HOME/.config/nix/nix.conf"
if [ ! -f "$NIX_CONF" ] || ! grep -q "flakes" "$NIX_CONF" 2>/dev/null; then
    echo "==> Включаю nix flakes для пользователя..."
    mkdir -p "$HOME/.config/nix"
    echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
fi

# Запускаем home-manager switch через nix run
# --impure нужен чтобы flake мог читать $HOME и $USER из окружения
cd "$SCRIPT_DIR"
nix run home-manager/master -- switch --flake .#default --impure

echo ""
echo "==> Готово! Перезапусти терминал чтобы изменения вступили в силу:"
echo "    exec \$SHELL"

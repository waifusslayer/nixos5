#!/usr/bin/env bash
# uninstall.sh — полностью удалить окружение Home Manager для текущего пользователя
#
# Удаляет:
#   - профиль Home Manager (~/.nix-profile и связанные данные)
#   - конфиги шеллов, прописанные Home Manager
#   - саму папку с репозиторием (~/dotfiles или директория скрипта)
#
# НЕ трогает:
#   - /nix/store и сам Nix (они общие для всего сервера!)
#   - ~/.kube, ~/.ssh, ~/.aws и другие пользовательские данные
#   - окружения других пользователей
#
# Использование: ./uninstall.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Удаление окружения Home Manager для пользователя: $USER"
echo ""
echo "ВНИМАНИЕ: это удалит все пакеты и конфиги, установленные через этот репозиторий."
echo "Nix и /nix/store НЕ затрагиваются — они общие для всех пользователей сервера."
echo ""
read -r -p "Продолжить? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "Отменено."
    exit 0
fi

# 1. Убираем Home Manager через встроенный механизм (если доступен)
echo ""
echo "==> Шаг 1: удаление поколений Home Manager..."
if command -v home-manager &>/dev/null; then
    home-manager expire-generations "-0 days" 2>/dev/null || true
fi

# 2. Удаляем nix-профиль пользователя
echo "==> Шаг 2: удаление ~/.nix-profile и связанных данных..."
rm -rf \
    "$HOME/.nix-profile" \
    "$HOME/.nix-defexpr" \
    "$HOME/.local/state/nix" \
    "$HOME/.local/state/home-manager" \
    "$HOME/.config/home-manager" \
    "$HOME/."nix-channels \
    2>/dev/null || true

# 3. Чистим конфиги nix (пользовательские настройки flakes и т.д.)
echo "==> Шаг 3: очистка ~/.config/nix..."
rm -rf "$HOME/.config/nix" 2>/dev/null || true

# 4. Убираем строки инициализации из шелл-конфигов
echo "==> Шаг 4: очистка шелл-конфигов от записей Home Manager..."
for RC_FILE in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.bash_profile"; do
    if [ -f "$RC_FILE" ]; then
        # Home Manager добавляет блок с маркером. Удаляем его.
        sed -i '/# Home Manager session variables/,/^$/d' "$RC_FILE" 2>/dev/null || true
        sed -i '/\.nix-profile/d' "$RC_FILE" 2>/dev/null || true
        sed -i '/home-manager/d' "$RC_FILE" 2>/dev/null || true
    fi
done

# 5. Удаляем саму директорию с репозиторием
echo "==> Шаг 5: удаление репозитория ($SCRIPT_DIR)..."
# Сохраним путь, потом удалим (скрипт уже загружен в память)
REPO_DIR="$SCRIPT_DIR"
cd "$HOME"
rm -rf "$REPO_DIR"

echo ""
echo "==> Готово. Окружение удалено."
echo "    Перезапусти терминал: exec \$SHELL"
echo ""
echo "    Примечание: /nix/store не тронут. Если пакеты из store"
echo "    больше не нужны никому — администратор может запустить"
echo "    nix-collect-garbage -d от root."

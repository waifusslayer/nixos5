# DevOps Environment — Nix Home Manager

Декларативное пользовательское окружение для DevOps-инженера на бастион-сервере.
Работает **полностью в userspace** — каждый сотрудник управляет только своим HOME,
не затрагивая других пользователей и не требуя root.

---

## Что входит

| Категория | Инструменты |
|---|---|
| **Kubernetes** | kubectl, kubectx, kubens, kubecm, argocd, helm, kustomize, krew + плагины (stern, neat, tree, access-matrix, images) |
| **Cloud** | aws-cli v2, rclone |
| **Утилиты** | git, fzf, ripgrep, bat, eza, jq, yq, curl, rsync и др. |
| **Шеллы** | zsh (default), fish, bash, ksh — с completions и алиасами |
| **Редакторы** | neovim (default), vim, nano, helix (опционально) |
| **Промпт** | Starship — однострочный, с kubernetes-контекстом |
| **История** | Atuin — единое хранилище истории всех шеллов |

---

## Как устроена изоляция пользователей

Nix хранит все пакеты в `/nix/store` — общем read-only хранилище на всём сервере.
Каждый пользователь получает **свой** `~/.nix-profile` — набор симлинков на пакеты
из store. Это значит:

- Удаление или изменение конфига одного сотрудника **никак не влияет** на других.
- Пакеты в `/nix/store` переиспользуются между пользователями — не скачиваются повторно.
- Все данные (kubeconfig, SSH-ключи, история) хранятся в HOME каждого пользователя отдельно.

---

## Быстрый старт для нового сотрудника

### 1. Проверь, установлен ли Nix

Nix устанавливается один раз администратором и доступен всем пользователям сервера.
Просто проверь:

```bash
nix --version
# nix (Nix) 2.x.x
```

Если команда не найдена — обратись к администратору. Самостоятельно устанавливать Nix
через `sudo` не нужно.

---

### 2. Склонируй репозиторий

```bash
git clone <url-репозитория> ~/dotfiles
cd ~/dotfiles
```

---

### 3. Выбери свой шелл и настройки

Открой `home.nix` и отредактируй блок `custom`:

```nix
custom = {
  preferredShell = "zsh";   # zsh | fish | bash | ksh
  enableK8s      = true;    # kubectl, helm, krew и т.д.
  enableAws      = true;    # aws-cli, rclone
  enableHelix    = false;   # редактор helix (опционально)
};
```

> **По умолчанию** стоит `zsh`. Если не уверен — оставь как есть.

Так же сделай скрипты исполняемыми 

```bash
chmod +x apply.sh
chmod +x uninstall.sh
```

---

### 4. Применить конфигурацию

```bash
./apply.sh
```

Скрипт запустит `nix run` и скачает все необходимые пакеты.
При первом запуске это займёт несколько минут.
Последующие запуски работают быстрее благодаря кешу.

После завершения **перезапусти терминал**:

```bash
exec $SHELL
```

---

### 5. Проверь что всё работает

```bash
echo $SHELL
kubectl version --client
helm version
krew version
k get nodes   # = kubectl get nodes
ll            # = eza -la --icons
```

---

## Обновление конфига

Если ты изменил `home.nix` — запусти `apply.sh` снова.
Скрипт синхронизирует окружение с новым состоянием конфига:

```bash
cd ~/dotfiles
./apply.sh
```

---

## Обновление версий пакетов

`flake.lock` фиксирует конкретные версии nixpkgs на момент клонирования репо.
Чтобы подтянуть свежие версии всех пакетов до актуальных:

```bash
cd ~/dotfiles
nix flake update
./apply.sh
```

`nix flake update` обновляет `flake.lock` до актуальных коммитов nixpkgs — после этого
`apply.sh` пересоберёт окружение с новыми версиями. Окружения других пользователей
не затрагиваются: у каждого свой `flake.lock` в своём `~/dotfiles`.

---

## Удаление окружения

Чтобы полностью убрать всё что было установлено и вернуть чистый HOME:

```bash
cd ~/dotfiles
./uninstall.sh
```

Скрипт удалит:
- установленные пакеты (`~/.nix-profile`)
- конфиги шеллов, прописанные Home Manager
- сам репозиторий `~/dotfiles`

**Nix и `/nix/store` не затрагиваются** — они общие для всего сервера.

---

## Пользовательские оверрайды

Хочешь добавить своё — **не трогай nix-файлы**, создай оверрайд в HOME:

| Шелл | Файл для оверрайда |
|---|---|
| zsh | `~/.config/zsh/extra.zsh` |
| bash | `~/.config/bash/extra.bash` |
| fish | `~/.config/fish/extra.fish` |
| ksh | `~/.config/ksh/extra.kshrc` |
| neovim | `~/.config/nvim/init.lua` |
| helix | `~/.config/helix/config.toml` |

Эти файлы автоматически подхватываются при старте шелла и никогда не перезаписываются
Home Manager.

---

## Kubeconfig и SSH

`~/.kube/config` и `~/.ssh/` **не трогаются** Home Manager.
Кладёшь свои конфиги туда как обычно.

Для нескольких kubeconfig-ов удобно использовать `kubecm`:

```bash
kubecm add -f ~/my-cluster.yaml
kubecm ls
ktx   # переключить контекст
kns   # переключить namespace
```

---

## Полезные алиасы

| Алиас | Команда |
|---|---|
| `k` | kubectl |
| `kg` | kubectl get |
| `kd` | kubectl describe |
| `kl` | kubectl logs |
| `ke` | kubectl exec -it |
| `kns` | kubens |
| `ktx` | kubectx |
| `ll` | eza -la --icons |
| `hms` | home-manager switch --flake .#default |
| `gc` | nix-collect-garbage -d |

---

## Добавить новый инструмент

1. Найди пакет: `nix search nixpkgs <название>`
2. Добавь в нужный модуль (например `core-utils.nix`):
   ```nix
   home.packages = with pkgs; [
     ...
     <новый-пакет>
   ];
   ```
3. Примени: `./apply.sh`

---

## Структура проекта

```
.
├── apply.sh                   # применить / обновить конфигурацию
├── uninstall.sh               # удалить окружение и репозиторий
├── flake.nix                  # точка входа, inputs (nixpkgs, home-manager, krewfile)
├── home.nix                   # главный файл — редактируй флаги здесь
└── modules/
    ├── options.nix            # объявление всех custom.* флагов
    ├── core-utils.nix         # базовые утилиты (git, fzf, curl, …)
    ├── kubernetes.nix         # k8s-инструменты + krew-плагины
    ├── editors.nix            # neovim, vim, nano, helix
    ├── cloud.nix              # aws-cli, rclone
    └── shells/
        ├── default.nix        # логика выбора шелла
        ├── common.nix         # общие алиасы для всех шеллов
        ├── zsh.nix
        ├── bash.nix
        ├── fish.nix
        └── ksh.nix
```

---

## Возможные проблемы

**`error: experimental Nix feature 'flakes' is not enabled`**

```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

`apply.sh` проверяет и добавляет это автоматически.

---

**`krew: command not found` после первого apply**

Krew устанавливается в `~/.krew/bin` — убедись что PATH обновился:

```bash
exec $SHELL
krew version
```

---

**`nix` недоступен — команда не найдена**

Обратись к администратору сервера — Nix должен быть установлен системно.

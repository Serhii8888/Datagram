#!/bin/bash

# ========= Налаштування =========
SERVICE_PREFIX=datagram
BINARY_URL="https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux"

# ========= Функція встановлення багатьох нод =========
function install_nodes() {
    read -p "👉 Скільки нод встановити?: " NODE_COUNT

    for (( i=1; i<=NODE_COUNT; i++ )); do
        echo "\n🔹 Встановлення ноди #$i..."
        read -p "👉 Введіть ключ для ноди #$i: " NODE_KEY

        NODE_DIR="$HOME/${SERVICE_PREFIX}_$i"
        SERVICE_NAME="${SERVICE_PREFIX}_$i"

        mkdir -p "$NODE_DIR"
        cd "$NODE_DIR"

        wget -O datagram-cli "$BINARY_URL"
        chmod +x datagram-cli

        # Створюємо systemd сервіс
        sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" > /dev/null << EOF
[Unit]
Description=Datagram Node #$i
After=network.target

[Service]
User=$USER
WorkingDirectory=$NODE_DIR
ExecStart=$NODE_DIR/datagram-cli run -- -key $NODE_KEY
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME"
        sudo systemctl start "$SERVICE_NAME"

        echo "✅ Нода #$i встановлена та запущена. Перевірити логи: journalctl -u $SERVICE_NAME -f"
    done
}

# ========= Функція перезапуску всіх нод =========
function restart_nodes() {
    echo "♻️ Перезапуск всіх нод..."
    for service in $(systemctl list-units --type=service --state=running | grep "${SERVICE_PREFIX}_" | awk '{print $1}'); do
        sudo systemctl restart "$service"
        echo "✅ Перезапущено $service"
    done
}

# ========= Перегляд логів =========
function view_logs() {
    echo "📜 Активні ноди для перегляду логів:"
    systemctl list-units --type=service --state=running | grep "${SERVICE_PREFIX}_" | awk '{print NR ". " $1}'
    read -p "👉 Введіть номер ноди для перегляду логів: " choice
    SERVICE_NAME=$(systemctl list-units --type=service --state=running | grep "${SERVICE_PREFIX}_" | awk "NR==$choice {print \\$1}")

    if [ -n "$SERVICE_NAME" ]; then
        echo "📜 Вивід логів для $SERVICE_NAME. Для виходу натисніть Ctrl+C."
        sudo journalctl -u "$SERVICE_NAME" -f
    else
        echo "❌ Невірний вибір."
    fi
}

# ========= Видалення всіх нод =========
function remove_nodes() {
    echo "⚠️ Видалення всіх нод, встановлених через цей скрипт..."
    read -p "Ви впевнені, що хочете видалити всі ноди? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        for service in $(systemctl list-units --type=service | grep "${SERVICE_PREFIX}_" | awk '{print $1}' | sed 's/\.service//'); do
            echo "🛑 Зупинка та видалення $service"
            sudo systemctl stop "$service"
            sudo systemctl disable "$service"
            sudo rm "/etc/systemd/system/${service}.service"
            rm -rf "$HOME/${service}"
        done
        sudo systemctl daemon-reload
        echo "✅ Усі ноди видалено."
    else
        echo "❌ Видалення скасовано."
    fi
}

# ========= Меню =========
while true; do
    echo "\n🚀 Меню керування багатьма нодами Datagram:"
    echo "1️⃣ Встановити ноди"
    echo "2️⃣ Перезапустити всі ноди"
    echo "3️⃣ Переглянути логи ноди"
    echo "4️⃣ Видалити всі ноди"
    echo "5️⃣ Вийти"
    read -p "👉 Введіть номер опції: " choice

    case $choice in
        1) install_nodes ;;
        2) restart_nodes ;;
        3) view_logs ;;
        4) remove_nodes ;;
        5) echo "👋 Вихід..."; exit 0 ;;
        *) echo "❌ Невірна опція. Спробуйте ще раз." ;;
    esac
done

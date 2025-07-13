#!/bin/bash

SERVICE_PREFIX=datagram
BINARY_URL="https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux"

function install_nodes() {
    read -p "👉 Скільки нод встановити?: " NODE_COUNT

    declare -a NODE_KEYS
    for (( i=1; i<=NODE_COUNT; i++ )); do
        read -p "🔑 Введіть ключ для ноди #$i: " NODE_KEYS[$i]
    done

    for (( i=1; i<=NODE_COUNT; i++ )); do
        local NODE_KEY="${NODE_KEYS[$i]}"
        local NODE_NUM=$i
        echo "🔹 Встановлення ноди #$NODE_NUM з ключем $NODE_KEY"

        NODE_DIR="$HOME/${SERVICE_PREFIX}_$NODE_NUM"
        SERVICE_NAME="${SERVICE_PREFIX}_$NODE_NUM"

        mkdir -p "$NODE_DIR"
        cd "$NODE_DIR"

        wget -O datagram-cli "$BINARY_URL"
        chmod +x datagram-cli

        sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" > /dev/null << EOF
[Unit]
Description=Datagram Node #$NODE_NUM
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

        echo "✅ Нода #$NODE_NUM встановлена та запущена."
    done
}

function restart_nodes() {
    echo "♻️ Перезапуск всіх нод..."
    local services
    mapfile -t services < <(systemctl list-units --type=service --state=running | grep "${SERVICE_PREFIX}_" | awk '{print $1}')
    if [ ${#services[@]} -eq 0 ]; then
        echo "❌ Немає запущених нод для перезапуску."
        return
    fi
    for service in "${services[@]}"; do
        sudo systemctl restart "$service"
        echo "✅ Перезапущено $service"
    done
}

function view_logs() {
    echo "📜 Активні ноди для перегляду логів:"
    mapfile -t services < <(systemctl list-units --type=service --state=running | grep "${SERVICE_PREFIX}_" | awk '{print $1}')
    if [ ${#services[@]} -eq 0 ]; then
        echo "❌ Немає запущених нод."
        return
    fi

    for i in "${!services[@]}"; do
        echo "$((i+1)). ${services[$i]}"
    done

    read -p "👉 Введіть номер ноди для перегляду логів: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#services[@]} )); then
        echo "❌ Невірний вибір."
        return
    fi

    SERVICE_NAME="${services[$((choice-1))]}"
    echo "📜 Вивід логів для $SERVICE_NAME. Для виходу натисніть Ctrl+C."
    sudo journalctl -u "$SERVICE_NAME" -f
}

function remove_nodes() {
    echo "⚠️ Видалення всіх нод, встановлених через цей скрипт..."
    read -p "Ви впевнені, що хочете видалити всі ноди? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        local services
        mapfile -t services < <(systemctl list-units --type=service | grep "${SERVICE_PREFIX}_" | awk '{print $1}' | sed 's/\\.service//')
        if [ ${#services[@]} -eq 0 ]; then
            echo "❌ Немає встановлених нод для видалення."
            return
        fi
        for service in "${services[@]}"; do
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

while true; do
    echo ""
    echo "🚀 Меню керування багатьма нодами Datagram:"
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

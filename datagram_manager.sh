#!/bin/bash

SERVICE_NAME=datagram
NODE_DIR=$HOME/datagram
BINARY_URL="https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux"

function install_node() {
    echo "🔹 Встановлення ноди Datagram..."
    read -p "👉 Введіть ваш ключ (-key ...): " NODE_KEY

    mkdir -p $NODE_DIR
    cd $NODE_DIR

    wget -O datagram-cli $BINARY_URL
    chmod +x datagram-cli

    # Створюємо systemd сервіс
    sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << EOF
[Unit]
Description=Datagram Node
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
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME

    echo "✅ Нода встановлена та запущена. Перевірити логи: journalctl -u $SERVICE_NAME -f"
}

function restart_node() {
    echo "♻️ Перезапуск ноди..."
    sudo systemctl restart $SERVICE_NAME
    echo "✅ Нода перезапущена."
}

function view_logs() {
    echo "📜 Вивід логів. Для виходу натисніть Ctrl+C."
    sudo journalctl -u $SERVICE_NAME -f
}

function remove_node() {
    echo "⚠️ Видалення ноди..."
    read -p "Ви впевнені, що хочете видалити ноду? (y/n): " confirm
    if [[ $confirm == "y" ]]; then
        sudo systemctl stop $SERVICE_NAME
        sudo systemctl disable $SERVICE_NAME
        sudo rm /etc/systemd/system/$SERVICE_NAME.service
        sudo systemctl daemon-reload
        rm -rf $NODE_DIR
        echo "✅ Нода видалена."
    else
        echo "❌ Видалення скасовано."
    fi
}

while true; do
    echo ""
    echo "🚀 Меню керування нодою Datagram:"
    echo "1️⃣ Встановити ноду"
    echo "2️⃣ Перезапустити ноду"
    echo "3️⃣ Переглянути логи"
    echo "4️⃣ Видалити ноду"
    echo "5️⃣ Вийти"
    read -p "👉 Введіть номер опції: " choice

    case $choice in
        1) install_node ;;
        2) restart_node ;;
        3) view_logs ;;
        4) remove_node ;;
        5) echo "👋 Вихід..."; exit 0 ;;
        *) echo "❌ Невірна опція. Спробуйте ще раз." ;;
    esac
done

#!/bin/bash

SERVICE_PREFIX=datagram
IMAGE_NAME=datagram-node
BASE_PORT=5000

function build_image() {
    echo "🔹 Створюємо Dockerfile..."
    cat << EOF > Dockerfile
FROM ubuntu:20.04

RUN apt-get update && apt-get install -y wget screen && rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux \\
    && mv datagram-cli-x86_64-linux /usr/bin/datagram-cli \\
    && chmod +x /usr/bin/datagram-cli

CMD ["/bin/bash", "-c", "screen -S datagram -d -m datagram-cli run -- -key \$DATAGRAM_KEY && tail -f /dev/null"]
EOF

    echo "🔹 Будуємо Docker-образ..."
    if ! docker build -t $IMAGE_NAME .; then
        echo "❌ Помилка при створенні Docker-образу. Перевірте інтернет та Dockerfile."
        exit 1
    fi

    rm Dockerfile
    echo "✅ Docker-образ $IMAGE_NAME створено."
}

function install_nodes() {
    build_image

    echo "👉 Введіть ключі для нод (по одному в рядок)."
    echo "🔹 Після введення всіх ключів натисніть Enter на порожньому рядку для завершення."

    NODE_KEYS=()
    while true; do
        read -r key
        [[ -z "$key" ]] && break
        NODE_KEYS+=("$key")
    done

    NODE_COUNT=${#NODE_KEYS[@]}
    echo "🔹 Ви ввели $NODE_COUNT ключ(ів). Починаємо запуск контейнерів..."

    # Видаляємо старі контейнери
    echo "🔹 Видалення старих контейнерів..."
    docker ps -a --filter "name=${SERVICE_PREFIX}_" -q | xargs -r docker rm -f

    for (( i=0; i<NODE_COUNT; i++ )); do
        NODE_KEY="${NODE_KEYS[$i]}"
        NODE_NUM=$((i+1))
        PORT=$((BASE_PORT + i))
        CONTAINER_NAME="${SERVICE_PREFIX}_$NODE_NUM"

        echo "🔹 Запуск контейнера $CONTAINER_NAME з портом $PORT"

        if ! docker run -d --restart unless-stopped --name "$CONTAINER_NAME" -e DATAGRAM_KEY="$NODE_KEY" -p "$PORT:5000" $IMAGE_NAME; then
            echo "❌ Помилка запуску контейнера $CONTAINER_NAME"
        else
            echo "✅ Контейнер $CONTAINER_NAME запущено (порт $PORT)"
            echo "⏳ Затримка 2 секунди перед запуском наступного контейнера..."
            sleep 2
        fi
    done

    echo "✅ Усі контейнери запущено. Використовуйте 'docker ps' для перегляду."
}

function restart_nodes() {
    echo "♻️ Перезапуск всіх контейнерів..."
    mapfile -t containers < <(docker ps --filter "name=${SERVICE_PREFIX}_" --format "{{.Names}}")
    if [ ${#containers[@]} -eq 0 ]; then
        echo "❌ Немає запущених контейнерів для перезапуску."
        return
    fi
    for container in "${containers[@]}"; do
        docker restart "$container"
        echo "✅ Перезапущено $container"
        echo "⏳ Затримка 20 секунд перед перезапуском наступного контейнера..."
        sleep 20
    done
}

function view_logs() {
    echo "📜 Список контейнерів:"
    mapfile -t containers < <(docker ps --filter "name=${SERVICE_PREFIX}_" --format "{{.Names}}")
    if [ ${#containers[@]} -eq 0 ]; then
        echo "❌ Немає запущених контейнерів."
        return
    fi

    for i in "${!containers[@]}"; do
        echo "$((i+1)). ${containers[$i]}"
    done

    read -p "👉 Введіть номер контейнера для перегляду логів: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#containers[@]} )); then
        echo "❌ Невірний вибір."
        return
    fi

    CONTAINER_NAME="${containers[$((choice-1))]}"
    echo "📜 Логи для $CONTAINER_NAME. Для виходу натисніть Ctrl+C."
    docker logs -f "$CONTAINER_NAME"
}

function remove_nodes() {
    echo "⚠️ Видалення всіх контейнерів ${SERVICE_PREFIX}_..."
    read -p "Ви впевнені, що хочете видалити всі ноди? (y/n): " confirm
    if [[ "$confirm" == "y" ]]; then
        docker ps -a --filter "name=${SERVICE_PREFIX}_" -q | xargs -r docker rm -f
        echo "✅ Усі контейнери видалено."
    else
        echo "❌ Видалення скасовано."
    fi
}

# Перевірка встановлення Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не встановлено. Встановлюємо..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "✅ Docker встановлено та запущено."
fi

while true; do
    echo ""
    echo "🚀 Меню керування багатьма нодами Datagram (Docker):"
    echo "1️⃣ Встановити (запустити) ноди"
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

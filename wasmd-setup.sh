#!/bin/bash
set -e

# Загрузка переменных окружения из .env, если есть
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

function pause() {
    echo -e "\nНажмите Enter для возврата в меню..."
    read
}

function clone_repo() {
    if [ -d "wasmd" ]; then
        echo "Папка wasmd уже существует. Пропускаем клонирование."
    else
        git clone https://github.com/kitay-sudo/wasmd.git wasmd && echo "Репозиторий успешно клонирован!" || { echo "Ошибка при клонировании!"; pause; return; }
    fi
    pause
}

function install_deps() {
    echo "Установка зависимостей..."
    sudo apt update
    sudo apt install -y build-essential make git curl jq nano screen crudini libssl-dev autoconf libtool pkg-config
    sudo apt install -y python3-pip
    sudo pip3 install python-dotenv cryptography toml toml-cli
    wget https://go.dev/dl/go1.22.2.linux-amd64.tar.gz
    sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.22.2.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    echo 'export PATH=$PATH:/root/go/bin' >> ~/.bashrc
    source ~/.bashrc
    # Проверяем, что Go доступен в PATH
    if ! command -v go &> /dev/null; then
        echo "Go не найден в PATH после установки. Проверьте настройки PATH."
        pause
        return
    fi
    rm go1.22.2.linux-amd64.tar.gz
    curl -sSL https://raw.githubusercontent.com/cyber-chip/GO_install_1.23.3/master/buf-Linux-x86_64 -o /usr/local/bin/buf
    sudo chmod +x /usr/local/bin/buf
    go version && make --version && git --version && echo "Все зависимости установлены!" || { echo "Ошибка при установке зависимостей!"; pause; return; }
    pause
}

function build_wasmd() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    make install && echo "wasmd успешно собран и установлен!" || { echo "Ошибка при сборке!"; cd ..; pause; return; }
    cd ..
    pause
}

function init_wasmd() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    # Запрашиваем MONIKER у пользователя
    read -p "Введите MONIKER для узла: " MONIKER
    MONIKER=${MONIKER:-node001}
    CHAIN_ID=${CHAIN_ID:-fzp-chain}
    wasmd init "$MONIKER" --chain-id "$CHAIN_ID" && echo "Узел wasmd успешно инициализирован!" || { echo "Ошибка при инициализации узла!"; cd ..; pause; return; }
    cd ..
    pause
}

function configure_wasmd() {
    GENESIS="/root/.wasmd/config/genesis.json"
    CONFIG_TOML="/root/.wasmd/config/config.toml"
    APP_TOML="/root/.wasmd/config/app.toml"

    STAKE="ufzp"
    export STAKE

    # Обновляем genesis.json через jq
    jq \
      --arg stake "$STAKE" \
      '.app_state.crisis.constant_fee.denom = $stake
       | .app_state.crisis.constant_fee.amount = "100000"
       | .app_state.gov.deposit_params.min_deposit[0].denom = $stake
       | .app_state.gov.deposit_params.min_deposit[0].amount = "10000000"
       | .app_state.gov.params.min_deposit[0].denom = $stake
       | .app_state.gov.params.min_deposit[0].amount = "10000000"
       | .app_state.gov.params.expedited_min_deposit[0].denom = $stake
       | .app_state.gov.params.expedited_min_deposit[0].amount = "50000000"
       | .app_state.mint.params.mint_denom = $stake
       | .app_state.staking.params.bond_denom = $stake
      ' "$GENESIS" > tmp_genesis.json && mv tmp_genesis.json "$GENESIS"

    # Изменяем chain_id, если нужно
    read -p "Введите chain-id (Enter чтобы пропустить): " CHAIN_ID
    if [ ! -z "$CHAIN_ID" ]; then
        jq --arg chain_id "$CHAIN_ID" '.chain_id = $chain_id' "$GENESIS" > tmp_genesis.json && mv tmp_genesis.json "$GENESIS"
    fi

    # Изменяем другие параметры через sed (если нужно)
    sed -i "s/\"max_validators\": [0-9]*/\"max_validators\": 100/" "$GENESIS"
    sed -i "s/\"unbonding_time\": \".*\"/\"unbonding_time\": \"1814400s\"/" "$GENESIS"
    sed -i "s/\"inflation\": \".*\"/\"inflation\": \"0.050000000000000000\"/" "$GENESIS"
    sed -i "s/\"annual_provisions\": \".*\"/\"annual_provisions\": \"0.000000000000000000\"/" "$GENESIS"
    sed -i "s/\"inflation_rate_change\": \".*\"/\"inflation_rate_change\": \"0.010000000000000000\"/" "$GENESIS"
    sed -i "s/\"inflation_max\": \".*\"/\"inflation_max\": \"0.015000000000000000\"/" "$GENESIS"
    sed -i "s/\"inflation_min\": \".*\"/\"inflation_min\": \"0.010000000000000000\"/" "$GENESIS"
    sed -i "s/\"goal_bonded\": \".*\"/\"goal_bonded\": \"0.670000000000000000\"/" "$GENESIS"
    sed -i "s/\"blocks_per_year\": \".*\"/\"blocks_per_year\": \"6311520\"/" "$GENESIS"
    sed -i "s/\"community_tax\": \".*\"/\"community_tax\": \"0.020000000000000000\"/" "$GENESIS"
    sed -i "s/\"base_proposer_reward\": \".*\"/\"base_proposer_reward\": \"0.010000000000000000\"/" "$GENESIS"
    sed -i "s/\"bonus_proposer_reward\": \".*\"/\"bonus_proposer_reward\": \"0.040000000000000000\"/" "$GENESIS"
    sed -i "s/\"withdraw_addr_enabled\": [a-z]*/\"withdraw_addr_enabled\": true/" "$GENESIS"
    sed -i "s/\"slash_fraction_double_sign\": \".*\"/\"slash_fraction_double_sign\": \"0.006300000000000000\"/" "$GENESIS"
    sed -i "s/\"slash_fraction_downtime\": \".*\"/\"slash_fraction_downtime\": \"0.002100000000000000\"/" "$GENESIS"
    sed -i "s/\"downtime_jail_duration\": \".*\"/\"downtime_jail_duration\": \"600s\"/" "$GENESIS"
    sed -i "s/\"signed_blocks_window\": \".*\"/\"signed_blocks_window\": \"100\"/" "$GENESIS"
    sed -i "s/\"min_signed_per_window\": \".*\"/\"min_signed_per_window\": \"0.500000000000000000\"/" "$GENESIS"

    # Настройка config.toml
    sed -i 's|^rpc_laddr *=.*|rpc_laddr = "tcp://0.0.0.0:26657"|' "$CONFIG_TOML"
    read -p "Введите external_address (например, 192.168.1.10): " EXTERNAL_ADDR
    if [ -z "$EXTERNAL_ADDR" ]; then
        echo "external_address не может быть пустым!"
        pause
        return
    fi
    sed -i "s|^external_address *=.*|external_address = \"$EXTERNAL_ADDR:26656\"|" "$CONFIG_TOML"

    # Настройка app.toml
    # [api]
    sed -i '/\[api\]/,/^\[/ s|^enable *=.*|enable = true|' "$APP_TOML"
    sed -i '/\[api\]/,/^\[/ s|^swagger *=.*|swagger = true|' "$APP_TOML"
    sed -i '/\[api\]/,/^\[/ s|^address *=.*|address = "tcp://0.0.0.0:1317"|' "$APP_TOML"
    sed -i '/\[api\]/,/^\[/ s|^max_open_connections *=.*|max_open_connections = 500|' "$APP_TOML"
    sed -i '/\[api\]/,/^\[/ s|^rpc_write_timeout *=.*|rpc_write_timeout = 15|' "$APP_TOML"
    sed -i '/\[api\]/,/^\[/ s|^enabled_unsafe_cors *=.*|enabled_unsafe_cors = true|' "$APP_TOML"
    # [grpc]
    sed -i '/\[grpc\]/,/^\[/ s|^address *=.*|address = "0.0.0.0:9090"|' "$APP_TOML"
    # [state_sync]
    sed -i '/\[state_sync\]/,/^\[/ s|^snapshot_interval *=.*|snapshot_interval = 1000|' "$APP_TOML"
    # [wasm]
    sed -i '/\[wasm\]/,/^\[/ s|^enable *=.*|enable = true|' "$APP_TOML"
    sed -i '/\[wasm\]/,/^\[/ s|^wasm_cache_size *=.*|wasm_cache_size = 200|' "$APP_TOML"
    sed -i '/\[wasm\]/,/^\[/ s|^memory_cache_size *=.*|memory_cache_size = 100|' "$APP_TOML"
    sed -i '/\[wasm\]/,/^\[/ s|^query_gas_limit *=.*|query_gas_limit = 3000000|' "$APP_TOML"
    sed -i '/\[wasm\]/,/^\[/ s|^max_contract_size *=.*|max_contract_size = 2000000|' "$APP_TOML"
    sed -i '/\[wasm\]/,/^\[/ s|^max_contract_gas *=.*|max_contract_gas = 3000000|' "$APP_TOML"
    sed -i '/\[wasm\]/,/^\[/ s|^max_contract_msg_size *=.*|max_contract_msg_size = 1048576|' "$APP_TOML"
    sed -i '/\[wasm\]/,/^\[/ s|^simulation_gas_limit *=.*|simulation_gas_limit = 3000000|' "$APP_TOML"
    # minimum-gas-prices (глобальный параметр)
    sed -i 's|^[[:space:]]*minimum-gas-prices *=.*|minimum-gas-prices = "0.025ufzp"|' "$APP_TOML"

    echo "Конфигурация wasmd успешно обновлена!"
    pause
}

function add_validator_key() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    wasmd keys add validator && echo "Ключ валидатора успешно создан!" || { echo "Ошибка при создании ключа валидатора!"; cd ..; pause; return; }
    cd ..
    pause
}

function add_wallet() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    read -p "Введите имя для кошелька: " WALLET_NAME
    wasmd keys add "$WALLET_NAME" && echo "Кошелек '$WALLET_NAME' успешно создан!" || { echo "Ошибка при создании кошелька!"; cd ..; pause; return; }
    cd ..
    pause
}

function add_genesis_account() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    read -p "Введите имя кошелька для добавления в генезис: " WALLET_NAME
    read -p "Введите количество монет для добавления: " AMOUNT
    wasmd genesis add-genesis-account "$(wasmd keys show "$WALLET_NAME" -a)" "${AMOUNT}ufzp" && echo "Генезис-аккаунт для '$WALLET_NAME' успешно добавлен с ${AMOUNT}ufzp!" || { echo "Ошибка при добавлении генезис-аккаунта!"; cd ..; pause; return; }
    cd ..
    pause
}

function create_and_collect_gentx() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    read -p "Введите количество для gentx: " AMOUNT
    read -p "Введите chain-id: " CHAIN_ID
    wasmd genesis gentx validator "${AMOUNT}ufzp" --chain-id "$CHAIN_ID" && echo "gentx успешно создан!" || { echo "Ошибка при создании gentx!"; cd ..; pause; return; }
    wasmd genesis collect-gentxs && echo "gentxs успешно собраны!" || { echo "Ошибка при сборе gentxs!"; cd ..; pause; return; }
    echo
    echo "ID вашей ноды:" 
    wasmd tendermint show-node-id
    cd ..
    pause
}

function start_wasmd_node() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    wasmd start && echo "Нода wasmd успешно запущена!" || { echo "Ошибка при запуске ноды!"; cd ..; pause; return; }
    cd ..
    pause
}

function set_bech32_prefix() {
    if [ ! -f "wasmd/Makefile" ]; then
        echo "Makefile не найден в папке wasmd!"
        read -p 'Нажмите Enter, чтобы вернуться в меню...'
        return
    fi
    read -p "Введите желаемый Bech32-префикс (например, myprefix): " new_prefix
    if [ -z "$new_prefix" ]; then
        echo "Префикс не может быть пустым!"
        read -p 'Нажмите Enter, чтобы вернуться в меню...'
        return
    fi
    # Замена строки с Bech32Prefix в Makefile (используем # как разделитель)
    sed -i "s#-X github.com/CosmWasm/wasmd/app.Bech32Prefix=[^ ]* #-X github.com/CosmWasm/wasmd/app.Bech32Prefix=${new_prefix} #" wasmd/Makefile
    if [ $? -eq 0 ]; then
        echo "✅ Bech32-префикс успешно изменён на '${new_prefix}'!"
    else
        echo "❌ Ошибка при изменении префикса!"
    fi
    read -p 'Нажмите Enter, чтобы вернуться в меню...'
}

function show_node_id() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    echo
    echo "ID вашей ноды:" 
    wasmd tendermint show-node-id
    cd ..
    pause
}

function create_systemd_service() {
    SERVICE_FILE="/etc/systemd/system/wasmd.service"
    USER=$(whoami)
    WASMD_PATH="$(which wasmd)"
    if [ -z "$WASMD_PATH" ]; then
        echo "wasmd не найден в PATH!"
        pause
        return
    fi
    sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=wasmd node service
After=network-online.target

[Service]
User=$USER
ExecStart=$WASMD_PATH start
Restart=always
RestartSec=3
LimitNOFILE=4096
WorkingDirectory=$HOME/.wasmd

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable wasmd
    echo "Системный сервис wasmd создан и добавлен в автозагрузку!"
    pause
}

function start_systemd_service() {
    sudo systemctl start wasmd
    sudo systemctl status wasmd --no-pager
    pause
}

function generate_persistent_peers() {
    read -p "Введите внешний IP ноды: " PEER_IP
    if [ -z "$PEER_IP" ]; then
        echo "IP не может быть пустым!"
        pause
        return
    fi
    read -p "Введите node ID: " PEER_ID
    if [ -z "$PEER_ID" ]; then
        echo "ID не может быть пустым!"
        pause
        return
    fi
    PEER_STRING="${PEER_ID}@${PEER_IP}:26656"
    echo
    echo "Сформированная строка persistent_peers:"
    echo "$PEER_STRING"
    BACKUP_FILE="persistent_peers_backup.txt"
    echo "$PEER_STRING" > "$BACKUP_FILE"
    echo "Строка сохранена в файл $BACKUP_FILE (рядом со скриптом)"
    pause
}

function copy_genesis_to_node() {
    GENESIS_FILE="$HOME/.wasmd/config/genesis.json"
    read -p "Введите IP-адрес целевой ноды: " TARGET_IP
    if [ -z "$TARGET_IP" ]; then
        echo "IP не может быть пустым!"
        pause
        return
    fi
    read -p "Введите имя пользователя на целевой ноде (по умолчанию root): " TARGET_USER
    TARGET_USER=${TARGET_USER:-root}
    echo "Сейчас потребуется ввести пароль для $TARGET_USER@$TARGET_IP"
    scp "$GENESIS_FILE" "$TARGET_USER@$TARGET_IP:/root/.wasmd/config/genesis.json"
    if [ $? -eq 0 ]; then
        echo "Файл genesis.json успешно скопирован на $TARGET_IP:/root/.wasmd/config/"
    else
        echo "Ошибка при копировании файла!"
    fi
    pause
}

function send_tokens() {
    read -p "Введите адрес отправителя (master_address): " MASTER_ADDR
    if [ -z "$MASTER_ADDR" ]; then
        echo "Адрес отправителя не может быть пустым!"
        pause
        return
    fi
    read -p "Введите адрес получателя (validator2_address): " VALIDATOR2_ADDR
    if [ -z "$VALIDATOR2_ADDR" ]; then
        echo "Адрес получателя не может быть пустым!"
        pause
        return
    fi
    read -p "Введите сумму для отправки (например, 100000000ufzp): " AMOUNT
    if [ -z "$AMOUNT" ]; then
        echo "Сумма не может быть пустой!"
        pause
        return
    fi
    read -p "Введите chain-id (по умолчанию fzp-chain): " CHAIN_ID
    CHAIN_ID=${CHAIN_ID:-fzp-chain}
    wasmd tx bank send "$MASTER_ADDR" "$VALIDATOR2_ADDR" "$AMOUNT" --chain-id "$CHAIN_ID" --keyring-backend test --node tcp://localhost:26657
    pause
}

while true; do
    clear
    echo "===== Мастер-нода wasmd: меню установки ====="
    echo "1. Клонировать репозиторий блокчейна"
    echo "2. Установить зависимости для сборки"
    echo "3. Установить Bech32-префикс"
    echo "4. Собрать и установить wasmd"
    echo "5. Инициализировать узел wasmd"
    echo "6. Настроить конфигурацию wasmd"
    echo "7. Создать ключ валидатора"
    echo "8. Добавить генезис-аккаунт"
    echo "9. Создать и собрать gentx"
    echo "10. Показать ID ноды"
    echo "11. Создать systemd-сервис и добавить в автозагрузку"
    echo "12. Запустить wasmd через systemd (в фоне)"
    echo "13. Запустить ноду wasmd (foreground)"
    echo "14. Создать persistent_peers строку и сохранить в файл"
    echo "15. Копировать genesis.json на другую ноду"
    echo "16. Отправить монеты (tx bank send)"
    echo "17. Создать кошелек"
    echo "18. Выйти"
    echo -n "Выберите пункт меню: "
    read choice
    case $choice in
        1) clone_repo ;;
        2) install_deps ;;
        3) set_bech32_prefix ;;
        4) build_wasmd ;;
        5) init_wasmd ;;
        6) configure_wasmd ;;
        7) add_validator_key ;;
        8) add_genesis_account ;;
        9) create_and_collect_gentx ;;
        10) show_node_id ;;
        11) create_systemd_service ;;
        12) start_systemd_service ;;
        13) start_wasmd_node ;;
        14) generate_persistent_peers ;;
        15) copy_genesis_to_node ;;
        16) send_tokens ;;
        17) add_wallet ;;
        18) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор!"; pause ;;
    esac
done 
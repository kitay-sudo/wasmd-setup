#!/bin/bash
set -e

# Загрузка переменных окружения из .env, если есть
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Список обязательных переменных
REQUIRED_VARS=(
  STAKE CHAIN_ID MONIKER EXTERNAL_ADDR TOKEN_DENOM
  MIN_SELF_DELEGATION COMMISSION_RATE COMMISSION_MAX_RATE COMMISSION_MAX_CHANGE_RATE
  P2P_PORT RPC_PORT API_PORT GRPC_PORT
  MIN_DEPOSIT_AMOUNT EXPEDITED_MIN_DEPOSIT_AMOUNT CONSTANT_FEE_AMOUNT MAX_VALIDATORS
  UNBONDING_TIME INFLATION ANNUAL_PROVISIONS INFLATION_RATE_CHANGE INFLATION_MAX INFLATION_MIN
  GOAL_BONDED BLOCKS_PER_YEAR COMMUNITY_TAX BASE_PROPOSER_REWARD BONUS_PROPOSER_REWARD
  WITHDRAW_ADDR_ENABLED SLASH_FRACTION_DOUBLE_SIGN SLASH_FRACTION_DOWNTIME DOWNTIME_JAIL_DURATION
  SIGNED_BLOCKS_WINDOW MIN_SIGNED_PER_WINDOW MINIMUM_GAS_PRICE SEND_AMOUNT GENTX_AMOUNT
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    MISSING_VARS+=("$var")
  fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
  echo "Ошибка: Не заданы обязательные параметры в .env:"
  for var in "${MISSING_VARS[@]}"; do
    echo "  - $var"
  done
  echo "Пожалуйста, добавьте эти параметры в .env и перезапустите скрипт."
  exit 1
fi

# Проверка и запрос всех переменных, если не заданы в .env
if [ -z "$STAKE" ]; then read -p "Введите STAKE (деноминация монеты): " STAKE; fi
if [ -z "$CHAIN_ID" ]; then read -p "Введите chain-id: " CHAIN_ID; fi
if [ -z "$MONIKER" ]; then read -p "Введите MONIKER (имя ноды): " MONIKER; fi
if [ -z "$EXTERNAL_ADDR" ]; then read -p "Введите EXTERNAL_ADDR (внешний IP): " EXTERNAL_ADDR; fi
if [ -z "$TOKEN_DENOM" ]; then read -p "Введите TOKEN_DENOM: " TOKEN_DENOM; fi
if [ -z "$MIN_SELF_DELEGATION" ]; then read -p "Введите MIN_SELF_DELEGATION: " MIN_SELF_DELEGATION; fi
if [ -z "$COMMISSION_RATE" ]; then read -p "Введите COMMISSION_RATE: " COMMISSION_RATE; fi
if [ -z "$COMMISSION_MAX_RATE" ]; then read -p "Введите COMMISSION_MAX_RATE: " COMMISSION_MAX_RATE; fi
if [ -z "$COMMISSION_MAX_CHANGE_RATE" ]; then read -p "Введите COMMISSION_MAX_CHANGE_RATE: " COMMISSION_MAX_CHANGE_RATE; fi
if [ -z "$P2P_PORT" ]; then read -p "Введите P2P_PORT: " P2P_PORT; fi
if [ -z "$RPC_PORT" ]; then read -p "Введите RPC_PORT: " RPC_PORT; fi
if [ -z "$API_PORT" ]; then read -p "Введите API_PORT: " API_PORT; fi
if [ -z "$GRPC_PORT" ]; then read -p "Введите GRPC_PORT: " GRPC_PORT; fi
if [ -z "$MIN_DEPOSIT_AMOUNT" ]; then read -p "Введите MIN_DEPOSIT_AMOUNT: " MIN_DEPOSIT_AMOUNT; fi
if [ -z "$EXPEDITED_MIN_DEPOSIT_AMOUNT" ]; then read -p "Введите EXPEDITED_MIN_DEPOSIT_AMOUNT: " EXPEDITED_MIN_DEPOSIT_AMOUNT; fi
if [ -z "$CONSTANT_FEE_AMOUNT" ]; then read -p "Введите CONSTANT_FEE_AMOUNT: " CONSTANT_FEE_AMOUNT; fi
if [ -z "$MAX_VALIDATORS" ]; then read -p "Введите MAX_VALIDATORS: " MAX_VALIDATORS; fi
if [ -z "$UNBONDING_TIME" ]; then read -p "Введите UNBONDING_TIME: " UNBONDING_TIME; fi
if [ -z "$INFLATION" ]; then read -p "Введите INFLATION: " INFLATION; fi
if [ -z "$ANNUAL_PROVISIONS" ]; then read -p "Введите ANNUAL_PROVISIONS: " ANNUAL_PROVISIONS; fi
if [ -z "$INFLATION_RATE_CHANGE" ]; then read -p "Введите INFLATION_RATE_CHANGE: " INFLATION_RATE_CHANGE; fi
if [ -z "$INFLATION_MAX" ]; then read -p "Введите INFLATION_MAX: " INFLATION_MAX; fi
if [ -z "$INFLATION_MIN" ]; then read -p "Введите INFLATION_MIN: " INFLATION_MIN; fi
if [ -z "$GOAL_BONDED" ]; then read -p "Введите GOAL_BONDED: " GOAL_BONDED; fi
if [ -z "$BLOCKS_PER_YEAR" ]; then read -p "Введите BLOCKS_PER_YEAR: " BLOCKS_PER_YEAR; fi
if [ -z "$COMMUNITY_TAX" ]; then read -p "Введите COMMUNITY_TAX: " COMMUNITY_TAX; fi
if [ -z "$BASE_PROPOSER_REWARD" ]; then read -p "Введите BASE_PROPOSER_REWARD: " BASE_PROPOSER_REWARD; fi
if [ -z "$BONUS_PROPOSER_REWARD" ]; then read -p "Введите BONUS_PROPOSER_REWARD: " BONUS_PROPOSER_REWARD; fi
if [ -z "$WITHDRAW_ADDR_ENABLED" ]; then read -p "Введите WITHDRAW_ADDR_ENABLED: " WITHDRAW_ADDR_ENABLED; fi
if [ -z "$SLASH_FRACTION_DOUBLE_SIGN" ]; then read -p "Введите SLASH_FRACTION_DOUBLE_SIGN: " SLASH_FRACTION_DOUBLE_SIGN; fi
if [ -z "$SLASH_FRACTION_DOWNTIME" ]; then read -p "Введите SLASH_FRACTION_DOWNTIME: " SLASH_FRACTION_DOWNTIME; fi
if [ -z "$DOWNTIME_JAIL_DURATION" ]; then read -p "Введите DOWNTIME_JAIL_DURATION: " DOWNTIME_JAIL_DURATION; fi
if [ -z "$SIGNED_BLOCKS_WINDOW" ]; then read -p "Введите SIGNED_BLOCKS_WINDOW: " SIGNED_BLOCKS_WINDOW; fi
if [ -z "$MIN_SIGNED_PER_WINDOW" ]; then read -p "Введите MIN_SIGNED_PER_WINDOW: " MIN_SIGNED_PER_WINDOW; fi
if [ -z "$MINIMUM_GAS_PRICE" ]; then read -p "Введите MINIMUM_GAS_PRICE: " MINIMUM_GAS_PRICE; fi
if [ -z "$SEND_AMOUNT" ]; then read -p "Введите SEND_AMOUNT: " SEND_AMOUNT; fi
if [ -z "$GENTX_AMOUNT" ]; then read -p "Введите GENTX_AMOUNT: " GENTX_AMOUNT; fi

clear

echo "Установка wasmd: выберите роль"
echo "1. Мастер-нода (создание сети)"
echo "2. Валидатор (подключение к сети)"
echo -n "Ваш выбор: "
read NODE_TYPE

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
    wasmd init "$MONIKER" --chain-id "$CHAIN_ID" && echo "Узел wasmd успешно инициализирован!" || { echo "Ошибка при инициализации узла!"; cd ..; pause; return; }
    cd ..
    pause
}

function configure_wasmd() {
    GENESIS="/root/.wasmd/config/genesis.json"
    CONFIG_TOML="/root/.wasmd/config/config.toml"
    APP_TOML="/root/.wasmd/config/app.toml"

    # Обновляем genesis.json через jq
    jq \
      --arg stake "$STAKE" \
      --arg constant_fee "$CONSTANT_FEE_AMOUNT" \
      --arg min_deposit "$MIN_DEPOSIT_AMOUNT" \
      --arg expedited_min_deposit "$EXPEDITED_MIN_DEPOSIT_AMOUNT" \
      '.app_state.crisis.constant_fee.denom = $stake
       | .app_state.crisis.constant_fee.amount = $constant_fee
       | .app_state.gov.deposit_params.min_deposit[0].denom = $stake
       | .app_state.gov.deposit_params.min_deposit[0].amount = $min_deposit
       | .app_state.gov.params.min_deposit[0].denom = $stake
       | .app_state.gov.params.min_deposit[0].amount = $min_deposit
       | .app_state.gov.params.expedited_min_deposit[0].denom = $stake
       | .app_state.gov.params.expedited_min_deposit[0].amount = $expedited_min_deposit
       | .app_state.mint.params.mint_denom = $stake
       | .app_state.staking.params.bond_denom = $stake
      ' "$GENESIS" > tmp_genesis.json && mv tmp_genesis.json "$GENESIS"

    # Изменяем chain_id, если нужно
    read -p "Введите chain-id (Enter чтобы пропустить): " CHAIN_ID
    if [ ! -z "$CHAIN_ID" ]; then
        jq --arg chain_id "$CHAIN_ID" '.chain_id = $chain_id' "$GENESIS" > tmp_genesis.json && mv tmp_genesis.json "$GENESIS"
    fi

    # Изменяем другие параметры через sed (если нужно)
    sed -i "s/\"max_validators\": [0-9]*/\"max_validators\": $MAX_VALIDATORS/" "$GENESIS"
    sed -i "s/\"unbonding_time\": \".*\"/\"unbonding_time\": \"$UNBONDING_TIME\"/" "$GENESIS"
    sed -i "s/\"inflation\": \".*\"/\"inflation\": \"$INFLATION\"/" "$GENESIS"
    sed -i "s/\"annual_provisions\": \".*\"/\"annual_provisions\": \"$ANNUAL_PROVISIONS\"/" "$GENESIS"
    sed -i "s/\"inflation_rate_change\": \".*\"/\"inflation_rate_change\": \"$INFLATION_RATE_CHANGE\"/" "$GENESIS"
    sed -i "s/\"inflation_max\": \".*\"/\"inflation_max\": \"$INFLATION_MAX\"/" "$GENESIS"
    sed -i "s/\"inflation_min\": \".*\"/\"inflation_min\": \"$INFLATION_MIN\"/" "$GENESIS"
    sed -i "s/\"goal_bonded\": \".*\"/\"goal_bonded\": \"$GOAL_BONDED\"/" "$GENESIS"
    sed -i "s/\"blocks_per_year\": \".*\"/\"blocks_per_year\": \"$BLOCKS_PER_YEAR\"/" "$GENESIS"
    sed -i "s/\"community_tax\": \".*\"/\"community_tax\": \"$COMMUNITY_TAX\"/" "$GENESIS"
    sed -i "s/\"base_proposer_reward\": \".*\"/\"base_proposer_reward\": \"$BASE_PROPOSER_REWARD\"/" "$GENESIS"
    sed -i "s/\"bonus_proposer_reward\": \".*\"/\"bonus_proposer_reward\": \"$BONUS_PROPOSER_REWARD\"/" "$GENESIS"
    sed -i "s/\"withdraw_addr_enabled\": [a-z]*/\"withdraw_addr_enabled\": $WITHDRAW_ADDR_ENABLED/" "$GENESIS"
    sed -i "s/\"slash_fraction_double_sign\": \".*\"/\"slash_fraction_double_sign\": \"$SLASH_FRACTION_DOUBLE_SIGN\"/" "$GENESIS"
    sed -i "s/\"slash_fraction_downtime\": \".*\"/\"slash_fraction_downtime\": \"$SLASH_FRACTION_DOWNTIME\"/" "$GENESIS"
    sed -i "s/\"downtime_jail_duration\": \".*\"/\"downtime_jail_duration\": \"$DOWNTIME_JAIL_DURATION\"/" "$GENESIS"
    sed -i "s/\"signed_blocks_window\": \".*\"/\"signed_blocks_window\": \"$SIGNED_BLOCKS_WINDOW\"/" "$GENESIS"
    sed -i "s/\"min_signed_per_window\": \".*\"/\"min_signed_per_window\": \"$MIN_SIGNED_PER_WINDOW\"/" "$GENESIS"

    # Настройка config.toml
    sed -i "s|^rpc_laddr *=.*|rpc_laddr = \"$RPC_LADDR\"|" "$CONFIG_TOML"
    sed -i "s|^external_address *=.*|external_address = \"$EXTERNAL_ADDR:$P2P_PORT\"|" "$CONFIG_TOML"

    # Настройка app.toml
    # [api]
    sed -i "/\\[api\\]/,/^\\[/ s|^address *=.*|address = \"$API_ADDRESS\"|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^enable *=.*|enable = $API_ENABLE|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^swagger *=.*|swagger = $API_SWAGGER|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^max_open_connections *=.*|max_open_connections = $API_MAX_OPEN_CONNECTIONS|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^rpc_write_timeout *=.*|rpc_write_timeout = $API_RPC_WRITE_TIMEOUT|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^enabled_unsafe_cors *=.*|enabled_unsafe_cors = $API_ENABLED_UNSAFE_CORS|" "$APP_TOML"
    # [grpc]
    sed -i "/\\[grpc\\]/,/^\\[/ s|^address *=.*|address = \"$GRPC_ADDRESS\"|" "$APP_TOML"
    sed -i "/\\[grpc\\]/,/^\\[/ s|^enable *=.*|enable = $GRPC_ENABLE|" "$APP_TOML"
    # [state_sync]
    sed -i "/\\[state_sync\\]/,/^\\[/ s|^snapshot_interval *=.*|snapshot_interval = $STATE_SYNC_SNAPSHOT_INTERVAL|" "$APP_TOML"
    # [wasm]
    sed -i "/\\[wasm\\]/,/^\\[/ s|^enable *=.*|enable = $WASM_ENABLE|" "$APP_TOML"
    sed -i "/\\[wasm\\]/,/^\\[/ s|^wasm_cache_size *=.*|wasm_cache_size = $WASM_CACHE_SIZE|" "$APP_TOML"
    sed -i "/\\[wasm\\]/,/^\\[/ s|^memory_cache_size *=.*|memory_cache_size = $WASM_MEMORY_CACHE_SIZE|" "$APP_TOML"
    sed -i "/\\[wasm\\]/,/^\\[/ s|^query_gas_limit *=.*|query_gas_limit = $WASM_QUERY_GAS_LIMIT|" "$APP_TOML"
    sed -i "/\\[wasm\\]/,/^\\[/ s|^max_contract_size *=.*|max_contract_size = $WASM_MAX_CONTRACT_SIZE|" "$APP_TOML"
    sed -i "/\\[wasm\\]/,/^\\[/ s|^max_contract_gas *=.*|max_contract_gas = $WASM_MAX_CONTRACT_GAS|" "$APP_TOML"
    sed -i "/\\[wasm\\]/,/^\\[/ s|^max_contract_msg_size *=.*|max_contract_msg_size = $WASM_MAX_CONTRACT_MSG_SIZE|" "$APP_TOML"
    sed -i "/\\[wasm\\]/,/^\\[/ s|^simulation_gas_limit *=.*|simulation_gas_limit = $WASM_SIMULATION_GAS_LIMIT|" "$APP_TOML"
    # minimum-gas-prices (глобальный параметр)
    sed -i "s|^[[:space:]]*minimum-gas-prices *=.*|minimum-gas-prices = \"$MINIMUM_GAS_PRICE$STAKE\"|" "$APP_TOML"

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
    read -p "Введите имя для ключа валидатора: " VALIDATOR_WALLET_NAME
    wasmd keys add "$VALIDATOR_WALLET_NAME" && echo "Ключ валидатора '$VALIDATOR_WALLET_NAME' успешно создан!" || { echo "Ошибка при создании ключа валидатора!"; cd ..; pause; return; }
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
    read -p "Введите имя ключа валидатора для gentx: " VALIDATOR_WALLET_NAME
    read -p "Введите количество для gentx: " AMOUNT
    read -p "Введите chain-id: " CHAIN_ID
    wasmd genesis gentx "$VALIDATOR_WALLET_NAME" "${AMOUNT}ufzp" --chain-id "$CHAIN_ID" && echo "gentx успешно создан!" || { echo "Ошибка при создании gentx!"; cd ..; pause; return; }
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

function create_validator_from_file() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    wasmd keys add validator --from-file validator.json && echo "Валидатор успешно создан!" || { echo "Ошибка при создании валидатора!"; cd ..; pause; return; }
    cd ..
    pause
}

function helper_menu() {
    while true; do
        clear
        echo "Утилиты/дополнительные действия"
        echo "1. Создать systemd-сервис и добавить в автозагрузку"
        echo "2. Запустить ноду wasmd (foreground)"
        echo "3. Создать persistent_peers строку и сохранить в файл"
        echo "4. Отправить монеты (tx bank send)"
        echo "5. Создать валидатора через файл (validator.json)"
        echo "6. Создать кошелек"
        echo "7. Вернуться в главное меню"
        echo -n "Выберите пункт меню: "
        read helper_choice
        case $helper_choice in
            1) create_systemd_service ;;
            2) start_wasmd_node ;;
            3) generate_persistent_peers ;;
            4) send_tokens ;;
            5) create_validator_from_file ;;
            6) add_wallet ;;
            7) break ;;
            *) echo "Неверный выбор!"; pause ;;
        esac
    done
}

if [ "$NODE_TYPE" = "1" ]; then
    # Мастер-нода: только нужные пункты
    while true; do
        clear
        echo "Мастер-нода wasmd: меню установки"
        echo "1. Клонировать репозиторий блокчейна"
        echo "2. Установить зависимости для сборки"
        echo "3. Установить Bech32-префикс"
        echo "4. Собрать и установить wasmd"
        echo "5. Инициализировать узел wasmd"
        echo "6. Настроить конфигурацию wasmd"
        echo "7. Создать ключ валидатора"
        echo "8. Добавить аккаунт в генезис"
        echo "9. Создать и собрать gentx"
        echo "10. Показать ID ноды"
        echo "11. Копировать genesis.json на другую ноду"
        echo "12. Утилиты/дополнительные действия"
        echo "13. Выйти"
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
            11) copy_genesis_to_node ;;
            12) helper_menu ;;
            13) echo "Выход."; exit 0 ;;
            *) echo "Неверный выбор!"; pause ;;
        esac
    done
elif [ "$NODE_TYPE" = "2" ]; then
    # Валидатор: только нужные пункты
    while true; do
        clear
        echo "Валидатор wasmd: меню установки"
        echo "1. Клонировать репозиторий блокчейна"
        echo "2. Установить зависимости для сборки"
        echo "3. Установить Bech32-префикс"
        echo "4. Собрать и установить wasmd"
        echo "5. Инициализировать узел wasmd"
        echo "6. Настроить конфигурацию wasmd"
        echo "7. Создать persistent_peers строку и сохранить в файл"
        echo "8. Копировать genesis.json с мастер-ноды"
        echo "9. Создать кошелек"
        echo "10. Отправить монеты (tx bank send)"
        echo "11. Создать валидатора через файл (validator.json)"
        echo "12. Показать ID ноды"
        echo "13. Создать systemd-сервис и добавить в автозагрузку"
        echo "14. Запустить wasmd через systemd (в фоне)"
        echo "15. Запустить ноду wasmd (foreground)"
        echo "16. Утилиты/дополнительные действия"
        echo "17. Выйти"
        echo -n "Выберите пункт меню: "
        read choice
        case $choice in
            1) clone_repo ;;
            2) install_deps ;;
            3) set_bech32_prefix ;;
            4) build_wasmd ;;
            5) init_wasmd ;;
            6) configure_wasmd ;;
            7) generate_persistent_peers ;;
            8) copy_genesis_to_node ;;
            9) add_wallet ;;
            10) send_tokens ;;
            11) create_validator_from_file ;;
            12) show_node_id ;;
            13) create_systemd_service ;;
            14) start_systemd_service ;;
            15) start_wasmd_node ;;
            16) helper_menu ;;
            17) echo "Выход."; exit 0 ;;
            *) echo "Неверный выбор!"; pause ;;
        esac
    done
else
    echo "Неверный выбор! Перезапустите скрипт."
    exit 1
fi 
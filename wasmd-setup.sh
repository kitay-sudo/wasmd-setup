#!/bin/bash
set -e

# Функция для очистки строк от недопустимых символов
sanitize_input() {
    local input="$1"
    local input_type="$2"
    
    if [ "$input_type" = "number" ]; then
        # Для числовых значений оставляем только цифры
        echo "$input" | tr -cd '0-9'
    else
        # Для обычного текста удаляем недопустимые символы
        echo "$input" | tr -cd '[:print:][:cntrl:]' | tr -d '\r\n' | LC_ALL=C tr -dc 'a-zA-Z0-9-_/:.'
    fi
}

# Функция для обеспечения валидного bech32-строк
validate_bech32_string() {
    local input="$1"
    # Оставляем только допустимые символы для bech32 (a-z0-9)
    echo "$input" | tr -cd 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]'
}

# Загрузка переменных окружения из .env, если есть
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Список обязательных переменных
REQUIRED_VARS=(
  # Основные параметры сети
  STAKE CHAIN_ID MONIKER EXTERNAL_ADDR TOKEN_DENOM
  
  # Параметры валидатора - влияют на комиссии и минимальные делегирования
  MIN_SELF_DELEGATION COMMISSION_RATE COMMISSION_MAX_RATE COMMISSION_MAX_CHANGE_RATE
  
  # Порты для различных сервисов блокчейна
  P2P_PORT RPC_PORT API_PORT GRPC_PORT
  
  # Параметры управления (governance) и экономики сети
  MIN_DEPOSIT_AMOUNT EXPEDITED_MIN_DEPOSIT_AMOUNT CONSTANT_FEE_AMOUNT MAX_VALIDATORS
  UNBONDING_TIME INFLATION ANNUAL_PROVISIONS INFLATION_RATE_CHANGE INFLATION_MAX INFLATION_MIN
  GOAL_BONDED BLOCKS_PER_YEAR COMMUNITY_TAX BASE_PROPOSER_REWARD BONUS_PROPOSER_REWARD
  WITHDRAW_ADDR_ENABLED 
  
  # Параметры слэшинга (штрафов) и безопасности сети
  SLASH_FRACTION_DOUBLE_SIGN SLASH_FRACTION_DOWNTIME DOWNTIME_JAIL_DURATION
  SIGNED_BLOCKS_WINDOW MIN_SIGNED_PER_WINDOW 
  
  # Прочие параметры
  MINIMUM_GAS_PRICES SEND_AMOUNT GENTX_AMOUNT
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
# Основные параметры
if [ -z "$STAKE" ]; then read -p "Введите STAKE (деноминация монеты): " STAKE; fi
if [ -z "$CHAIN_ID" ]; then read -p "Введите chain-id: " CHAIN_ID; fi
if [ -z "$MONIKER" ]; then read -p "Введите MONIKER (имя ноды): " MONIKER; fi
if [ -z "$EXTERNAL_ADDR" ]; then read -p "Введите EXTERNAL_ADDR (внешний IP): " EXTERNAL_ADDR; fi
if [ -z "$TOKEN_DENOM" ]; then read -p "Введите TOKEN_DENOM: " TOKEN_DENOM; fi

# Параметры валидатора
if [ -z "$MIN_SELF_DELEGATION" ]; then read -p "Введите MIN_SELF_DELEGATION: " MIN_SELF_DELEGATION; fi
if [ -z "$COMMISSION_RATE" ]; then read -p "Введите COMMISSION_RATE: " COMMISSION_RATE; fi
if [ -z "$COMMISSION_MAX_RATE" ]; then read -p "Введите COMMISSION_MAX_RATE: " COMMISSION_MAX_RATE; fi
if [ -z "$COMMISSION_MAX_CHANGE_RATE" ]; then read -p "Введите COMMISSION_MAX_CHANGE_RATE: " COMMISSION_MAX_CHANGE_RATE; fi

# Порты
if [ -z "$P2P_PORT" ]; then read -p "Введите P2P_PORT: " P2P_PORT; fi
if [ -z "$RPC_PORT" ]; then read -p "Введите RPC_PORT: " RPC_PORT; fi
if [ -z "$API_PORT" ]; then read -p "Введите API_PORT: " API_PORT; fi
if [ -z "$GRPC_PORT" ]; then read -p "Введите GRPC_PORT: " GRPC_PORT; fi

# Параметры governance и экономики
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

# Параметры слэшинга и безопасности
if [ -z "$SLASH_FRACTION_DOUBLE_SIGN" ]; then read -p "Введите SLASH_FRACTION_DOUBLE_SIGN: " SLASH_FRACTION_DOUBLE_SIGN; fi
if [ -z "$SLASH_FRACTION_DOWNTIME" ]; then read -p "Введите SLASH_FRACTION_DOWNTIME: " SLASH_FRACTION_DOWNTIME; fi
if [ -z "$DOWNTIME_JAIL_DURATION" ]; then read -p "Введите DOWNTIME_JAIL_DURATION: " DOWNTIME_JAIL_DURATION; fi
if [ -z "$SIGNED_BLOCKS_WINDOW" ]; then read -p "Введите SIGNED_BLOCKS_WINDOW: " SIGNED_BLOCKS_WINDOW; fi
if [ -z "$MIN_SIGNED_PER_WINDOW" ]; then read -p "Введите MIN_SIGNED_PER_WINDOW: " MIN_SIGNED_PER_WINDOW; fi

# Прочие параметры
if [ -z "$MINIMUM_GAS_PRICES" ]; then read -p "Введите MINIMUM_GAS_PRICES: " MINIMUM_GAS_PRICES; fi
if [ -z "$SEND_AMOUNT" ]; then read -p "Введите SEND_AMOUNT: " SEND_AMOUNT; fi
if [ -z "$GENTX_AMOUNT" ]; then read -p "Введите GENTX_AMOUNT: " GENTX_AMOUNT; fi

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
    # Очищаем MONIKER и CHAIN_ID от символов новой строки и недопустимых символов
    MONIKER_CLEAN=$(sanitize_input "$MONIKER")
    CHAIN_ID_CLEAN=$(sanitize_input "$CHAIN_ID")
    
    echo "Инициализация узла с: MONIKER=$MONIKER_CLEAN, CHAIN_ID=$CHAIN_ID_CLEAN"
    wasmd init "$MONIKER_CLEAN" --chain-id "$CHAIN_ID_CLEAN" && echo "Узел wasmd успешно инициализирован!" || { echo "Ошибка при инициализации узла!"; cd ..; pause; return; }
    
    # Дополнительная очистка файлов конфигурации от символов переноса строки и других проблемных символов
    echo "Очистка конфигурационных файлов от проблемных символов..."
    
    # Обрабатываем все json и toml файлы
    find ~/.wasmd/config -type f -name "*.json" -o -name "*.toml" | while read file; do
        echo "Обрабатываем $file"
        TMP_FILE=$(mktemp)
        # Оставляем только допустимые ASCII символы
        tr -cd '\11\12\15\40-\176' < "$file" > "$TMP_FILE"
        mv "$TMP_FILE" "$file"
    done
    
    # Особая обработка genesis.json для исправления возможных проблем с bech32 адресами
    GENESIS_FILE=~/.wasmd/config/genesis.json
    if [ -f "$GENESIS_FILE" ]; then
        echo "Проверка и исправление bech32 адресов в genesis.json..."
        TMP_FILE=$(mktemp)
        
        # Специальная очистка адресов типа bech32
        # Сначала сохраняем только допустимые символы для JSON (без кириллицы и других специальных символов)
        LC_ALL=C tr -dc '\11\12\15\40-\176' < "$GENESIS_FILE" > "$TMP_FILE"
        
        # Проверяем, что файл не поврежден и является допустимым JSON после очистки
        if jq '.' "$TMP_FILE" >/dev/null 2>&1; then
            mv "$TMP_FILE" "$GENESIS_FILE"
            echo "Genesis файл успешно очищен."
        else
            echo "⚠️ Внимание: Ошибка при проверке genesis.json после очистки. Используем оригинальный файл."
            rm "$TMP_FILE"
        fi
        
        # Проверяем наличие недопустимых символов в адресах
        echo "Финальная проверка на допустимость символов в адресах..."
        if grep -P '[^\x00-\x7F]' "$GENESIS_FILE"; then
            echo "⚠️ Обнаружены недопустимые символы в $GENESIS_FILE!"
            echo "Попытка дополнительной очистки..."
            TMP_FILE=$(mktemp)
            # Еще одна итерация очистки только ASCII
            LC_ALL=C tr -cd '\11\12\15\40-\176' < "$GENESIS_FILE" > "$TMP_FILE"
            mv "$TMP_FILE" "$GENESIS_FILE"
        else
            echo "✅ Не обнаружено недопустимых символов в genesis.json"
        fi
    fi
    
    # Проверяем все критические файлы на наличие недопустимых символов
    for config_file in ~/.wasmd/config/app.toml ~/.wasmd/config/config.toml ~/.wasmd/config/client.toml; do
        if [ -f "$config_file" ]; then
            echo "Проверка $config_file на наличие недопустимых символов..."
            if grep -P '[^\x00-\x7F]' "$config_file"; then
                echo "⚠️ Обнаружены недопустимые символы в $config_file!"
                echo "Выполняем дополнительную очистку..."
                TMP_FILE=$(mktemp)
                LC_ALL=C tr -cd '\11\12\15\40-\176' < "$config_file" > "$TMP_FILE"
                mv "$TMP_FILE" "$config_file"
            else
                echo "✅ Не обнаружено недопустимых символов в $config_file"
            fi
        fi
    done
    
    echo "Очистка завершена. Все конфигурационные файлы проверены и очищены."
    cd ..
    pause
}

function configure_wasmd() {
    GENESIS="/root/.wasmd/config/genesis.json"
    CONFIG_TOML="/root/.wasmd/config/config.toml"
    APP_TOML="/root/.wasmd/config/app.toml"

    # Очищаем все переменные от символов переноса строки
    echo "Очищаем параметры от символов переноса строки..."
    STAKE_CLEAN=$(echo "$STAKE" | tr -d '\r\n')
    CONSTANT_FEE_AMOUNT_CLEAN=$(echo "$CONSTANT_FEE_AMOUNT" | tr -d '\r\n')
    MIN_DEPOSIT_AMOUNT_CLEAN=$(echo "$MIN_DEPOSIT_AMOUNT" | tr -d '\r\n')
    EXPEDITED_MIN_DEPOSIT_AMOUNT_CLEAN=$(echo "$EXPEDITED_MIN_DEPOSIT_AMOUNT" | tr -d '\r\n')
    MAX_VALIDATORS_CLEAN=$(echo "$MAX_VALIDATORS" | tr -d '\r\n')
    UNBONDING_TIME_CLEAN=$(echo "$UNBONDING_TIME" | tr -d '\r\n')
    INFLATION_CLEAN=$(echo "$INFLATION" | tr -d '\r\n')
    ANNUAL_PROVISIONS_CLEAN=$(echo "$ANNUAL_PROVISIONS" | tr -d '\r\n')
    INFLATION_RATE_CHANGE_CLEAN=$(echo "$INFLATION_RATE_CHANGE" | tr -d '\r\n')
    INFLATION_MAX_CLEAN=$(echo "$INFLATION_MAX" | tr -d '\r\n')
    INFLATION_MIN_CLEAN=$(echo "$INFLATION_MIN" | tr -d '\r\n')
    GOAL_BONDED_CLEAN=$(echo "$GOAL_BONDED" | tr -d '\r\n')
    BLOCKS_PER_YEAR_CLEAN=$(echo "$BLOCKS_PER_YEAR" | tr -d '\r\n')
    COMMUNITY_TAX_CLEAN=$(echo "$COMMUNITY_TAX" | tr -d '\r\n')
    BASE_PROPOSER_REWARD_CLEAN=$(echo "$BASE_PROPOSER_REWARD" | tr -d '\r\n')
    BONUS_PROPOSER_REWARD_CLEAN=$(echo "$BONUS_PROPOSER_REWARD" | tr -d '\r\n')
    WITHDRAW_ADDR_ENABLED_CLEAN=$(echo "$WITHDRAW_ADDR_ENABLED" | tr -d '\r\n')
    SLASH_FRACTION_DOUBLE_SIGN_CLEAN=$(echo "$SLASH_FRACTION_DOUBLE_SIGN" | tr -d '\r\n')
    SLASH_FRACTION_DOWNTIME_CLEAN=$(echo "$SLASH_FRACTION_DOWNTIME" | tr -d '\r\n')
    DOWNTIME_JAIL_DURATION_CLEAN=$(echo "$DOWNTIME_JAIL_DURATION" | tr -d '\r\n')
    SIGNED_BLOCKS_WINDOW_CLEAN=$(echo "$SIGNED_BLOCKS_WINDOW" | tr -d '\r\n')
    MIN_SIGNED_PER_WINDOW_CLEAN=$(echo "$MIN_SIGNED_PER_WINDOW" | tr -d '\r\n')

    # Обновляем genesis.json через jq с очищенными параметрами
    jq \
      --arg stake "$STAKE_CLEAN" \
      --arg constant_fee "$CONSTANT_FEE_AMOUNT_CLEAN" \
      --arg min_deposit "$MIN_DEPOSIT_AMOUNT_CLEAN" \
      --arg expedited_min_deposit "$EXPEDITED_MIN_DEPOSIT_AMOUNT_CLEAN" \
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
        CHAIN_ID_CLEAN=$(echo "$CHAIN_ID" | tr -d '\r\n')
        jq --arg chain_id "$CHAIN_ID_CLEAN" '.chain_id = $chain_id' "$GENESIS" > tmp_genesis.json && mv tmp_genesis.json "$GENESIS"
    fi

    # Изменяем другие параметры через sed (если нужно) с очищенными значениями
    # Основные параметры валидаторов и стейкинга
    sed -i "s/\"max_validators\": [0-9]*/\"max_validators\": $MAX_VALIDATORS_CLEAN/" "$GENESIS"
    sed -i "s/\"unbonding_time\": \".*\"/\"unbonding_time\": \"$UNBONDING_TIME_CLEAN\"/" "$GENESIS"
    
    # Параметры инфляции и экономики сети
    sed -i "s/\"inflation\": \".*\"/\"inflation\": \"$INFLATION_CLEAN\"/" "$GENESIS"
    sed -i "s/\"annual_provisions\": \".*\"/\"annual_provisions\": \"$ANNUAL_PROVISIONS_CLEAN\"/" "$GENESIS"
    sed -i "s/\"inflation_rate_change\": \".*\"/\"inflation_rate_change\": \"$INFLATION_RATE_CHANGE_CLEAN\"/" "$GENESIS"
    sed -i "s/\"inflation_max\": \".*\"/\"inflation_max\": \"$INFLATION_MAX_CLEAN\"/" "$GENESIS"
    sed -i "s/\"inflation_min\": \".*\"/\"inflation_min\": \"$INFLATION_MIN_CLEAN\"/" "$GENESIS"
    sed -i "s/\"goal_bonded\": \".*\"/\"goal_bonded\": \"$GOAL_BONDED_CLEAN\"/" "$GENESIS"
    sed -i "s/\"blocks_per_year\": \".*\"/\"blocks_per_year\": \"$BLOCKS_PER_YEAR_CLEAN\"/" "$GENESIS"
    
    # Параметры комиссий и наград
    sed -i "s/\"community_tax\": \".*\"/\"community_tax\": \"$COMMUNITY_TAX_CLEAN\"/" "$GENESIS"
    sed -i "s/\"base_proposer_reward\": \".*\"/\"base_proposer_reward\": \"$BASE_PROPOSER_REWARD_CLEAN\"/" "$GENESIS"
    sed -i "s/\"bonus_proposer_reward\": \".*\"/\"bonus_proposer_reward\": \"$BONUS_PROPOSER_REWARD_CLEAN\"/" "$GENESIS"
    sed -i "s/\"withdraw_addr_enabled\": [a-z]*/\"withdraw_addr_enabled\": $WITHDRAW_ADDR_ENABLED_CLEAN/" "$GENESIS"
    
    # Параметры слэшинга (штрафов) и безопасности
    sed -i "s/\"slash_fraction_double_sign\": \".*\"/\"slash_fraction_double_sign\": \"$SLASH_FRACTION_DOUBLE_SIGN_CLEAN\"/" "$GENESIS"
    sed -i "s/\"slash_fraction_downtime\": \".*\"/\"slash_fraction_downtime\": \"$SLASH_FRACTION_DOWNTIME_CLEAN\"/" "$GENESIS"
    sed -i "s/\"downtime_jail_duration\": \".*\"/\"downtime_jail_duration\": \"$DOWNTIME_JAIL_DURATION_CLEAN\"/" "$GENESIS"
    sed -i "s/\"signed_blocks_window\": \".*\"/\"signed_blocks_window\": \"$SIGNED_BLOCKS_WINDOW_CLEAN\"/" "$GENESIS"
    sed -i "s/\"min_signed_per_window\": \".*\"/\"min_signed_per_window\": \"$MIN_SIGNED_PER_WINDOW_CLEAN\"/" "$GENESIS"

    # Настройка config.toml
    # Очищаем переменные от символов новой строки
    RPC_LADDR_CLEAN=$(echo "$RPC_LADDR" | tr -d '\r\n')
    EXTERNAL_ADDR_CLEAN=$(echo "$EXTERNAL_ADDR" | tr -d '\r\n')
    P2P_PORT_CLEAN=$(echo "$P2P_PORT" | tr -d '\r\n')
    
    sed -i "s|^rpc_laddr *=.*|rpc_laddr = \"$RPC_LADDR_CLEAN\"|" "$CONFIG_TOML"
    sed -i "s|^external_address *=.*|external_address = \"$EXTERNAL_ADDR_CLEAN:$P2P_PORT_CLEAN\"|" "$CONFIG_TOML"

    # Настройка app.toml
    # Очищаем переменные от символов новой строки для API и GRPC
    API_ADDRESS_CLEAN=$(echo "$API_ADDRESS" | tr -d '\r\n')
    GRPC_ADDRESS_CLEAN=$(echo "$GRPC_ADDRESS" | tr -d '\r\n')
    
    # [api]
    sed -i "/\\[api\\]/,/^\\[/ s|^address *=.*|address = \"$API_ADDRESS_CLEAN\"|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^enable *=.*|enable = $API_ENABLE|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^swagger *=.*|swagger = $API_SWAGGER|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^max_open_connections *=.*|max_open_connections = $API_MAX_OPEN_CONNECTIONS|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^rpc_write_timeout *=.*|rpc_write_timeout = $API_RPC_WRITE_TIMEOUT|" "$APP_TOML"
    sed -i "/\\[api\\]/,/^\\[/ s|^enabled_unsafe_cors *=.*|enabled_unsafe_cors = $API_ENABLED_UNSAFE_CORS|" "$APP_TOML"
    # [grpc]
    sed -i "/\\[grpc\\]/,/^\\[/ s|^address *=.*|address = \"$GRPC_ADDRESS_CLEAN\"|" "$APP_TOML"
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
    
    # Настройка минимальной цены газа
    MINIMUM_GAS_PRICES_CLEAN=$(echo "$MINIMUM_GAS_PRICES" | tr -d '\r\n')
    STAKE_CLEAN=$(echo "$STAKE" | tr -d '\r\n')
    sed -i "s|^[[:space:]]*minimum-gas-prices *=.*|minimum-gas-prices = \"$MINIMUM_GAS_PRICES_CLEAN$STAKE_CLEAN\"|" "$APP_TOML"
    
    echo "Конфигурация wasmd успешно настроена!"
    
    # Автоматически исправляем файлы конфигурации от символов переноса строки
    echo "Дополнительно исправляем файлы от символов переноса строки..."
    
    # Исправляем config.toml
    echo "Обрабатываем $CONFIG_TOML..."
    TMP_FILE=$(mktemp)
    tr -d '\r' < "$CONFIG_TOML" > "$TMP_FILE"
    mv "$TMP_FILE" "$CONFIG_TOML"
    
    # Исправляем genesis.json
    echo "Обрабатываем $GENESIS..."
    TMP_FILE=$(mktemp)
    tr -d '\r' < "$GENESIS" > "$TMP_FILE"
    mv "$TMP_FILE" "$GENESIS"
    
    # Исправляем app.toml
    echo "Обрабатываем $APP_TOML..."
    TMP_FILE=$(mktemp)
    tr -d '\r' < "$APP_TOML" > "$TMP_FILE"
    mv "$TMP_FILE" "$APP_TOML"
    
    echo "Все файлы конфигурации успешно обработаны!"
    
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
    
    # Очищаем имя от недопустимых символов
    VALIDATOR_WALLET_NAME_CLEAN=$(sanitize_input "$VALIDATOR_WALLET_NAME")
    
    echo "Создание ключа валидатора с именем: $VALIDATOR_WALLET_NAME_CLEAN"
    wasmd keys add "$VALIDATOR_WALLET_NAME_CLEAN" && echo "Ключ валидатора '$VALIDATOR_WALLET_NAME_CLEAN' успешно создан!" || { echo "Ошибка при создании ключа валидатора!"; cd ..; pause; return; }
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
    
    # Очищаем имя от недопустимых символов
    WALLET_NAME_CLEAN=$(sanitize_input "$WALLET_NAME")
    
    echo "Создание кошелька с именем: $WALLET_NAME_CLEAN"
    wasmd keys add "$WALLET_NAME_CLEAN" && echo "Кошелек '$WALLET_NAME_CLEAN' успешно создан!" || { echo "Ошибка при создании кошелька!"; cd ..; pause; return; }
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
    
    # Очищаем введенные данные от недопустимых символов
    WALLET_NAME_CLEAN=$(sanitize_input "$WALLET_NAME")
    AMOUNT_CLEAN=$(sanitize_input "$AMOUNT")
    
    # Очищаем переменную STAKE от символов переноса строки и недопустимых символов
    STAKE_CLEAN=$(sanitize_input "$STAKE")
    
    # Получаем очищенный адрес
    WALLET_ADDR=$(wasmd keys show "$WALLET_NAME_CLEAN" -a | tr -cd 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]')
    
    # Проверяем, что получили допустимый адрес
    if [ -z "$WALLET_ADDR" ]; then
        echo "Ошибка: Не удалось получить адрес для кошелька '$WALLET_NAME_CLEAN'!"
        cd ..
        pause
        return
    fi
    
    echo "Получен адрес: $WALLET_ADDR"
    
    # Формируем сумму с очищенной деноминацией
    AMOUNT_WITH_DENOM="${AMOUNT_CLEAN}${STAKE_CLEAN}"
    
    echo "Выполняем: wasmd genesis add-genesis-account $WALLET_ADDR ${AMOUNT_WITH_DENOM}"
    
    wasmd genesis add-genesis-account "$WALLET_ADDR" "${AMOUNT_WITH_DENOM}" && echo "Генезис-аккаунт для '$WALLET_NAME_CLEAN' успешно добавлен с ${AMOUNT_WITH_DENOM}!" || { echo "Ошибка при добавлении генезис-аккаунта!"; cd ..; pause; return; }
    cd ..
    pause
}


function create_validator_from_json() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    
    # Проверяем, запущена ли нода
    echo "Проверка доступности ноды..."
    if ! wasmd status 2>/dev/null | grep -q "latest_block_height"; then
        echo "Предупреждение: Нода не отвечает. Убедитесь, что она запущена (wasmd start)."
        echo "Валидатор можно создать только на запущенной ноде."
        cd ..
        pause
        return
    fi
    
    # Получаем chain-id
    read -p "Введите chain-id: " chain_id
    chain_id=$(echo "$chain_id" | tr -d '\r\n')
    if [[ -z "$chain_id" ]]; then
        echo "Ошибка: chain-id не может быть пустым."
        cd ..
        pause
        return
    fi
    echo "Chain-id: $chain_id"
    
    # Получаем токен из genesis.json
    coin_prefix=$(jq -r '.app_state["staking"]["params"]["bond_denom"]' ~/.wasmd/config/genesis.json 2>/dev/null)
    if [[ -z "$coin_prefix" ]]; then
        coin_prefix=$(jq -r '.app_state.bank.balances[0].coins[0].denom // empty' ~/.wasmd/config/genesis.json 2>/dev/null)
        if [ -z "$coin_prefix" ]; then
            echo "Использую значение из переменной STAKE."
            coin_prefix="$STAKE"
        fi
    fi
    echo "Монета (токен): $coin_prefix"
    
    # Получаем имя кошелька
    read -p "Введите имя ключа валидатора: " wallet_name
    wallet_name=$(echo "$wallet_name" | tr -d '\r\n')
    
    # Проверяем, что кошелек существует
    wasmd keys show "$wallet_name" --keyring-backend os > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Ошибка: Кошелек '$wallet_name' не найден."
        cd ..
        pause
        return
    fi
    
    # Запрашиваем moniker
    read -p "Введите moniker (имя ноды): " moniker
    moniker=$(echo "$moniker" | tr -d '\r\n')
    
    # Получаем публичный ключ валидатора
    pubkey=$(wasmd tendermint show-validator)
    if [ -z "$pubkey" ]; then
        echo "Ошибка: Не удалось получить публичный ключ валидатора."
        cd ..
        pause
        return
    fi
    key=$(echo "$pubkey" | jq -r '.key')
    
    # Конверсия: 1 токен = 1000000 микроединиц
    token_to_micro=1000000
    
    # Запрос суммы для стейкинга
    while true; do
        read -p "Введите сумму для стейка валидатора (в $coin_prefix, минимум 1, без микроединиц): " input_amount_token
        input_amount_token=$(echo "$input_amount_token" | tr -d '\r\n')
        if [[ "$input_amount_token" =~ ^[0-9]+$ ]]; then
            input_amount=$((input_amount_token * token_to_micro))
            if (( input_amount < token_to_micro )); then
                echo "Предупреждение: Введено меньше минимальной суммы для стейкинга (1 $coin_prefix). Пожалуйста, введите сумму не менее 1 $coin_prefix."
                continue
            fi
            break
        else
            echo "Предупреждение: Введено некорректное значение суммы. Пожалуйста, введите только цифры (например, 3000000)."
        fi
    done
    
    # Запрос минимального self-delegation
    while true; do
        read -p "Введите минимальную сумму самоделегирования (в $coin_prefix, минимум 1, без микроединиц): " min_self_delegation
        min_self_delegation=$(echo "$min_self_delegation" | tr -d '\r\n')
        if [[ "$min_self_delegation" =~ ^[0-9]+$ ]]; then
            min_amount=$((min_self_delegation * token_to_micro))
            if (( min_amount < token_to_micro )); then
                echo "Предупреждение: Введено меньше минимальной суммы для активации (1 $coin_prefix). Пожалуйста, введите сумму не менее 1 $coin_prefix."
                continue
            fi
            if (( min_amount > input_amount )); then
                echo "Предупреждение: Минимальная сумма самоделегирования не может быть больше суммы стейка. Пожалуйста, введите сумму не более $input_amount_token."
                continue
            fi
            break
        else
            echo "Предупреждение: Введено некорректное значение минимальной суммы. Пожалуйста, введите только цифры (например, 1000000)."
        fi
    done
    
    # Формируем суммы с деноминацией
    amount="${input_amount}${coin_prefix}"
    
    # Создаем файл validator.json
    validator_file="./validator.json"
    cat >"$validator_file" <<EOL
{
    "pubkey": {
        "@type": "/cosmos.crypto.ed25519.PubKey",
        "key": "$key"
    },
    "amount": "$amount",
    "moniker": "$moniker",
    "identity": "",
    "website": "",
    "security": "",
    "details": "",
    "commission-rate": "0.10",
    "commission-max-rate": "0.20",
    "commission-max-change-rate": "0.01",
    "min-self-delegation": "$min_self_delegation"
}
EOL
    
    echo "Файл $validator_file создан:"
    cat "$validator_file"
    
    # Выводим информацию о команде
    echo "Создание валидатора с помощью файла..."
    echo "Выполняем команду:"
    echo "wasmd tx staking create-validator \"$validator_file\" --from=\"$wallet_name\" --chain-id=\"$chain_id\" --gas=\"auto\" --gas-adjustment=1.2 --gas-prices=\"0.0001${coin_prefix}\" -y --keyring-backend os"
    
    # Создаем валидатора
    wasmd tx staking create-validator "$validator_file" \
        --from="$wallet_name" \
        --chain-id="$chain_id" \
        --gas="auto" \
        --gas-adjustment=1.2 \
        --gas-prices="0.0001${coin_prefix}" \
        -y \
        --keyring-backend os
    
    if [ $? -ne 0 ]; then
        echo "Ошибка: Создание валидатора завершилось неудачей."
        cd ..
        pause
        return
    fi
    
    # Пауза для завершения транзакции
    echo "Ожидание подтверждения транзакции..."
    sleep 5
    
    # Запрашиваем список валидаторов
    echo "Запрос списка валидаторов..."
    validators=$(wasmd query staking validators --output json 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$validators" ]; then
        echo "Предупреждение: Не удалось получить список валидаторов. Проверьте статус ноды."
        cd ..
        pause
        return
    fi
    
    # Выводим всех валидаторов
    echo "Список всех валидаторов:"
    wasmd query staking validators --output json | jq '.validators[] | {moniker: .description.moniker, tokens: .tokens, status: .status}'
    
    # Запрашиваем информацию о нашем валидаторе
    validator_info=$(echo "$validators" | jq -r ".validators[] | select(.description.moniker == \"$moniker\")")
    if [ -z "$validator_info" ]; then
        echo "Предупреждение: Валидатор с moniker '$moniker' не найден в списке. Возможно, транзакция еще не подтверждена."
        cd ..
        pause
        return
    fi
    
    # Извлекаем данные валидатора
    operator_address=$(echo "$validator_info" | jq -r '.operator_address')
    tokens=$(echo "$validator_info" | jq -r '.tokens')
    status=$(echo "$validator_info" | jq -r '.status')
    
    # Выводим информацию о валидаторе
    echo "Валидатор успешно создан! Вот его данные:"
    echo "MONIKER: $moniker"
    echo "Адрес валидатора: $operator_address"
    echo "Баланс токенов: $tokens $coin_prefix"
    
    # Проверка статуса валидатора
    if [ "$status" == "BOND_STATUS_BONDED" ]; then
        echo "🎉 Ваша нода начинает участвовать в консенсусе и подписывать блоки. Статус: Активен"
    else
        echo "⚠️ Ваша нода не участвует в консенсусе. Статус: $status"
    fi
    
    cd ..
    pause
}

function create_validator() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    
    clear
    echo "Выберите способ создания валидатора:"
    echo "1. Создать валидатора в genesis-файле (для мастер-ноды)"
    echo "2. Создать валидатора через JSON-файл (для подключения к существующей сети)"
    echo "3. Вернуться в главное меню"
    read -p "Ваш выбор: " validator_option
    
    case $validator_option in
        1) create_and_collect_gentx ;;
        2) create_validator_from_json ;;
        3) return ;;
        *) echo "Неверный выбор!"; pause ;;
    esac
} 

function create_and_collect_gentx() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    
    # Проверка существования genesis.json
    if [[ ! -f ~/.wasmd/config/genesis.json ]]; then
        echo "Ошибка: Файл genesis.json не найден. Убедитесь, что нода была правильно инициализирована."
        cd ..
        pause
        return
    fi

    # Проверка наличия утилиты jq
    if ! command -v jq &> /dev/null; then
        echo "Ошибка: Утилита 'jq' не найдена. Установите её с помощью команды: sudo apt install jq"
        cd ..
        pause
        return
    fi

    # Запрос chain-id от пользователя
    read -p "Введите chain-id: " chain_id
    chain_id=$(echo "$chain_id" | tr -d '\r\n')
    if [[ -z "$chain_id" ]]; then
        echo "Ошибка: chain-id не может быть пустым."
        cd ..
        pause
        return
    fi
    echo "Chain-id: $chain_id"

    # Извлечение bond_denom (префикс монеты) из genesis.json
    coin_prefix=$(jq -r '.app_state["staking"]["params"]["bond_denom"]' ~/.wasmd/config/genesis.json)
    if [[ -z "$coin_prefix" ]]; then
        coin_prefix=$(jq -r '.app_state.bank.balances[0].coins[0].denom // empty' ~/.wasmd/config/genesis.json)
        if [ -z "$coin_prefix" ]; then
            echo "Ошибка: Не удалось получить токен (bond_denom) из genesis.json. Используем значение из переменной STAKE."
            coin_prefix="$STAKE"
        fi
    fi
    echo "Монета (токен): $coin_prefix"
    
    # Получение имени кошелька
    read -p "Введите имя ключа валидатора для gentx: " wallet_name
    wallet_name=$(echo "$wallet_name" | tr -d '\r\n')
    
    # Получаем moniker из config.toml или запрашиваем его
    read -p "Введите moniker (имя ноды): " moniker
    moniker=$(echo "$moniker" | tr -d '\r\n')
    echo "Moniker: $moniker"

    # Конверсия: 1 токен = 1000000 микроединиц
    token_to_micro=1

    # Запрос суммы для стейкинга напрямую
    while true; do
        read -p "Введите сумму для стейка валидатора (в $coin_prefix, минимум 1, без микроединиц): " input_amount_token
        input_amount_token=$(echo "$input_amount_token" | tr -d '\r\n')
        if [[ "$input_amount_token" =~ ^[0-9]+$ ]]; then
            input_amount=$((input_amount_token * token_to_micro))
            if (( input_amount < token_to_micro )); then
                echo "Предупреждение: Введено меньше минимальной суммы для стейкинга (1 $coin_prefix). Пожалуйста, введите сумму не менее 1 $coin_prefix."
                continue
            fi
            break
        else
            echo "Предупреждение: Введено некорректное значение суммы. Пожалуйста, введите только цифры (например, 3000000)."
        fi
    done
    
    # Запрос минимального self-delegation
    while true; do
        read -p "Введите минимальную сумму самоделегирования (в $coin_prefix, минимум 1, без микроединиц): " min_self_delegation
        min_self_delegation=$(echo "$min_self_delegation" | tr -d '\r\n')
        if [[ "$min_self_delegation" =~ ^[0-9]+$ ]]; then
            min_amount=$((min_self_delegation * token_to_micro))
            if (( min_amount < token_to_micro )); then
                echo "Предупреждение: Введено меньше минимальной суммы для активации (1 $coin_prefix). Пожалуйста, введите сумму не менее 1 $coin_prefix."
                continue
            fi
            if (( min_amount > input_amount )); then
                echo "Предупреждение: Минимальная сумма самоделегирования не может быть больше суммы стейка. Пожалуйста, введите сумму не более $input_amount_token."
                continue
            fi
            break
        else
            echo "Предупреждение: Введено некорректное значение минимальной суммы. Пожалуйста, введите только цифры (например, 1000000)."
        fi
    done
    
    # Формируем суммы с деноминацией
    amount_with_prefix="${input_amount}${coin_prefix}"

    # Вывод информации о команде
    echo "Создание генезис-транзакции для стейка валидатора от кошелька '$wallet_name' с суммой $input_amount_token $coin_prefix (в микроединицах: $amount_with_prefix)..."

    # Формирование и вывод команды для проверки
    echo "Выполняем команду:"
    echo "wasmd genesis gentx \"$wallet_name\" \"$amount_with_prefix\" \\"
    echo "  --chain-id \"$chain_id\" \\"
    echo "  --moniker \"$moniker\" \\"
    echo "  --commission-rate \"0.10\" \\"
    echo "  --commission-max-rate \"0.20\" \\"
    echo "  --commission-max-change-rate \"0.01\" \\"
    echo "  --min-self-delegation \"$min_self_delegation\" \\"
    echo "  --from \"$wallet_name\" \\"
    echo "  --keyring-backend os"

    # Выполнение команды wasmd genesis gentx
    wasmd genesis gentx "$wallet_name" "$amount_with_prefix" \
        --chain-id "$chain_id" \
        --moniker "$moniker" \
        --commission-rate "0.10" \
        --commission-max-rate "0.20" \
        --commission-max-change-rate "0.01" \
        --min-self-delegation "$min_self_delegation" \
        --from "$wallet_name" \
        --keyring-backend os \
        --home "$HOME/.wasmd"
    
    # Проверка результата выполнения команды
    if [ $? -ne 0 ]; then
        echo "Ошибка при создании генезис-транзакции. Проверьте правильность параметров и доступный баланс."
        cd ..
        pause
        return
    fi

    # Явная проверка наличия файла в директории ~/.wasmd/config/gentx
    gentx_dir=~/.wasmd/config/gentx
    if [[ ! -d "$gentx_dir" ]]; then
        echo "Ошибка: Директория $gentx_dir не существует. Проверьте настройки вашей ноды."
        cd ..
        pause
        return
    fi

    # Поиск файла генезис-транзакции
    gentx_file=$(find "$gentx_dir" -type f -name "gentx-*.json" | head -n 1)
    if [[ -f "$gentx_file" ]]; then
        echo "✅ Генезис-транзакция создана успешно."
        echo "Файл генезис-транзакции найден: $gentx_file"
        
        # Сбор gentx автоматически
        echo "Сбор gentxs..."
        wasmd genesis collect-gentxs && echo "gentxs успешно собраны!" || { echo "Ошибка при сборе gentxs!"; cd ..; pause; return; }
        
        echo
        echo "ID вашей ноды:" 
        wasmd tendermint show-node-id
    else
        echo "❌ Ошибка: Файл генезис-транзакции не найден в директории $gentx_dir. Проверьте логи wasmd для подробностей."
    fi
    
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
    read -p "Введите желаемый Bech32-префикс (например, myprefix): " new_prefix_raw
    if [ -z "$new_prefix_raw" ]; then
        echo "Префикс не может быть пустым!"
        read -p 'Нажмите Enter, чтобы вернуться в меню...'
        return
    fi
    
    # Используем функцию sanitize_input для очистки префикса от нежелательных символов
    new_prefix=$(sanitize_input "$new_prefix_raw")
    
    # Ещё раз проверяем, что после очистки префикс не пустой
    if [ -z "$new_prefix" ]; then
        echo "Префикс после очистки от недопустимых символов стал пустым!"
        read -p 'Нажмите Enter, чтобы вернуться в меню...'
        return
    fi
    
    # Проверяем, что префикс содержит только допустимые символы (a-z, 0-9)
    if ! [[ "$new_prefix" =~ ^[a-z0-9]+$ ]]; then
        echo "❌ Ошибка: Префикс должен содержать только буквы в нижнем регистре (a-z) и цифры (0-9)!"
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
    read -p "Введите сумму для отправки (без деноминации, например, 100000000): " AMOUNT
    if [ -z "$AMOUNT" ]; then
        echo "Сумма не может быть пустой!"
        pause
        return
    fi
    read -p "Введите chain-id (по умолчанию fzp-chain): " CHAIN_ID
    CHAIN_ID=${CHAIN_ID:-fzp-chain}
    
    # Очищаем введенные данные от символов новой строки
    MASTER_ADDR_CLEAN=$(echo "$MASTER_ADDR" | tr -d '\r\n')
    VALIDATOR2_ADDR_CLEAN=$(echo "$VALIDATOR2_ADDR" | tr -d '\r\n')
    AMOUNT_CLEAN=$(echo "$AMOUNT" | tr -d '\r\n')
    CHAIN_ID_CLEAN=$(echo "$CHAIN_ID" | tr -d '\r\n')
    
    # Очищаем переменную STAKE от символов переноса строки
    STAKE_CLEAN=$(echo "$STAKE" | tr -d '\r\n')
    
    # Формируем сумму с очищенной деноминацией
    AMOUNT_WITH_DENOM="${AMOUNT_CLEAN}${STAKE_CLEAN}"
    
    # Добавляем параметр --fees для покрытия комиссии транзакции
    # Стандартное значение для комиссии (минимум 20 токенов)
    FEES="20${STAKE_CLEAN}"
    
    echo "Выполняем: wasmd tx bank send $MASTER_ADDR_CLEAN $VALIDATOR2_ADDR_CLEAN $AMOUNT_WITH_DENOM --chain-id $CHAIN_ID_CLEAN --fees $FEES"
    
    wasmd tx bank send "$MASTER_ADDR_CLEAN" "$VALIDATOR2_ADDR_CLEAN" "$AMOUNT_WITH_DENOM" \
        --chain-id "$CHAIN_ID_CLEAN" \
        --fees "$FEES" \
        --keyring-backend os \
        --yes
    
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

function fix_config_files() {
    CONFIG_TOML="/root/.wasmd/config/config.toml"
    GENESIS_JSON="/root/.wasmd/config/genesis.json"
    APP_TOML="/root/.wasmd/config/app.toml"
    
    echo "Исправляем файлы конфигурации от символов переноса строки..."
    
    # Исправляем config.toml
    if [ -f "$CONFIG_TOML" ]; then
        echo "Обрабатываем $CONFIG_TOML..."
        # Создаем временный файл
        TMP_FILE=$(mktemp)
        # Удаляем символы возврата каретки и сохраняем в временный файл
        tr -d '\r' < "$CONFIG_TOML" > "$TMP_FILE"
        # Заменяем оригинальный файл исправленным
        mv "$TMP_FILE" "$CONFIG_TOML"
        echo "✅ Файл $CONFIG_TOML успешно исправлен"
    else
        echo "⚠️ Файл $CONFIG_TOML не найден"
    fi
    
    # Исправляем genesis.json
    if [ -f "$GENESIS_JSON" ]; then
        echo "Обрабатываем $GENESIS_JSON..."
        # Создаем временный файл
        TMP_FILE=$(mktemp)
        # Удаляем символы возврата каретки и сохраняем в временный файл
        tr -d '\r' < "$GENESIS_JSON" > "$TMP_FILE"
        # Заменяем оригинальный файл исправленным
        mv "$TMP_FILE" "$GENESIS_JSON"
        echo "✅ Файл $GENESIS_JSON успешно исправлен"
    else
        echo "⚠️ Файл $GENESIS_JSON не найден"
    fi
    
    # Исправляем app.toml
    if [ -f "$APP_TOML" ]; then
        echo "Обрабатываем $APP_TOML..."
        # Создаем временный файл
        TMP_FILE=$(mktemp)
        # Удаляем символы возврата каретки и сохраняем в временный файл
        tr -d '\r' < "$APP_TOML" > "$TMP_FILE"
        # Заменяем оригинальный файл исправленным
        mv "$TMP_FILE" "$APP_TOML"
        echo "✅ Файл $APP_TOML успешно исправлен"
    else
        echo "⚠️ Файл $APP_TOML не найден"
    fi
    
    echo "Все файлы конфигурации успешно обработаны!"
    pause
}

function setup_nftables() {
    # Запрос адресов нод
    read -p "Введите IP-адрес первой ноды: " NODE1_IP
    read -p "Введите IP-адрес второй ноды: " NODE2_IP
    read -p "Введите IP-адрес третьей ноды: " NODE3_IP

    # Запрос административного IP для SSH
    read -p "Введите административный IP для доступа по SSH: " ADMIN_IP

    # Установка необходимых пакетов
    echo "Установка необходимых пакетов..."
    sudo apt update
    sudo apt install -y nftables

    # Настройка nftables
    echo "Настройка nftables..."

    NFTABLES_CONF="/etc/nftables.conf"

    sudo bash -c "cat > $NFTABLES_CONF" <<EOL
#!/usr/sbin/nft -f

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;

        # Accept established and related connections
        ct state established,related accept

        # Allow loopback traffic
        iif lo accept

        # Allow SSH from the admin IP
        ip saddr $ADMIN_IP tcp dport 22 accept

        # Allow traffic between the nodes
        ip saddr { $NODE1_IP, $NODE2_IP, $NODE3_IP } accept
        ip daddr { $NODE1_IP, $NODE2_IP, $NODE3_IP } accept

        # Log and drop everything else
        log prefix "Dropped: " counter
        drop
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOL

    # Активируем и перезапускаем nftables
    echo "Активация и перезапуск nftables..."
    sudo systemctl enable nftables
    sudo systemctl restart nftables

    echo "Настройка завершена. Правила nftables применены."
    echo "Разрешен SSH-доступ с IP: $ADMIN_IP"
    echo "Разрешен трафик между нодами: $NODE1_IP, $NODE2_IP, $NODE3_IP"

    # Функции логирования
    log_info() {
        echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"
    }
    log_error() {
        echo -e "\e[31m[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1\e[0m" >&2
    }

    log_info "nftables успешно настроен."
    pause
}

function helper_menu() {
    # Одинаковое меню для обоих типов нод
    while true; do
        clear
        echo "Утилиты/дополнительные действия"
        echo "1. Запустить ноду wasmd (foreground)"
        echo "2. Отправить монеты (tx bank send)"
        echo "3. Просмотреть логи"
        echo "4. Резервное копирование файлов"
        echo "5. Проверить статус сервиса"
        echo "6. Тестовый запуск"
        echo "7. Вернуться в главное меню"
        echo -n "Выберите пункт меню: "
        read helper_choice
        case $helper_choice in
            1) start_wasmd_node ;;
            2) send_tokens ;;
            3) view_logs ;;
            4) backup_files ;;
            5) check_service_status ;;
            6) test_run ;;
            7) break ;;
            *) echo "Неверный выбор!"; pause ;;
        esac
    done
}

# Добавляем недостающие функции для вспомогательного меню
function view_logs() {
    echo "Просмотр журнала сервиса wasmd..."
    sudo journalctl -u wasmd -n 100 --no-pager
    echo
    echo "Для непрерывного просмотра журнала используйте команду:"
    echo "sudo journalctl -u wasmd -f"
    pause
}

function backup_files() {
    BACKUP_DIR="wasmd_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    echo "Создание резервной копии конфигурационных файлов..."
    cp -r ~/.wasmd/config "$BACKUP_DIR/" 2>/dev/null || echo "Конфигурация не найдена"
    cp -r ~/.wasmd/data/priv_validator_state.json "$BACKUP_DIR/" 2>/dev/null || echo "Файл состояния валидатора не найден"
    
    echo "Сохранение информации о ключах (без приватных данных)..."
    wasmd keys list > "$BACKUP_DIR/keys_list.txt" 2>/dev/null || echo "Ошибка при получении списка ключей"
    
    echo "Сохранение версий и статусов..."
    wasmd version > "$BACKUP_DIR/version.txt" 2>/dev/null
    wasmd status > "$BACKUP_DIR/status.txt" 2>/dev/null || echo "Ошибка при получении статуса ноды"
    
    echo "Создание архива..."
    tar -czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR" && rm -rf "$BACKUP_DIR"
    
    echo "Резервная копия создана: ${BACKUP_DIR}.tar.gz"
    echo "Сохраните этот файл в надежном месте!"
    pause
}

function check_service_status() {
    echo "Проверка статуса сервиса wasmd..."
    sudo systemctl status wasmd --no-pager
    echo
    echo "Проверка последних логов:"
    sudo journalctl -u wasmd -n 10 --no-pager
    pause
}

function test_run() {
    echo "Запуск wasmd в тестовом режиме (нажмите Ctrl+C для выхода)..."
    cd "$(dirname "$(which wasmd)")" 2>/dev/null || cd ~
    wasmd start
    cd - > /dev/null
    pause
}

function collect_node_ids() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    
    echo "Сбор информации о нодах для persistent_peers"
    echo "Введите информацию о нодах (пустая строка для завершения):"
    
    PEERS=""
    while true; do
        read -p "IP-адрес ноды (или Enter для завершения): " NODE_IP
        if [ -z "$NODE_IP" ]; then
            break
        fi
        
        read -p "ID ноды: " NODE_ID
        if [ -z "$NODE_ID" ]; then
            echo "ID ноды не может быть пустым!"
            continue
        fi
        
        # Очищаем введенные данные от недопустимых символов
        NODE_IP_CLEAN=$(sanitize_input "$NODE_IP")
        NODE_ID_CLEAN=$(sanitize_input "$NODE_ID")
        
        # Формируем строку для одной ноды
        NODE_STRING="${NODE_ID_CLEAN}@${NODE_IP_CLEAN}:26656"
        
        if [ -z "$PEERS" ]; then
            PEERS="$NODE_STRING"
        else
            PEERS="$PEERS,$NODE_STRING"
        fi
        
        echo "Сформированная строка для ноды: $NODE_STRING"
    done
    
    if [ ! -z "$PEERS" ]; then
        echo
        echo "Итоговая строка persistent_peers:"
        echo "$PEERS"
        echo
        echo "Скопируйте эту строку и используйте её в config.toml"
    else
        echo "⚠️ Не было добавлено ни одной ноды"
    fi
    
    pause
}

function create_master_validator() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    
    # Запрашиваем необходимые данные
    read -p "Введите имя ключа валидатора: " VALIDATOR_WALLET_NAME
    read -p "Введите количество монет для стейкинга: " STAKE_AMOUNT
    read -p "Введите chain-id: " CHAIN_ID
    
    # Очищаем введенные данные
    VALIDATOR_WALLET_NAME_CLEAN=$(sanitize_input "$VALIDATOR_WALLET_NAME")
    STAKE_AMOUNT_CLEAN=$(sanitize_input "$STAKE_AMOUNT")
    CHAIN_ID_CLEAN=$(sanitize_input "$CHAIN_ID")
    STAKE_CLEAN=$(sanitize_input "$STAKE")
    
    # Получаем адрес валидатора (без очистки!)
    VALIDATOR_ADDR=$(wasmd keys show "$VALIDATOR_WALLET_NAME_CLEAN" -a --keyring-backend os)
    if [ -z "$VALIDATOR_ADDR" ]; then
        echo "Ошибка: Не удалось получить адрес валидатора!"
        cd ..
        pause
        return
    fi
    
    # Формируем сумму с деноминацией
    STAKE_WITH_DENOM="${STAKE_AMOUNT_CLEAN}${STAKE_CLEAN}"
    
    echo "Создание валидатора в генезисе..."
    echo "Имя: $VALIDATOR_WALLET_NAME_CLEAN"
    echo "Адрес: $VALIDATOR_ADDR"
    echo "Сумма стейкинга: $STAKE_WITH_DENOM"
    echo "Chain ID: $CHAIN_ID_CLEAN"
    
    # Создаем gentx со всеми необходимыми параметрами
    wasmd genesis gentx "$VALIDATOR_WALLET_NAME_CLEAN" "$STAKE_WITH_DENOM" \
        --chain-id "$CHAIN_ID_CLEAN" \
        --moniker "$VALIDATOR_WALLET_NAME_CLEAN" \
        --commission-rate "0.10" \
        --commission-max-rate "0.20" \
        --commission-max-change-rate "0.01" \
        --min-self-delegation "1" \
        --keyring-backend os \
        --home "$HOME/.wasmd"
    
    if [ $? -eq 0 ]; then
        echo "✅ Gentx успешно создан!"
        
        # Собираем все gentx
        echo "Сбор всех gentx..."
        wasmd genesis collect-gentxs
        
        echo "✅ Валидатор успешно добавлен в генезис!"
        echo "ID вашей ноды:"
        wasmd tendermint show-node-id
    else
        echo "❌ Ошибка при создании gentx!"
    fi
    
    cd ..
    pause
}

# Основной цикл меню
while true; do
    clear
    echo "=========================================================="
    echo "                  WASMD: Меню Установки                   "
    echo "=========================================================="
    echo "1.  Клонировать репозиторий блокчейна"
    echo "2.  Установить зависимости для сборки"
    echo "3.  Установить Bech32-префикс"
    echo "4.  Собрать и установить wasmd"
    echo "5.  Инициализировать узел wasmd"
    echo "6.  Настроить конфигурацию wasmd"
    echo "7.  Создать ключ валидатора"
    echo "8.  Создать обычный кошелек"
    echo "9.  Добавить аккаунт в генезис"
    echo "10. Создать валидатора в генезисе"
    echo "11. Создать и собрать gentx"
    echo "12. Создать валидатора через JSON"
    echo "13. Показать ID ноды"
    echo "14. Копировать genesis.json на другую ноду"
    echo "15. Создать systemd-сервис и добавить в автозагрузку"
    echo "16. Настроить файрвол (nftables) для защиты нод"
    echo "17. Запустить ноду wasmd (foreground)"
    echo "18. Отправить монеты (tx bank send)"
    echo "19. Просмотреть логи"
    echo "20. Резервное копирование файлов"
    echo "21. Проверить статус сервиса"
    echo "22. Тестовый запуск"
    echo "23. Собрать ID нод для config.toml"
    echo "0.  Выйти"
    echo "----------------------------------------------------------"
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
        8) add_wallet ;;
        9) add_genesis_account ;;
        10) create_master_validator ;;
        11) create_and_collect_gentx ;;
        12) create_validator_from_json ;;
        13) show_node_id ;;
        14) copy_genesis_to_node ;;
        15) create_systemd_service ;;
        16) setup_nftables ;;
        17) start_wasmd_node ;;
        18) send_tokens ;;
        19) view_logs ;;
        20) backup_files ;;
        21) check_service_status ;;
        22) test_run ;;
        23) collect_node_ids ;;
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор!"; pause ;;
    esac
done


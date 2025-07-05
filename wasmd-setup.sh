#!/bin/bash
set -e

# Принудительно используем test keyring-backend для избежания зависаний
# Можно изменить на "os" если нужно использовать системный keyring
export KEYRING_BACKEND=${KEYRING_BACKEND:-"test"}

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

# Функция для определения доступного keyring-backend
detect_keyring_backend() {
    # Проверяем переменную окружения
    if [ ! -z "$KEYRING_BACKEND" ]; then
        echo "$KEYRING_BACKEND"
        return
    fi
    
    # Всегда используем test backend по умолчанию (самый безопасный и быстрый)
    # Он не требует системных настроек и почти всегда работает
    echo "test"
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

# Функция для определения минимальной суммы для валидатора
get_min_validator_stake() {
    # Безопасная большая сумма по умолчанию (1 триллион)
    local safe_default="1000000000000"
    
    # Пытаемся определить DefaultPowerReduction разными способами
    
    # Способ 1: Из сохраненного файла (обновляется при ошибках)
    if [ -f ~/.wasmd_min_stake ]; then
        local saved_value=$(cat ~/.wasmd_min_stake 2>/dev/null)
        if [[ "$saved_value" =~ ^[0-9]+$ ]] && [ "$saved_value" -gt 0 ]; then
            echo "$saved_value"
            return
        fi
    fi
    
    # Способ 2: Из genesis.json (если есть параметр)
    if [ -f ~/.wasmd/config/genesis.json ] && command -v jq &> /dev/null; then
        power_reduction=$(jq -r '.app_state.staking.params.power_reduction // empty' ~/.wasmd/config/genesis.json 2>/dev/null)
        if [ ! -z "$power_reduction" ] && [ "$power_reduction" != "null" ] && [[ "$power_reduction" =~ ^[0-9]+$ ]]; then
            echo "$power_reduction"
            return
        fi
    fi
    
    # Способ 3: Из логов wasmd (если есть)
    if [ -f ~/.wasmd/logs/wasmd.log ]; then
        power_reduction=$(grep -o "DefaultPowerReduction ({[0-9]*})" ~/.wasmd/logs/wasmd.log 2>/dev/null | tail -1 | grep -o "[0-9]*")
        if [[ "$power_reduction" =~ ^[0-9]+$ ]] && [ "$power_reduction" -gt 0 ]; then
            echo "$power_reduction"
            return
        fi
    fi
    
    # Способ 4: Поиск в системных логах
    if command -v journalctl &> /dev/null; then
        power_reduction=$(journalctl -u wasmd --no-pager -n 100 2>/dev/null | grep -o "DefaultPowerReduction ({[0-9]*})" | tail -1 | grep -o "[0-9]*")
        if [[ "$power_reduction" =~ ^[0-9]+$ ]] && [ "$power_reduction" -gt 0 ]; then
            echo "$power_reduction"
            return
        fi
    fi
    
    # Способ 5: Безопасное значение по умолчанию
    echo "$safe_default"
}

# Функция для предложения безопасной суммы
suggest_safe_amount() {
    local min_required="$1"
    local safe_multiplier=10  # В 10 раз больше минимума
    
    if [[ "$min_required" =~ ^[0-9]+$ ]] && [ "$min_required" -gt 0 ]; then
        local safe_amount=$((min_required * safe_multiplier))
        echo "$safe_amount"
    else
        echo "10000000000000"  # 10 триллионов как резерв
    fi
}

# Функция для извлечения минимальной суммы из текста ошибки
extract_min_from_error() {
    local error_text="$1"
    if [ ! -z "$error_text" ]; then
        local extracted=$(echo "$error_text" | grep -o "DefaultPowerReduction ({[0-9]*})" | grep -o "[0-9]*" | tail -1)
        if [[ "$extracted" =~ ^[0-9]+$ ]] && [ "$extracted" -gt 0 ]; then
            echo "$extracted"
            return 0
        fi
    fi
    return 1
}

# Функция для обновления минимальной суммы в runtime
update_min_stake_from_error() {
    local error_message="$1"
    if [ ! -z "$error_message" ]; then
        local new_min=$(echo "$error_message" | grep -o "DefaultPowerReduction ({[0-9]*})" | grep -o "[0-9]*")
        if [ ! -z "$new_min" ]; then
            echo "🔄 Обнаружено новое минимальное значение: $new_min"
            echo "Сохраняем для использования в следующий раз..."
            echo "$new_min" > ~/.wasmd_min_stake 2>/dev/null || true
            echo "$new_min"
            return
        fi
    fi
    
    # Если в ошибке не нашли, попробуем из сохраненного файла
    if [ -f ~/.wasmd_min_stake ]; then
        cat ~/.wasmd_min_stake
    else
        get_min_validator_stake
    fi
}

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

    # Изменяем chain-id, если нужно
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

function quick_add_validator_key() {
    echo "=========================================================="
    echo "           БЫСТРОЕ СОЗДАНИЕ КЛЮЧА ВАЛИДАТОРА             "
    echo "=========================================================="
    echo ""
    
    if [ ! -d "wasmd" ]; then
        echo "❌ Сначала клонируйте репозиторий (пункт 1)!"
        echo "Нажмите Enter для возврата в меню..."
        read
        return
    fi
    
    cd wasmd
    
    read -p "Введите имя для ключа валидатора: " VALIDATOR_WALLET_NAME
    VALIDATOR_WALLET_NAME_CLEAN=$(sanitize_input "$VALIDATOR_WALLET_NAME")
    
    echo ""
    echo "⚠️ ВАЖНО: Сохраните mnemonic фразу!"
    echo ""
    echo "Создание ключа с test keyring-backend..."
    
    # Напрямую создаем с test backend
    wasmd keys add "$VALIDATOR_WALLET_NAME_CLEAN" --keyring-backend test
    
    echo ""
    echo "✅ Ключ создан! Адрес:"
    wasmd keys show "$VALIDATOR_WALLET_NAME_CLEAN" -a --keyring-backend test 2>/dev/null || echo "Не удалось получить адрес"
    
    cd ..
    echo ""
    echo "Нажмите Enter для возврата в меню..."
    read
}

function add_validator_key() {
    clear
    echo "Выберите способ создания ключа:"
    echo "1. Обычное создание (автоопределение keyring)"
    echo "2. Быстрое создание (принудительно test keyring)"
    echo "3. Вернуться в меню"
    read -p "Ваш выбор: " key_choice
    
    case $key_choice in
        1) create_validator_key_normal ;;
        2) quick_add_validator_key ;;
        3) return ;;
        *) echo "Неверный выбор!"; pause ;;
    esac
}

function create_validator_key_normal() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    
    echo "=========================================================="
    echo "               СОЗДАНИЕ КЛЮЧА ВАЛИДАТОРА                 "
    echo "=========================================================="
    echo ""
    
    read -p "Введите имя для ключа валидатора: " VALIDATOR_WALLET_NAME
    
    # Очищаем имя от недопустимых символов
    VALIDATOR_WALLET_NAME_CLEAN=$(sanitize_input "$VALIDATOR_WALLET_NAME")
    
    echo ""
    echo "Создание ключа валидатора с именем: $VALIDATOR_WALLET_NAME_CLEAN"
    echo ""
    echo "⚠️ ВАЖНО: Сохраните mnemonic фразу в безопасном месте!"
    echo "Без неё вы не сможете восстановить кошелек!"
    echo ""
    
    # Определяем keyring-backend
    KEYRING_BACKEND=$(detect_keyring_backend)
    echo "Используется keyring-backend: $KEYRING_BACKEND"
    echo ""
    
    # Создаем ключ с определенным keyring-backend
    echo "Создание ключа..."
    if wasmd keys add "$VALIDATOR_WALLET_NAME_CLEAN" --keyring-backend "$KEYRING_BACKEND"; then
        echo ""
        echo "✅ Ключ валидатора '$VALIDATOR_WALLET_NAME_CLEAN' успешно создан!"
        
        # Показываем адрес
        echo ""
        echo "📍 Адрес валидатора:"
        timeout 10s wasmd keys show "$VALIDATOR_WALLET_NAME_CLEAN" -a --keyring-backend "$KEYRING_BACKEND" 2>/dev/null || echo "Не удалось получить адрес"
        
        echo ""
        echo "📋 Список всех ключей:"
        timeout 10s wasmd keys list --keyring-backend "$KEYRING_BACKEND" 2>/dev/null || echo "Не удалось получить список ключей"
        
    else
        echo ""
        echo "❌ Ошибка при создании ключа валидатора!"
        echo "Попробуйте создать ключ вручную:"
        echo "wasmd keys add $VALIDATOR_WALLET_NAME_CLEAN --keyring-backend $KEYRING_BACKEND"
    fi
    
    cd ..
    echo ""
    echo "Нажмите Enter для возврата в меню..."
    read
}

function add_wallet() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    
    echo "=========================================================="
    echo "                  СОЗДАНИЕ КОШЕЛЬКА                      "
    echo "=========================================================="
    echo ""
    
    read -p "Введите имя для кошелька: " WALLET_NAME
    
    # Очищаем имя от недопустимых символов
    WALLET_NAME_CLEAN=$(sanitize_input "$WALLET_NAME")
    
    # Определяем keyring-backend
    KEYRING_BACKEND=$(detect_keyring_backend)
    echo "Используется keyring-backend: $KEYRING_BACKEND"
    
    echo ""
    echo "Создание кошелька с именем: $WALLET_NAME_CLEAN"
    echo ""
    echo "⚠️ ВАЖНО: Сохраните mnemonic фразу в безопасном месте!"
    echo "Без неё вы не сможете восстановить кошелек!"
    echo ""
    
    # Создаем кошелек с определенным keyring-backend
    if wasmd keys add "$WALLET_NAME_CLEAN" --keyring-backend "$KEYRING_BACKEND"; then
        echo ""
        echo "✅ Кошелек '$WALLET_NAME_CLEAN' успешно создан!"
        
        # Показываем адрес
        echo ""
        echo "📍 Адрес кошелька:"
        timeout 10s wasmd keys show "$WALLET_NAME_CLEAN" -a --keyring-backend "$KEYRING_BACKEND" 2>/dev/null || echo "Не удалось получить адрес"
        
    else
        echo "❌ Ошибка при создании кошелька!"
        echo "Попробуйте создать кошелек вручную:"
        echo "wasmd keys add $WALLET_NAME_CLEAN --keyring-backend $KEYRING_BACKEND"
    fi
    
    cd ..
    echo ""
    echo "Нажмите Enter для возврата в меню..."
    read
}

function add_genesis_account() {
    if [ ! -d "wasmd" ]; then
        echo "Сначала клонируйте репозиторий!"
        pause
        return
    fi
    cd wasmd
    
    echo "=========================================================="
    echo "               ДОБАВЛЕНИЕ АККАУНТА В GENESIS             "
    echo "=========================================================="
    echo ""
    
    read -p "Введите имя кошелька для добавления в генезис: " WALLET_NAME
    
    # Определяем минимальные суммы
    MIN_VALIDATOR_STAKE=$(get_min_validator_stake)
    SAFE_AMOUNT=$(suggest_safe_amount "$MIN_VALIDATOR_STAKE")
    
    echo ""
    echo "💰 Рекомендуемые суммы для добавления:"
    echo "   - Минимум для валидатора: $MIN_VALIDATOR_STAKE"
    echo "   - Безопасная сумма: $SAFE_AMOUNT (рекомендуется)"
    echo "   - Максимальная безопасная: 10000000000000"
    echo ""
    echo "💡 Выберите сумму для добавления:"
    echo "   1. Безопасная сумма: $SAFE_AMOUNT (рекомендуется)"
    echo "   2. Максимальная: 10000000000000"
    echo "   3. Ввести свою сумму"
    echo ""
    
    while true; do
        read -p "Выберите вариант (1-3): " amount_choice
        
        case $amount_choice in
            1)
                AMOUNT="$SAFE_AMOUNT"
                echo "✅ Выбрана безопасная сумма: $AMOUNT"
                break
                ;;
            2)
                AMOUNT="10000000000000"
                echo "✅ Выбрана максимальная сумма: $AMOUNT"
                break
                ;;
            3)
                echo ""
                read -p "Введите количество монет (минимум $MIN_VALIDATOR_STAKE): " custom_amount
                custom_amount=$(echo "$custom_amount" | tr -d '\r\n')
                if [[ "$custom_amount" =~ ^[0-9]+$ ]]; then
                    if (( custom_amount < MIN_VALIDATOR_STAKE )); then
                        echo "⚠️ Сумма меньше минимума для валидатора!"
                        echo "Рекомендуется использовать минимум $MIN_VALIDATOR_STAKE"
                        read -p "Все равно продолжить с $custom_amount? (y/n): " confirm
                        if [[ "$confirm" =~ ^[yYдД]$ ]]; then
                            AMOUNT="$custom_amount"
                            break
                        else
                            continue
                        fi
                    else
                        AMOUNT="$custom_amount"
                        echo "✅ Принята сумма: $AMOUNT"
                        break
                    fi
                else
                    echo "❌ Введите только цифры!"
                    continue
                fi
                ;;
            *)
                echo "❌ Неверный выбор! Введите 1, 2 или 3"
                continue
                ;;
        esac
    done
    
    # Очищаем переменную STAKE от символов переноса строки и недопустимых символов
    STAKE_CLEAN=$(sanitize_input "$STAKE")
    
    # Определяем keyring-backend
    KEYRING_BACKEND=$(detect_keyring_backend)
    echo "Используется keyring-backend: $KEYRING_BACKEND"
    
    # Получаем очищенный адрес
    echo "Получение адреса кошелька '$WALLET_NAME'..."
    WALLET_ADDR=$(timeout 10s wasmd keys show "$WALLET_NAME" -a --keyring-backend "$KEYRING_BACKEND" 2>/dev/null | tr -cd 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]')
    
    # Проверяем, что получили допустимый адрес
    if [ -z "$WALLET_ADDR" ]; then
        echo "❌ Ошибка: Не удалось получить адрес для кошелька '$WALLET_NAME'!"
        echo ""
        echo "Возможные причины:"
        echo "1. Кошелек не существует"
        echo "2. Неправильный keyring-backend"
        echo "3. Требуется пароль"
        echo ""
        echo "💡 Сначала создайте кошелек (пункт 7)"
        cd ..
        pause
        return
    fi
    
    echo "Получен адрес: $WALLET_ADDR"
    
    # Формируем сумму с очищенной деноминацией
    AMOUNT_WITH_DENOM="${AMOUNT}${STAKE_CLEAN}"
    
    echo "Выполняем: wasmd genesis add-genesis-account $WALLET_ADDR ${AMOUNT_WITH_DENOM}"
    
    # Выполняем команду с детальной диагностикой
    if wasmd genesis add-genesis-account "$WALLET_ADDR" "${AMOUNT_WITH_DENOM}"; then
        echo "✅ Генезис-аккаунт для '$WALLET_NAME' успешно добавлен с ${AMOUNT_WITH_DENOM}!"
        
        # Проверяем, что аккаунт действительно добавлен в genesis.json
        if command -v jq &> /dev/null; then
            echo "🔍 Проверка добавления аккаунта в genesis.json..."
            account_found=$(jq -r ".app_state.bank.balances[] | select(.address == \"$WALLET_ADDR\") | .address" ~/.wasmd/config/genesis.json 2>/dev/null)
            if [ "$account_found" = "$WALLET_ADDR" ]; then
                echo "✅ Аккаунт $WALLET_ADDR найден в genesis.json"
                
                # Проверяем баланс
                balance=$(jq -r ".app_state.bank.balances[] | select(.address == \"$WALLET_ADDR\") | .coins[0].amount" ~/.wasmd/config/genesis.json 2>/dev/null)
                echo "💰 Баланс аккаунта: $balance $STAKE_CLEAN"
                
                # Проверяем, что сумма достаточна для валидатора
                MIN_VALIDATOR_STAKE=$(get_min_validator_stake)
                if (( balance >= MIN_VALIDATOR_STAKE )); then
                    echo "✅ Баланс достаточен для создания валидатора"
                else
                    echo "❌ ВНИМАНИЕ: Баланс ($balance) меньше минимального требования для валидатора ($MIN_VALIDATOR_STAKE)"
                    echo "💡 Увеличьте сумму при добавлении аккаунта!"
                    echo "💡 Или обновите минимальную сумму через пункт 19.7"
                fi
            else
                echo "❌ ОШИБКА: Аккаунт $WALLET_ADDR НЕ найден в genesis.json!"
                echo "Проверьте genesis.json вручную:"
                echo "jq '.app_state.bank.balances' ~/.wasmd/config/genesis.json"
            fi
        fi
    else
        echo "❌ Ошибка при добавлении генезис-аккаунта!"
        echo ""
        echo "Возможные причины:"
        echo "1. Файл genesis.json не найден или поврежден"
        echo "2. Неправильный формат адреса"
        echo "3. Неправильный формат суммы"
        echo "4. Нода не была инициализирована"
        echo ""
        echo "💡 Попробуйте:"
        echo "1. Инициализировать ноду (пункт 5)"
        echo "2. Проверить формат адреса: $WALLET_ADDR"
        echo "3. Проверить формат суммы: $AMOUNT_WITH_DENOM"
        
        cd ..
        pause
        return
    fi
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
    
    # Получаем текущую минимальную сумму для валидатора
    echo "🔍 Определение минимальной суммы для валидатора..."
    MIN_VALIDATOR_STAKE=$(get_min_validator_stake)
    SAFE_AMOUNT=$(suggest_safe_amount "$MIN_VALIDATOR_STAKE")
    
    echo "📊 Минимальная сумма для валидатора: $MIN_VALIDATOR_STAKE $coin_prefix"
    echo "🛡️ Рекомендуемая безопасная сумма: $SAFE_AMOUNT $coin_prefix"
    echo ""
    
    # Предлагаем пользователю обновить минимальную сумму если есть новая ошибка
    echo "❓ Если вы получили ошибку 'validator set is empty' с новым значением DefaultPowerReduction:"
    read -p "Хотите ввести текст ошибки для автоматического определения суммы? (y/n): " update_from_error
    
    if [[ "$update_from_error" =~ ^[yYдД]$ ]]; then
        echo ""
        echo "📋 Вставьте полный текст ошибки (нажмите Enter два раза для завершения):"
        error_text=""
        while IFS= read -r line; do
            [ -z "$line" ] && break
            error_text+="$line "
        done
        
        if [ ! -z "$error_text" ]; then
            if extracted_min=$(extract_min_from_error "$error_text"); then
                echo "✅ Извлечено новое минимальное значение: $extracted_min"
                echo "$extracted_min" > ~/.wasmd_min_stake
                MIN_VALIDATOR_STAKE="$extracted_min"
                SAFE_AMOUNT=$(suggest_safe_amount "$MIN_VALIDATOR_STAKE")
                echo "📊 Обновленная минимальная сумма: $MIN_VALIDATOR_STAKE $coin_prefix"
                echo "🛡️ Новая рекомендуемая сумма: $SAFE_AMOUNT $coin_prefix"
            else
                echo "⚠️ Не удалось извлечь значение из ошибки. Используем текущие настройки."
            fi
        fi
        echo ""
    fi

    # Запрос суммы для стейкинга с умными предложениями
    while true; do
        echo "💰 Варианты сумм для стейкинга:"
        echo "   1. Минимальная: $MIN_VALIDATOR_STAKE $coin_prefix"
        echo "   2. Безопасная: $SAFE_AMOUNT $coin_prefix (рекомендуется)"
        echo "   3. Ввести свою сумму"
        echo ""
        read -p "Выберите вариант (1-3): " amount_choice
        
        case $amount_choice in
            1)
                input_amount_token="$MIN_VALIDATOR_STAKE"
                echo "✅ Выбрана минимальная сумма: $input_amount_token $coin_prefix"
                break
                ;;
            2)
                input_amount_token="$SAFE_AMOUNT"
                echo "✅ Выбрана безопасная сумма: $input_amount_token $coin_prefix"
                break
                ;;
            3)
                echo ""
                read -p "Введите сумму для стейка валидатора (минимум $MIN_VALIDATOR_STAKE): " custom_amount
                custom_amount=$(echo "$custom_amount" | tr -d '\r\n')
                if [[ "$custom_amount" =~ ^[0-9]+$ ]]; then
                    if (( custom_amount < MIN_VALIDATOR_STAKE )); then
                        echo "❌ Сумма ($custom_amount) меньше минимума ($MIN_VALIDATOR_STAKE)!"
                        echo "💡 Используйте минимум $MIN_VALIDATOR_STAKE или больше"
                        continue
                    fi
                    input_amount_token="$custom_amount"
                    echo "✅ Принята сумма: $input_amount_token $coin_prefix"
                    break
                else
                    echo "❌ Введите только цифры!"
                    continue
                fi
                ;;
            *)
                echo "❌ Неверный выбор! Введите 1, 2 или 3"
                continue
                ;;
        esac
    done
    
    # Запрос минимального self-delegation (упрощенный)
    echo ""
    echo "💡 Для минимального самоделегирования рекомендуется использовать ту же сумму"
    read -p "Минимальная сумма самоделегирования (Enter = $input_amount_token): " min_self_delegation
    min_self_delegation=${min_self_delegation:-$input_amount_token}
    min_self_delegation=$(echo "$min_self_delegation" | tr -d '\r\n')
    
    if [[ "$min_self_delegation" =~ ^[0-9]+$ ]]; then
        if (( min_self_delegation < MIN_VALIDATOR_STAKE )); then
            echo "⚠️ Используем минимум: $MIN_VALIDATOR_STAKE"
            min_self_delegation=$MIN_VALIDATOR_STAKE
        fi
        if (( min_self_delegation > input_amount_token )); then
            echo "⚠️ Самоделегирование не может быть больше стейка. Используем: $input_amount_token"
            min_self_delegation=$input_amount_token
        fi
    else
        echo "⚠️ Используем значение по умолчанию: $input_amount_token"
        min_self_delegation=$input_amount_token
    fi
    
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
    
    # Определяем доступный keyring-backend
    echo "Определение keyring-backend..."
    KEYRING_BACKEND=$(detect_keyring_backend)
    echo "Используется keyring-backend: $KEYRING_BACKEND"
    
    # Проверяем, что кошелек существует
    echo "Проверка существования кошелька '$wallet_name'..."
    
    # Используем timeout для предотвращения зависания
    if timeout 10s wasmd keys show "$wallet_name" --keyring-backend "$KEYRING_BACKEND" > /dev/null 2>&1; then
        echo "✅ Кошелек '$wallet_name' найден"
    else
        echo "❌ Ошибка: Кошелек '$wallet_name' не найден или недоступен."
        echo ""
        echo "Возможные причины:"
        echo "1. Кошелек не был создан (выполните пункт 7)"
        echo "2. Кошелек создан с другим keyring-backend"
        echo "3. Требуется пароль для доступа к keyring"
        echo ""
        echo "💡 Попробуйте:"
        echo "- Создать кошелек валидатора (пункт 7)"
        echo "- Добавить аккаунт в генезис (пункт 9)"
        echo "- Или использовать другой keyring-backend"
        echo ""
        
        read -p "Продолжить без проверки кошелька? (yes/no): " continue_anyway
        if [[ "$continue_anyway" != "yes" ]]; then
            echo "Операция отменена."
            cd ..
            pause
            return
        fi
        echo "⚠️ Продолжаем без проверки кошелька..."
    fi
    
    # Получаем moniker из config.toml или запрашиваем его
    read -p "Введите moniker (имя ноды): " moniker
    moniker=$(echo "$moniker" | tr -d '\r\n')
    echo "Moniker: $moniker"

    # Конверсия: 1 токен = 1000000 микроединиц (для правильного расчета)
    token_to_micro=1000000

    # Получаем текущую минимальную сумму для валидатора
    echo "🔍 Определение минимальной суммы для валидатора..."
    MIN_VALIDATOR_STAKE=$(get_min_validator_stake)
    SAFE_AMOUNT=$(suggest_safe_amount "$MIN_VALIDATOR_STAKE")
    
    echo "📊 Минимальная сумма для валидатора: $MIN_VALIDATOR_STAKE $coin_prefix"
    echo "🛡️ Рекомендуемая безопасная сумма: $SAFE_AMOUNT $coin_prefix"
    echo ""
    
    # Предлагаем пользователю обновить минимальную сумму если есть новая ошибка
    echo "❓ Если вы получили ошибку 'validator set is empty' с новым значением DefaultPowerReduction:"
    read -p "Хотите ввести текст ошибки для автоматического определения суммы? (y/n): " update_from_error
    
    if [[ "$update_from_error" =~ ^[yYдД]$ ]]; then
        echo ""
        echo "📋 Вставьте полный текст ошибки (нажмите Enter два раза для завершения):"
        error_text=""
        while IFS= read -r line; do
            [ -z "$line" ] && break
            error_text+="$line "
        done
        
        if [ ! -z "$error_text" ]; then
            if extracted_min=$(extract_min_from_error "$error_text"); then
                echo "✅ Извлечено новое минимальное значение: $extracted_min"
                echo "$extracted_min" > ~/.wasmd_min_stake
                MIN_VALIDATOR_STAKE="$extracted_min"
                SAFE_AMOUNT=$(suggest_safe_amount "$MIN_VALIDATOR_STAKE")
                echo "📊 Обновленная минимальная сумма: $MIN_VALIDATOR_STAKE $coin_prefix"
                echo "🛡️ Новая рекомендуемая сумма: $SAFE_AMOUNT $coin_prefix"
            else
                echo "⚠️ Не удалось извлечь значение из ошибки. Используем текущие настройки."
            fi
        fi
        echo ""
    fi

    # Запрос суммы для стейкинга с умными предложениями
    while true; do
        echo "💰 Варианты сумм для стейкинга:"
        echo "   1. Минимальная: $MIN_VALIDATOR_STAKE $coin_prefix"
        echo "   2. Безопасная: $SAFE_AMOUNT $coin_prefix (рекомендуется)"
        echo "   3. Ввести свою сумму"
        echo ""
        read -p "Выберите вариант (1-3): " amount_choice
        
        case $amount_choice in
            1)
                input_amount_token="$MIN_VALIDATOR_STAKE"
                echo "✅ Выбрана минимальная сумма: $input_amount_token $coin_prefix"
                break
                ;;
            2)
                input_amount_token="$SAFE_AMOUNT"
                echo "✅ Выбрана безопасная сумма: $input_amount_token $coin_prefix"
                break
                ;;
            3)
                echo ""
                read -p "Введите сумму для стейка валидатора (минимум $MIN_VALIDATOR_STAKE): " custom_amount
                custom_amount=$(echo "$custom_amount" | tr -d '\r\n')
                if [[ "$custom_amount" =~ ^[0-9]+$ ]]; then
                    if (( custom_amount < MIN_VALIDATOR_STAKE )); then
                        echo "❌ Сумма ($custom_amount) меньше минимума ($MIN_VALIDATOR_STAKE)!"
                        echo "💡 Используйте минимум $MIN_VALIDATOR_STAKE или больше"
                        continue
                    fi
                    input_amount_token="$custom_amount"
                    echo "✅ Принята сумма: $input_amount_token $coin_prefix"
                    break
                else
                    echo "❌ Введите только цифры!"
                    continue
                fi
                ;;
            *)
                echo "❌ Неверный выбор! Введите 1, 2 или 3"
                continue
                ;;
        esac
    done
    
    # Запрос минимального self-delegation (упрощенный)
    echo ""
    echo "💡 Для минимального самоделегирования рекомендуется использовать ту же сумму"
    read -p "Минимальная сумма самоделегирования (Enter = $input_amount_token): " min_self_delegation
    min_self_delegation=${min_self_delegation:-$input_amount_token}
    min_self_delegation=$(echo "$min_self_delegation" | tr -d '\r\n')
    
    if [[ "$min_self_delegation" =~ ^[0-9]+$ ]]; then
        if (( min_self_delegation < MIN_VALIDATOR_STAKE )); then
            echo "⚠️ Используем минимум: $MIN_VALIDATOR_STAKE"
            min_self_delegation=$MIN_VALIDATOR_STAKE
        fi
        if (( min_self_delegation > input_amount_token )); then
            echo "⚠️ Самоделегирование не может быть больше стейка. Используем: $input_amount_token"
            min_self_delegation=$input_amount_token
        fi
    else
        echo "⚠️ Используем значение по умолчанию: $input_amount_token"
        min_self_delegation=$input_amount_token
    fi
    
    # Формируем суммы с деноминацией
    amount_with_prefix="${input_amount_token}${coin_prefix}"

    # Вывод информации о команде
    echo "Создание генезис-транзакции для стейка валидатора от кошелька '$wallet_name' с суммой $input_amount_token $coin_prefix..."

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

    # Выполнение команды wasmd genesis gentx с детальной диагностикой
    echo ""
    echo "🔧 Создание генезис-транзакции..."
    echo "Команда: wasmd genesis gentx \"$wallet_name\" \"$amount_with_prefix\" \\"
    echo "  --chain-id \"$chain_id\" \\"
    echo "  --moniker \"$moniker\" \\"
    echo "  --commission-rate \"0.10\" \\"
    echo "  --commission-max-rate \"0.20\" \\"
    echo "  --commission-max-change-rate \"0.01\" \\"
    echo "  --min-self-delegation \"$min_self_delegation\" \\"
    echo "  --from \"$wallet_name\" \\"
    echo "  --keyring-backend \"$KEYRING_BACKEND\" \\"
    echo "  --home \"$HOME/.wasmd\""
    echo ""

    # Проверяем предварительные условия
    echo "🔍 Предварительная проверка:"
    
    # 1. Проверяем ключ
    echo "1. Проверка ключа '$wallet_name'..."
    if timeout 10s wasmd keys show "$wallet_name" --keyring-backend "$KEYRING_BACKEND" > /dev/null 2>&1; then
        key_address=$(timeout 10s wasmd keys show "$wallet_name" -a --keyring-backend "$KEYRING_BACKEND" 2>/dev/null)
        echo "   ✅ Ключ найден: $key_address"
    else
        echo "   ❌ Ключ '$wallet_name' не найден!"
        cd ..
        pause
        return
    fi
    
    # 2. Проверяем genesis.json
    echo "2. Проверка genesis.json..."
    if [ -f ~/.wasmd/config/genesis.json ]; then
        if jq '.' ~/.wasmd/config/genesis.json >/dev/null 2>&1; then
            echo "   ✅ Genesis.json валидный"
        else
            echo "   ❌ Genesis.json поврежден!"
            cd ..
            pause
            return
        fi
    else
        echo "   ❌ Genesis.json не найден!"
        cd ..
        pause
        return
    fi
    
    # 3. Проверяем аккаунт в genesis
    echo "3. Проверка аккаунта в genesis..."
    account_balance=$(jq -r ".app_state.bank.balances[] | select(.address == \"$key_address\") | .coins[0].amount" ~/.wasmd/config/genesis.json 2>/dev/null)
    if [ ! -z "$account_balance" ] && [ "$account_balance" != "null" ]; then
        echo "   ✅ Аккаунт найден с балансом: $account_balance"
        if (( account_balance >= input_amount_token )); then
            echo "   ✅ Баланс достаточен для стейкинга"
        else
            echo "   ❌ Недостаточный баланс! Есть: $account_balance, нужно: $input_amount_token"
            cd ..
            pause
            return
        fi
    else
        echo "   ❌ Аккаунт $key_address не найден в genesis!"
        echo "   💡 Сначала добавьте аккаунт через пункт 9"
        cd ..
        pause
        return
    fi
    
    # 4. Проверяем папку gentx
    echo "4. Проверка папки gentx..."
    gentx_dir=~/.wasmd/config/gentx
    if [ ! -d "$gentx_dir" ]; then
        echo "   ⚠️ Папка gentx не существует, создаем..."
        mkdir -p "$gentx_dir"
        if [ -d "$gentx_dir" ]; then
            echo "   ✅ Папка gentx создана: $gentx_dir"
        else
            echo "   ❌ Не удалось создать папку gentx!"
            cd ..
            pause
            return
        fi
    else
        echo "   ✅ Папка gentx существует: $gentx_dir"
    fi
    
    # Очищаем старые gentx файлы
    echo "5. Очистка старых gentx файлов..."
    old_gentx_count=$(find "$gentx_dir" -name "gentx-*.json" 2>/dev/null | wc -l)
    if [ "$old_gentx_count" -gt 0 ]; then
        echo "   🗑️ Найдено старых gentx файлов: $old_gentx_count"
        read -p "   Удалить старые gentx файлы? (y/n): " clean_old
        if [[ "$clean_old" =~ ^[yYдД]$ ]]; then
            rm -f "$gentx_dir"/gentx-*.json 2>/dev/null
            echo "   ✅ Старые gentx файлы удалены"
        fi
    else
        echo "   ✅ Старых gentx файлов нет"
    fi
    
    echo ""
    echo "🚀 Выполнение команды wasmd genesis gentx..."

    # Выполняем команду и сохраняем вывод
    gentx_output=$(wasmd genesis gentx "$wallet_name" "$amount_with_prefix" \
        --chain-id "$chain_id" \
        --moniker "$moniker" \
        --commission-rate "0.10" \
        --commission-max-rate "0.20" \
        --commission-max-change-rate "0.01" \
        --min-self-delegation "$min_self_delegation" \
        --from "$wallet_name" \
        --keyring-backend "$KEYRING_BACKEND" \
        --home "$HOME/.wasmd" 2>&1)
    
    gentx_exit_code=$?
    
    echo "📋 Вывод команды wasmd genesis gentx:"
    echo "$gentx_output"
    echo ""
    
    # Проверяем результат выполнения команды
    if [ $gentx_exit_code -ne 0 ]; then
        echo "❌ ОШИБКА: Команда wasmd genesis gentx завершилась с кодом $gentx_exit_code"
        echo ""
        echo "🔍 Анализ ошибок:"
        if echo "$gentx_output" | grep -q "insufficient funds"; then
            echo "   💰 Проблема: Недостаточно средств"
            echo "   💡 Решение: Увеличьте баланс аккаунта в genesis (пункт 9)"
        elif echo "$gentx_output" | grep -q "key not found"; then
            echo "   🔑 Проблема: Ключ не найден"
            echo "   💡 Решение: Проверьте имя ключа и keyring-backend"
        elif echo "$gentx_output" | grep -q "account does not exist"; then
            echo "   👤 Проблема: Аккаунт не существует в genesis"
            echo "   💡 Решение: Добавьте аккаунт через пункт 9"
        elif echo "$gentx_output" | grep -q "invalid chain-id"; then
            echo "   🔗 Проблема: Неправильный chain-id"
            echo "   💡 Решение: Проверьте chain-id в genesis.json"
        else
            echo "   ❓ Неизвестная ошибка"
        fi
        
        cd ..
        pause
        return
    fi
    
    echo "✅ Команда wasmd genesis gentx выполнена успешно!"
    
    # Детальная проверка созданных файлов
    echo ""
    echo "🔍 Проверка созданных gentx файлов..."
    
    # Ждем немного чтобы файлы записались
    sleep 2
    
    # Поиск файлов gentx
    gentx_files=$(find "$gentx_dir" -name "gentx-*.json" 2>/dev/null)
    gentx_count=$(echo "$gentx_files" | grep -c "gentx-" 2>/dev/null || echo "0")
    
    if [ "$gentx_count" -eq 0 ]; then
        echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Файлы gentx НЕ СОЗДАНЫ!"
        echo ""
        echo "🔍 Диагностика:"
        echo "   Папка gentx: $gentx_dir"
        echo "   Содержимое папки:"
        ls -la "$gentx_dir" 2>/dev/null || echo "   Папка недоступна"
        echo ""
        echo "🔧 Возможные причины:"
        echo "   1. Нет прав на запись в папку ~/.wasmd/config/gentx"
        echo "   2. Диск переполнен"
        echo "   3. Проблемы с wasmd"
        echo ""
        echo "💡 Попробуйте:"
        echo "   1. Проверить права: ls -la ~/.wasmd/config/"
        echo "   2. Создать файл вручную: touch ~/.wasmd/config/gentx/test.txt"
        echo "   3. Переинициализировать ноду (пункт 5)"
        
        cd ..
        pause
        return
    fi
    
    echo "✅ Создано gentx файлов: $gentx_count"
    
    # Проверяем содержимое gentx файлов
    echo ""
    echo "🔍 Анализ содержимого gentx файлов..."
    for gentx_file in $gentx_files; do
        echo "📄 Файл: $(basename "$gentx_file")"
        
        if [ -f "$gentx_file" ]; then
            file_size=$(stat -c%s "$gentx_file" 2>/dev/null || wc -c < "$gentx_file")
            echo "   📏 Размер: $file_size байт"
            
            if [ "$file_size" -eq 0 ]; then
                echo "   ❌ Файл пустой!"
                continue
            fi
            
            if jq '.' "$gentx_file" >/dev/null 2>&1; then
                echo "   ✅ JSON валидный"
                
                # Проверяем ключевые поля
                msg_type=$(jq -r '.body.messages[0]["@type"] // empty' "$gentx_file" 2>/dev/null)
                validator_addr=$(jq -r '.body.messages[0].validator_address // .body.messages[0].value.validator_address // empty' "$gentx_file" 2>/dev/null)
                delegator_addr=$(jq -r '.body.messages[0].delegator_address // .body.messages[0].value.delegator_address // empty' "$gentx_file" 2>/dev/null)
                amount_in_gentx=$(jq -r '.body.messages[0].value.amount // .body.messages[0].amount // empty' "$gentx_file" 2>/dev/null)
                
                echo "   📋 Содержимое:"
                echo "      Тип: $msg_type"
                echo "      Валидатор: $validator_addr"
                echo "      Делегатор: $delegator_addr"
                echo "      Сумма: $amount_in_gentx"
                
                if [ ! -z "$msg_type" ] && [ ! -z "$validator_addr" ] && [ ! -z "$amount_in_gentx" ]; then
                    echo "   ✅ Gentx файл содержит все необходимые данные"
                else
                    echo "   ❌ Gentx файл неполный!"
                fi
            else
                echo "   ❌ JSON невалидный!"
                echo "   📋 Первые 200 символов:"
                head -c 200 "$gentx_file" 2>/dev/null
            fi
        else
            echo "   ❌ Файл недоступен!"
        fi
        echo ""
    done
    
    # Сбор gentx автоматически с детальной диагностикой
    echo ""
    echo "🔧 Сбор генезис-транзакций (collect-gentxs)..."
    
    # Проверяем что у нас есть gentx файлы для сбора
    gentx_files_for_collect=$(find "$gentx_dir" -name "gentx-*.json" 2>/dev/null)
    gentx_count_for_collect=$(echo "$gentx_files_for_collect" | grep -c "gentx-" 2>/dev/null || echo "0")
    
    if [ "$gentx_count_for_collect" -eq 0 ]; then
        echo "❌ ОШИБКА: Нет gentx файлов для сбора!"
        cd ..
        pause
        return
    fi
    
    echo "📊 Найдено gentx файлов для сбора: $gentx_count_for_collect"
    echo "📁 Файлы:"
    for gentx_file in $gentx_files_for_collect; do
        echo "   - $(basename "$gentx_file")"
    done
    echo ""
    
    # Сохраняем состояние genesis.json ДО collect-gentxs
    echo "💾 Сохраняем текущее состояние genesis.json..."
    genesis_backup="$HOME/.wasmd/config/genesis_before_collect.json"
    cp ~/.wasmd/config/genesis.json "$genesis_backup" 2>/dev/null
    
    if command -v jq &> /dev/null; then
        validators_before=$(jq '.app_state.genutil.gen_txs | length' ~/.wasmd/config/genesis.json 2>/dev/null || echo "0")
        echo "📊 Валидаторов в genesis ДО collect-gentxs: $validators_before"
    fi
    
    # Выполняем collect-gentxs с захватом вывода
    echo "🚀 Выполнение команды: wasmd genesis collect-gentxs --home $HOME/.wasmd"
    collect_output=$(wasmd genesis collect-gentxs --home "$HOME/.wasmd" 2>&1)
    collect_exit_code=$?
    
    echo "📋 Вывод команды wasmd genesis collect-gentxs:"
    echo "$collect_output"
    echo ""
    
    if [ $collect_exit_code -ne 0 ]; then
        echo "❌ ОШИБКА: Команда collect-gentxs завершилась с кодом $collect_exit_code"
        echo ""
        echo "🔍 Анализ ошибок collect-gentxs:"
        if echo "$collect_output" | grep -q "failed to load application genesis state"; then
            echo "   🏗️ Проблема: Ошибка загрузки состояния genesis"
            echo "   💡 Решение: Проверьте структуру genesis.json"
        elif echo "$collect_output" | grep -q "validator set is empty"; then
            echo "   👥 Проблема: Набор валидаторов пустой"
            echo "   💡 Решение: Проблема с gentx файлами"
        elif echo "$collect_output" | grep -q "duplicate validator"; then
            echo "   🔁 Проблема: Дублирующийся валидатор"
            echo "   💡 Решение: Очистите старые gentx файлы"
        elif echo "$collect_output" | grep -q "insufficient power"; then
            echo "   ⚡ Проблема: Недостаточная сила валидатора"
            echo "   💡 Решение: Увеличьте сумму стейкинга"
        else
            echo "   ❓ Неизвестная ошибка collect-gentxs"
        fi
        
        echo ""
        echo "🔄 Восстанавливаем genesis.json из резервной копии..."
        if [ -f "$genesis_backup" ]; then
            cp "$genesis_backup" ~/.wasmd/config/genesis.json
            echo "✅ Genesis.json восстановлен"
        fi
        
        cd ..
        pause
        return
    fi
    
    echo "✅ Команда collect-gentxs выполнена успешно!"
    
    # Проверяем результат после collect-gentxs
    echo ""
    echo "🔍 Проверка результата collect-gentxs..."
    
    if command -v jq &> /dev/null; then
        # Проверяем валидаторов ПОСЛЕ collect-gentxs
        validators_after=$(jq '.app_state.genutil.gen_txs | length' ~/.wasmd/config/genesis.json 2>/dev/null || echo "0")
        echo "📊 Валидаторов в genesis ПОСЛЕ collect-gentxs: $validators_after"
        
        if [ "$validators_after" -gt 0 ]; then
            echo "✅ Валидаторы успешно добавлены в genesis.json!"
            
            # Показываем детали добавленных валидаторов
            echo ""
            echo "👥 Детали валидаторов в genesis.json:"
            for i in $(seq 0 $((validators_after - 1))); do
                echo "   Валидатор $((i + 1)):"
                validator_info=$(jq -r ".app_state.genutil.gen_txs[$i]" ~/.wasmd/config/genesis.json 2>/dev/null)
                
                if [ "$validator_info" != "null" ]; then
                    moniker=$(echo "$validator_info" | jq -r '.body.messages[0].description.moniker // .body.messages[0].value.description.moniker // "N/A"' 2>/dev/null)
                    amount=$(echo "$validator_info" | jq -r '.body.messages[0].value.amount // .body.messages[0].amount // "N/A"' 2>/dev/null)
                    delegator=$(echo "$validator_info" | jq -r '.body.messages[0].delegator_address // .body.messages[0].value.delegator_address // "N/A"' 2>/dev/null)
                    validator=$(echo "$validator_info" | jq -r '.body.messages[0].validator_address // .body.messages[0].value.validator_address // "N/A"' 2>/dev/null)
                    
                    echo "      Moniker: $moniker"
                    echo "      Сумма: $amount"
                    echo "      Делегатор: $delegator"
                    echo "      Валидатор: $validator"
                else
                    echo "      ❌ Не удалось получить информацию"
                fi
                echo ""
            done
            
            # Проверяем, что суммы достаточны
            echo "🔍 Проверка достаточности сумм стейкинга..."
            MIN_VALIDATOR_STAKE=$(get_min_validator_stake)
            
            for i in $(seq 0 $((validators_after - 1))); do
                amount=$(jq -r ".app_state.genutil.gen_txs[$i].body.messages[0].value.amount // .app_state.genutil.gen_txs[$i].body.messages[0].amount" ~/.wasmd/config/genesis.json 2>/dev/null)
                amount_value=$(echo "$amount" | sed 's/[^0-9]*//g')
                
                if [ -n "$amount_value" ] && (( amount_value >= MIN_VALIDATOR_STAKE )); then
                    echo "   ✅ Валидатор $((i + 1)): сумма $amount_value достаточна"
                else
                    echo "   ❌ Валидатор $((i + 1)): сумма $amount_value меньше минимума ($MIN_VALIDATOR_STAKE)"
                fi
            done
            
        else
            echo "❌ КРИТИЧЕСКАЯ ОШИБКА: После collect-gentxs валидаторов по-прежнему НЕТ!"
            echo ""
            echo "🔍 Возможные причины:"
            echo "   1. Gentx файлы содержат некорректные данные"
            echo "   2. Суммы стейкинга недостаточны"
            echo "   3. Проблемы с адресами валидаторов"
            echo "   4. Ошибки в структуре genesis.json"
            echo ""
            echo "💡 Диагностика:"
            
            # Сравниваем genesis до и после
            if [ -f "$genesis_backup" ]; then
                echo "   📊 Сравнение genesis до и после collect-gentxs..."
                validators_before_actual=$(jq '.app_state.genutil.gen_txs | length' "$genesis_backup" 2>/dev/null || echo "0")
                echo "   ДО: $validators_before_actual валидаторов"
                echo "   ПОСЛЕ: $validators_after валидаторов"
                
                if [ "$validators_before_actual" -eq "$validators_after" ]; then
                    echo "   ⚠️ Количество валидаторов не изменилось!"
                fi
            fi
            
            cd ..
            pause
            return
        fi
    else
        echo "⚠️ jq недоступен, детальная проверка невозможна"
    fi
    
    # Очищаем резервную копию
    rm -f "$genesis_backup" 2>/dev/null
    
    # Проверяем что в genesis.json есть валидаторы
    echo "Проверка genesis.json на наличие валидаторов..."
    validators_count=$(jq '.app_state.genutil.gen_txs | length' ~/.wasmd/config/genesis.json)
    if [ "$validators_count" -gt 0 ]; then
        echo "✅ В genesis.json найдено $validators_count валидаторов"
    else
        echo "❌ ВНИМАНИЕ: В genesis.json не найдено валидаторов! Это может вызвать ошибку при запуске."
    fi
    
    echo
    echo "ID вашей ноды:" 
    wasmd tendermint show-node-id
    echo
    echo "🎉 Валидатор успешно создан в genesis.json! Теперь можно запускать ноду."
    
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
    echo "=========================================================="
    echo "               НАСТРОЙКА BECH32 ПРЕФИКСА                 "
    echo "=========================================================="
    echo ""
    
    if [ ! -f "wasmd/Makefile" ]; then
        echo "❌ Makefile не найден в папке wasmd!"
        echo "Сначала клонируйте репозиторий (пункт 1)!"
        echo ""
        echo "Нажмите Enter для возврата в меню..."
        read
        return
    fi
    
    # Показываем текущий префикс
    echo "🔍 Проверка текущего префикса в Makefile..."
    current_prefix=$(grep -o "Bech32Prefix=[a-zA-Z0-9]*" wasmd/Makefile | cut -d= -f2 | head -1)
    if [ ! -z "$current_prefix" ]; then
        echo "Текущий префикс: $current_prefix"
    else
        echo "Префикс не установлен (используется дефолтный 'wasm')"
        current_prefix="wasm"
    fi
    echo ""
    
    read -p "Введите желаемый Bech32-префикс (например, fzp): " new_prefix_raw
    if [ -z "$new_prefix_raw" ]; then
        echo "❌ Префикс не может быть пустым!"
        echo "Нажмите Enter для возврата в меню..."
        read
        return
    fi
    
    # Используем функцию sanitize_input для очистки префикса от нежелательных символов
    new_prefix=$(sanitize_input "$new_prefix_raw")
    
    # Ещё раз проверяем, что после очистки префикс не пустой
    if [ -z "$new_prefix" ]; then
        echo "❌ Префикс после очистки от недопустимых символов стал пустым!"
        echo "Нажмите Enter для возврата в меню..."
        read
        return
    fi
    
    # Проверяем, что префикс содержит только допустимые символы (a-z, 0-9)
    if ! [[ "$new_prefix" =~ ^[a-z0-9]+$ ]]; then
        echo "❌ Ошибка: Префикс должен содержать только буквы в нижнем регистре (a-z) и цифры (0-9)!"
        echo "Нажмите Enter для возврата в меню..."
        read
        return
    fi
    
    echo ""
    echo "🔄 Установка префикса '$new_prefix' в Makefile..."
    
    # Создаем резервную копию Makefile
    cp wasmd/Makefile wasmd/Makefile.backup
    
    # Ищем и заменяем строку с Bech32Prefix
    if grep -q "Bech32Prefix=" wasmd/Makefile; then
        # Если строка уже есть - заменяем
        sed -i "s/Bech32Prefix=[a-zA-Z0-9]*/Bech32Prefix=${new_prefix}/g" wasmd/Makefile
    else
        # Если строки нет - добавляем к ldflags
        sed -i "s/-ldflags/-ldflags '-X github.com\/CosmWasm\/wasmd\/app.Bech32Prefix=${new_prefix}'/g" wasmd/Makefile
    fi
    
    # Проверяем результат
    if grep -q "Bech32Prefix=${new_prefix}" wasmd/Makefile; then
        echo "✅ Bech32-префикс успешно изменён на '${new_prefix}'!"
        echo ""
        echo "⚠️ ВАЖНО: Необходимо пересобрать wasmd для применения изменений!"
        echo "Выполните пункт 4 (Собрать и установить wasmd)"
        echo ""
        
        # Сохраняем префикс в переменную окружения
        export BECH32_PREFIX="$new_prefix"
        echo "export BECH32_PREFIX=$new_prefix" >> ~/.bashrc
        
    else
        echo "❌ Ошибка при изменении префикса!"
        echo "Восстанавливаем резервную копию..."
        cp wasmd/Makefile.backup wasmd/Makefile
    fi
    
    echo ""
    echo "Нажмите Enter для возврата в меню..."
    read
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
        
        # Проверяем наличие валидаторов в genesis.json
        if command -v jq &> /dev/null; then
            echo "Проверка genesis.json на наличие валидаторов..."
            validators_count=$(jq '.app_state.genutil.gen_txs | length' "$GENESIS_JSON" 2>/dev/null || echo "0")
            echo "Найдено валидаторов в genesis.json: $validators_count"
            
            if [ "$validators_count" -eq 0 ]; then
                echo "❌ КРИТИЧЕСКАЯ ОШИБКА: В genesis.json не найдено валидаторов!"
                echo "Это вызовет ошибку 'validator set is empty after InitGenesis' при запуске ноды."
                echo ""
                echo "Для исправления выполните следующие шаги:"
                echo "1. Создайте ключ валидатора (пункт 7)"
                echo "2. Добавьте аккаунт в генезис (пункт 9)"
                echo "3. Создайте валидатора в генезисе (пункт 10)"
                echo ""
                read -p "Хотите автоматически исправить genesis.json? (y/n): " auto_fix
                if [[ "$auto_fix" == "y" || "$auto_fix" == "Y" ]]; then
                    echo "Для автоматического исправления нужно выполнить пункты 7-9-10 в правильном порядке."
                    echo "Сначала завершите настройку через главное меню."
                fi
            else
                echo "✅ В genesis.json найдено $validators_count валидаторов - это нормально!"
            fi
        fi
        
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
    echo "=========================================================="
    echo "              ПРОВЕРКА СТАТУСА СЕРВИСА WASMD             "
    echo "=========================================================="
    
    echo "1. Проверка статуса сервиса wasmd..."
    
    # Проверяем существование сервиса
    if systemctl list-unit-files | grep -q "wasmd.service"; then
        echo "✅ Сервис wasmd.service найден"
        echo ""
        echo "📊 Статус сервиса:"
        sudo systemctl status wasmd --no-pager --lines=5
        
        echo ""
        echo "🔄 Состояние сервиса:"
        if systemctl is-active --quiet wasmd; then
            echo "   ✅ Активен (запущен)"
        else
            echo "   ❌ Не активен (остановлен)"
        fi
        
        if systemctl is-enabled --quiet wasmd; then
            echo "   ✅ Включен в автозагрузку"
        else
            echo "   ⚠️ Не включен в автозагрузку"
        fi
        
        echo ""
        echo "📋 Последние 10 строк логов:"
        sudo journalctl -u wasmd -n 10 --no-pager || echo "Логи недоступны"
        
    else
        echo "❌ Сервис wasmd.service НЕ НАЙДЕН!"
        echo ""
        echo "🔧 Возможные причины:"
        echo "   - Сервис не был создан (не выполнен пункт 13)"
        echo "   - Сервис был удален"
        echo "   - Ошибка при создании сервиса"
        echo ""
        echo "💡 Рекомендации:"
        echo "   1. Выполните пункт 13 'Создать systemd-сервис'"
        echo "   2. Или запускайте ноду вручную (пункт 12)"
        echo ""
        echo "🔍 Проверка процессов wasmd:"
        if pgrep -f wasmd > /dev/null; then
            echo "   ✅ Найдены запущенные процессы wasmd:"
            pgrep -f wasmd | head -5
        else
            echo "   ❌ Процессы wasmd не найдены"
        fi
    fi
    
    echo ""
    echo "=========================================================="
    echo "Нажмите Enter для возврата в меню..."
    read
}

function test_run() {
    echo "Запуск wasmd в тестовом режиме (нажмите Ctrl+C для выхода)..."
    cd "$(dirname "$(which wasmd)")" 2>/dev/null || cd ~
    wasmd start
    cd - > /dev/null
    pause
}

function diagnose_node() {
    echo "=========================================================="
    echo "                 ДИАГНОСТИКА НОДЫ WASMD                  "
    echo "=========================================================="
    
    # Проверяем установку wasmd
    echo "1. Проверка установки wasmd..."
    if command -v wasmd &> /dev/null; then
        echo "✅ wasmd установлен: $(which wasmd)"
        echo "   Версия: $(wasmd version 2>/dev/null || echo 'Не удалось получить версию')"
    else
        echo "❌ wasmd не найден! Выполните пункт 4 (Собрать и установить wasmd)"
    fi
    
    echo ""
    echo "2. Проверка конфигурационных файлов..."
    
    # Проверяем genesis.json
    GENESIS_JSON="/root/.wasmd/config/genesis.json"
    if [ -f "$GENESIS_JSON" ]; then
        echo "✅ Genesis.json найден"
        if command -v jq &> /dev/null; then
            validators_count=$(jq '.app_state.genutil.gen_txs | length' "$GENESIS_JSON" 2>/dev/null || echo "0")
            echo "   Валидаторов в genesis: $validators_count"
            if [ "$validators_count" -eq 0 ]; then
                echo "   ❌ ПРОБЛЕМА: Нет валидаторов в genesis.json!"
                echo "   Это вызывает ошибку 'validator set is empty after InitGenesis'"
                echo "   Решение: Выполните пункты 7-9-10 для создания валидатора"
            else
                echo "   ✅ Валидаторы найдены"
            fi
            
            # Проверяем chain-id
            chain_id=$(jq -r '.chain_id' "$GENESIS_JSON" 2>/dev/null || echo "unknown")
            echo "   Chain ID: $chain_id"
        else
            echo "   ⚠️ jq не установлен, подробная проверка недоступна"
        fi
    else
        echo "❌ Genesis.json не найден! Выполните пункт 5 (Инициализировать узел)"
    fi
    
    # Проверяем config.toml
    CONFIG_TOML="/root/.wasmd/config/config.toml"
    if [ -f "$CONFIG_TOML" ]; then
        echo "✅ Config.toml найден"
    else
        echo "❌ Config.toml не найден! Выполните пункт 5 (Инициализировать узел)"
    fi
    
    # Проверяем app.toml
    APP_TOML="/root/.wasmd/config/app.toml"
    if [ -f "$APP_TOML" ]; then
        echo "✅ App.toml найден"
    else
        echo "❌ App.toml не найден! Выполните пункт 5 (Инициализировать узел)"
    fi
    
    echo ""
    echo "3. Проверка ключей..."
    if command -v wasmd &> /dev/null; then
        KEYRING_BACKEND=$(detect_keyring_backend)
        echo "   Keyring backend: $KEYRING_BACKEND"
        
        keys_count=$(timeout 10s wasmd keys list --keyring-backend "$KEYRING_BACKEND" 2>/dev/null | wc -l)
        if [ "$keys_count" -gt 0 ]; then
            echo "✅ Найдено ключей: $keys_count"
            echo "   Список ключей:"
            timeout 10s wasmd keys list --keyring-backend "$KEYRING_BACKEND" 2>/dev/null | sed 's/^/     /' || echo "     Не удалось получить список"
        else
            echo "❌ Ключи не найдены! Выполните пункт 7 (Создать ключ валидатора)"
            echo "   Попробуйте разные keyring-backend:"
            echo "   - wasmd keys list --keyring-backend os"
            echo "   - wasmd keys list --keyring-backend test"
        fi
    fi
    
    echo ""
    echo "4. Проверка статуса ноды..."
    if command -v wasmd &> /dev/null; then
        if wasmd status &>/dev/null; then
            echo "✅ Нода отвечает"
            node_id=$(wasmd tendermint show-node-id 2>/dev/null || echo "Не удалось получить")
            echo "   Node ID: $node_id"
        else
            echo "❌ Нода не отвечает или не запущена"
            echo "   Попробуйте запустить ноду (пункт 12) или проверьте логи (пункт 19)"
        fi
    fi
    
    echo ""
    echo "5. Проверка портов..."
    if command -v netstat &> /dev/null || command -v ss &> /dev/null; then
        echo "Проверка используемых портов:"
        if command -v ss &> /dev/null; then
            ss -tlnp | grep -E ':(26656|26657|1317|9090)' | sed 's/^/   /' || echo "   Порты wasmd не используются"
        else
            netstat -tlnp | grep -E ':(26656|26657|1317|9090)' | sed 's/^/   /' || echo "   Порты wasmd не используются"
        fi
    else
        echo "⚠️ netstat/ss не установлены, проверка портов недоступна"
    fi
    
    echo ""
    echo ""
    echo "6. Проверка Bech32 префиксов..."
    
    # Проверяем соответствие префиксов
    if [ -f "$GENESIS_JSON" ] && command -v jq &> /dev/null; then
        # Получаем префикс из genesis.json
        genesis_address=$(jq -r '.. | strings | select(test("^[a-z]+1[a-z0-9]{38}$"))' "$GENESIS_JSON" 2>/dev/null | head -1)
        if [ ! -z "$genesis_address" ]; then
            genesis_prefix=$(echo "$genesis_address" | cut -d1 -f1)
            echo "   Префикс в genesis.json: $genesis_prefix"
            
            # Получаем префикс wasmd
            if command -v wasmd &> /dev/null; then
                test_key="test_prefix_check"
                if wasmd keys add "$test_key" --keyring-backend test --output json 2>/dev/null | grep -q '"address"'; then
                    wasmd_prefix=$(wasmd keys show "$test_key" -a --keyring-backend test 2>/dev/null | cut -d1 -f1)
                    wasmd keys delete "$test_key" --keyring-backend test -y 2>/dev/null
                    echo "   Префикс wasmd: $wasmd_prefix"
                    
                    if [ "$genesis_prefix" != "$wasmd_prefix" ]; then
                        echo "   ❌ ПРОБЛЕМА: Несоответствие префиксов!"
                        echo "   Решение: используйте пункт 26 (Исправить ошибку Bech32 префикса)"
                    else
                        echo "   ✅ Префиксы совпадают"
                    fi
                else
                    echo "   ⚠️ Не удалось проверить префикс wasmd"
                fi
            else
                echo "   ❌ wasmd не установлен"
            fi
        else
            echo "   ⚠️ Адреса в genesis.json не найдены"
        fi
    else
        echo "   ⚠️ Проверка недоступна (нет genesis.json или jq)"
    fi
    
    echo ""
    echo "7. Рекомендации по исправлению:"
    echo "   - Если нет валидаторов в genesis: выполните пункты 7→9→10"
    echo "   - Если ошибка Bech32 префикса: используйте пункт 26"
    echo "   - Если ошибка при старте: проверьте логи (пункт 20)"
    echo "   - Если проблемы с файлами: используйте пункт 24 (Исправить файлы)"
    echo "   - Для полной очистки: используйте пункт 25 (Очистить конфигурацию)"
    echo "   - Для solo ноды: используйте пункты 1-13 по порядку"
    echo "   - Для подключения к сети: используйте пункт 15"
    
    echo ""
    echo "=========================================================="
    echo "Нажмите Enter для возврата в меню..."
    read
}

function clean_wasmd_config() {
    echo "=========================================================="
    echo "                 ОЧИСТКА КОНФИГУРАЦИИ WASMD              "
    echo "=========================================================="
    
    WASMD_DIR="/root/.wasmd"
    
    # Проверяем, существует ли папка
    if [ ! -d "$WASMD_DIR" ]; then
        echo "✅ Папка $WASMD_DIR не найдена - очистка не требуется."
        pause
        return
    fi
    
    # Показываем что будет удалено
    echo "⚠️  ВНИМАНИЕ! Эта операция удалит ВСЕ данные wasmd:"
    echo ""
    echo "📁 Будет удалено:"
    echo "   - Все конфигурационные файлы (config.toml, app.toml, genesis.json)"
    echo "   - Все ключи валидаторов и кошельков"
    echo "   - Всю базу данных блокчейна"
    echo "   - Все настройки сети"
    echo ""
    echo "🔍 Текущий размер папки:"
    du -sh "$WASMD_DIR" 2>/dev/null || echo "   Не удалось определить размер"
    
    if [ -f "$WASMD_DIR/config/genesis.json" ] && command -v jq &> /dev/null; then
        echo ""
        echo "📊 Информация о текущей конфигурации:"
        chain_id=$(jq -r '.chain_id' "$WASMD_DIR/config/genesis.json" 2>/dev/null || echo "unknown")
        validators_count=$(jq '.app_state.genutil.gen_txs | length' "$WASMD_DIR/config/genesis.json" 2>/dev/null || echo "0")
        echo "   Chain ID: $chain_id"
        echo "   Валидаторов: $validators_count"
    fi
    
    echo ""
    echo "❌ ЭТО ДЕЙСТВИЕ НЕЛЬЗЯ ОТМЕНИТЬ!"
    echo ""
    
    # Первое подтверждение
    read -p "Вы уверены, что хотите удалить ВСЕ данные wasmd? (yes/no): " first_confirm
    if [[ "$first_confirm" != "yes" ]]; then
        echo "Операция отменена."
        pause
        return
    fi
    
    # Второе подтверждение
    echo ""
    echo "🔴 ФИНАЛЬНОЕ ПОДТВЕРЖДЕНИЕ:"
    read -p "Введите 'DELETE' (заглавными буквами) для подтверждения: " final_confirm
    if [[ "$final_confirm" != "DELETE" ]]; then
        echo "Операция отменена."
        pause
        return
    fi
    
    echo ""
    echo "🔄 Выполняется очистка..."
    
    # Останавливаем сервис wasmd если он запущен
    echo "1. Остановка сервиса wasmd..."
    if systemctl is-active --quiet wasmd 2>/dev/null; then
        echo "   Останавливаем systemd сервис..."
        sudo systemctl stop wasmd 2>/dev/null || echo "   Не удалось остановить сервис (возможно, не настроен)"
    else
        echo "   Сервис wasmd не запущен или не настроен"
    fi
    
    # Убиваем все процессы wasmd (кроме скриптов)
    echo "2. Завершение всех процессов wasmd..."
    
    # Ищем процессы wasmd, исключая скрипты bash
    WASMD_PIDS=$(pgrep -f "wasmd" | xargs -I {} sh -c 'ps -p {} -o pid,comm --no-headers | grep -v "bash\|sh" | awk "{print \$1}"' 2>/dev/null | tr '\n' ' ')
    
    if [ ! -z "$WASMD_PIDS" ]; then
        echo "   Найдены процессы wasmd: $WASMD_PIDS"
        echo "   Завершаем процессы..."
        
        # Сначала мягко завершаем
        for pid in $WASMD_PIDS; do
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                echo "   Завершаем процесс $pid..."
                kill "$pid" 2>/dev/null
            fi
        done
        
        sleep 3
        
        # Проверяем что осталось и принудительно завершаем
        REMAINING_PIDS=$(pgrep -f "wasmd" | xargs -I {} sh -c 'ps -p {} -o pid,comm --no-headers | grep -v "bash\|sh" | awk "{print \$1}"' 2>/dev/null | tr '\n' ' ')
        if [ ! -z "$REMAINING_PIDS" ]; then
            echo "   Принудительное завершение оставшихся процессов: $REMAINING_PIDS"
            for pid in $REMAINING_PIDS; do
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                    kill -9 "$pid" 2>/dev/null
                fi
            done
        fi
        
        echo "   ✅ Процессы wasmd завершены"
    else
        echo "   ✅ Активные процессы wasmd не найдены"
    fi
    
    # Удаляем папку
    echo "3. Удаление конфигурации..."
    
    # Дополнительная пауза для завершения всех процессов
    echo "   Ожидание завершения всех операций..."
    sleep 2
    
    # Проверяем что папка существует перед удалением
    if [ -d "$WASMD_DIR" ]; then
        echo "   Удаляем папку $WASMD_DIR..."
        
        # Пытаемся удалить обычным способом
        if rm -rf "$WASMD_DIR" 2>/dev/null; then
            echo "   ✅ Удаление выполнено успешно"
        else
            echo "   ⚠️ Обычное удаление не удалось, пробуем с sudo..."
            if sudo rm -rf "$WASMD_DIR" 2>/dev/null; then
                echo "   ✅ Удаление с sudo выполнено успешно"
            else
                echo "   ❌ Не удалось удалить даже с sudo"
            fi
        fi
    else
        echo "   ⚠️ Папка $WASMD_DIR уже не существует"
    fi
    
    # Проверяем результат
    echo ""
    echo "4. Проверка результата..."
    if [ ! -d "$WASMD_DIR" ]; then
        echo ""
        echo "✅ УСПЕШНО! Конфигурация wasmd полностью удалена."
        echo ""
        echo "🔄 Для создания новой конфигурации выполните:"
        echo "   5. Инициализировать узел wasmd"
        echo "   6. Настроить конфигурацию wasmd"
        echo "   7-9-10. Создать валидатора"
        echo "   12. Запустить ноду"
    else
        echo ""
        echo "❌ ОШИБКА! Не удалось полностью удалить конфигурацию."
        echo ""
        echo "🔧 Возможные причины:"
        echo "   - Недостаточно прав для удаления"
        echo "   - Файлы заблокированы запущенными процессами"
        echo "   - Файловая система защищена от записи"
        echo ""
        echo "💡 Попробуйте:"
        echo "   1. Завершить все процессы: sudo pkill -9 wasmd"
        echo "   2. Удалить вручную: sudo rm -rf $WASMD_DIR"
        echo "   3. Перезагрузить систему и повторить"
        echo ""
        echo "📁 Содержимое папки:"
        ls -la "$WASMD_DIR" 2>/dev/null || echo "   Не удалось просмотреть содержимое"
    fi
    
    echo ""
    echo "=========================================================="
    echo "Нажмите Enter для возврата в меню..."
    read
}

function fix_bech32_prefix_error() {
    echo "=========================================================="
    echo "           ИСПРАВЛЕНИЕ ОШИБКИ BECH32 ПРЕФИКСА           "
    echo "=========================================================="
    echo ""
    
    echo "🔍 Диагностика проблемы с Bech32 префиксом..."
    
    # Проверяем genesis.json
    GENESIS_JSON="/root/.wasmd/config/genesis.json"
    if [ ! -f "$GENESIS_JSON" ]; then
        echo "❌ Genesis.json не найден!"
        echo "Нажмите Enter для возврата в меню..."
        read
        return
    fi
    
    # Проверяем какие префиксы используются в genesis.json
    echo "Анализ адресов в genesis.json..."
    if command -v jq &> /dev/null; then
        # Ищем все адреса в genesis.json
        addresses=$(jq -r '.. | strings | select(test("^[a-z]+1[a-z0-9]{38}$"))' "$GENESIS_JSON" 2>/dev/null | head -5)
        if [ ! -z "$addresses" ]; then
            echo "Найденные адреса:"
            echo "$addresses" | sed 's/^/   /'
            
            # Определяем префикс
            first_address=$(echo "$addresses" | head -1)
            used_prefix=$(echo "$first_address" | cut -d1 -f1)
            echo ""
            echo "Используемый префикс в genesis.json: $used_prefix"
        else
            echo "⚠️ Адреса в genesis.json не найдены"
            used_prefix="unknown"
        fi
    else
        echo "⚠️ jq не установлен, ручная диагностика..."
        used_prefix="unknown"
    fi
    
    # Проверяем какой префикс ожидает wasmd
    echo ""
    echo "Проверка префикса в wasmd..."
    
    # Попробуем создать тестовый ключ чтобы узнать префикс
    test_key="test_key_$(date +%s)"
    cd wasmd 2>/dev/null || cd .
    
    if wasmd keys add "$test_key" --keyring-backend test --output json 2>/dev/null | grep -q '"address"'; then
        expected_prefix=$(wasmd keys show "$test_key" -a --keyring-backend test 2>/dev/null | cut -d1 -f1)
        wasmd keys delete "$test_key" --keyring-backend test -y 2>/dev/null
        echo "Ожидаемый префикс wasmd: $expected_prefix"
    else
        echo "⚠️ Не удалось определить префикс wasmd"
        expected_prefix="wasm"
    fi
    
    cd - > /dev/null 2>&1
    
    echo ""
    echo "📋 ДИАГНОСТИКА:"
    echo "   Genesis.json использует: $used_prefix"
    echo "   Wasmd ожидает: $expected_prefix"
    
    if [ "$used_prefix" != "$expected_prefix" ]; then
        echo ""
        echo "❌ НАЙДЕНО НЕСООТВЕТСТВИЕ ПРЕФИКСОВ!"
        echo ""
        echo "🔧 Варианты решения:"
        echo "1. Пересобрать wasmd с префиксом '$used_prefix'"
        echo "2. Полная переинициализация с префиксом '$expected_prefix'"
        echo "3. Вернуться в меню"
        echo ""
        read -p "Ваш выбор (1-3): " fix_choice
        
        case $fix_choice in
            1)
                echo ""
                echo "🔄 Пересборка wasmd с префиксом '$used_prefix'..."
                
                # Устанавливаем префикс в Makefile
                if [ -f "wasmd/Makefile" ]; then
                    cp wasmd/Makefile wasmd/Makefile.backup
                    
                    if grep -q "Bech32Prefix=" wasmd/Makefile; then
                        sed -i "s/Bech32Prefix=[a-zA-Z0-9]*/Bech32Prefix=${used_prefix}/g" wasmd/Makefile
                    else
                        sed -i "s/-ldflags/-ldflags '-X github.com\/CosmWasm\/wasmd\/app.Bech32Prefix=${used_prefix}'/g" wasmd/Makefile
                    fi
                    
                    echo "Префикс установлен в Makefile. Запускаем сборку..."
                    
                    cd wasmd
                    if make install; then
                        echo ""
                        echo "✅ Wasmd успешно пересобран с префиксом '$used_prefix'!"
                        echo "Теперь можно запускать ноду (пункт 12)"
                    else
                        echo ""
                        echo "❌ Ошибка при сборке wasmd!"
                        echo "Восстанавливаем Makefile..."
                        cp Makefile.backup Makefile
                    fi
                    cd ..
                else
                    echo "❌ Makefile не найден!"
                fi
                ;;
            2)
                echo ""
                echo "🔄 Полная переинициализация..."
                echo "Будет выполнена очистка конфигурации и создание новой с правильным префиксом."
                echo ""
                read -p "Продолжить? (yes/no): " confirm_reinit
                if [[ "$confirm_reinit" == "yes" ]]; then
                    # Очищаем конфигурацию
                    rm -rf ~/.wasmd 2>/dev/null
                    echo "✅ Конфигурация очищена"
                    echo ""
                    echo "💡 Теперь выполните по порядку:"
                    echo "   3. Установить Bech32-префикс ($expected_prefix)"
                    echo "   4. Собрать и установить wasmd"
                    echo "   5-6. Инициализировать и настроить"
                    echo "   7-9-10. Создать валидатора"
                fi
                ;;
            3)
                echo "Операция отменена"
                ;;
            *)
                echo "Неверный выбор"
                ;;
        esac
    else
        echo ""
        echo "✅ Префиксы совпадают! Проблема не в префиксе."
        echo "Возможно проблема в другом. Проверьте логи (пункт 20)"
    fi
    
    echo ""
    echo "Нажмите Enter для возврата в меню..."
    read
}

function quick_clean_wasmd() {
    echo "=========================================================="
    echo "              БЫСТРАЯ ОЧИСТКА WASMD (упрощенная)        "
    echo "=========================================================="
    
    WASMD_DIR="/root/.wasmd"
    
    echo "⚠️ Быстрая очистка - удаляет только файлы конфигурации"
    echo "Процессы wasmd нужно будет остановить вручную."
    echo ""
    
    if [ ! -d "$WASMD_DIR" ]; then
        echo "✅ Папка $WASMD_DIR не найдена - очистка не требуется."
        echo "Нажмите Enter для возврата в меню..."
        read
        return
    fi
    
    echo "📁 Найдена папка: $WASMD_DIR"
    du -sh "$WASMD_DIR" 2>/dev/null || echo "Размер не определен"
    echo ""
    
    read -p "Удалить папку ~/.wasmd? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Операция отменена."
        echo "Нажмите Enter для возврата в меню..."
        read
        return
    fi
    
    echo ""
    echo "Удаление папки..."
    
    if sudo rm -rf "$WASMD_DIR" 2>/dev/null; then
        echo "✅ Папка успешно удалена!"
    else
        echo "❌ Не удалось удалить папку."
        echo "Попробуйте вручную: sudo rm -rf $WASMD_DIR"
    fi
    
    echo ""
    echo "💡 Не забудьте остановить процессы wasmd:"
    echo "   sudo pkill -9 wasmd"
    echo "   sudo systemctl stop wasmd"
    
    echo ""
    echo "Нажмите Enter для возврата в меню..."
    read
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
        echo "Добавьте её в файл ~/.wasmd/config/config.toml в параметр persistent_peers"
    else
        echo "⚠️ Не было добавлено ни одной ноды"
    fi
    
    pause
}

function diagnose_genesis_problems() {
    echo "=========================================================="
    echo "             ДИАГНОСТИКА ПРОБЛЕМ GENESIS.JSON            "
    echo "=========================================================="
    echo ""
    
    GENESIS_FILE="$HOME/.wasmd/config/genesis.json"
    
    # Проверка существования файла
    if [ ! -f "$GENESIS_FILE" ]; then
        echo "❌ КРИТИЧЕСКАЯ ОШИБКА: Файл genesis.json не найден!"
        echo "Путь: $GENESIS_FILE"
        echo ""
        echo "💡 Решение: Выполните пункт 5 (Инициализировать ноду)"
        pause
        return
    fi
    
    echo "✅ Файл genesis.json найден: $GENESIS_FILE"
    
    # Проверка наличия jq
    if ! command -v jq &> /dev/null; then
        echo "❌ ОШИБКА: Утилита 'jq' не найдена!"
        echo "💡 Решение: Установите jq командой: sudo apt install jq"
        pause
        return
    fi
    
    # Проверка валидности JSON
    if ! jq '.' "$GENESIS_FILE" >/dev/null 2>&1; then
        echo "❌ ОШИБКА: genesis.json содержит некорректный JSON!"
        echo "💡 Решение: Переинициализируйте ноду (пункт 5)"
        pause
        return
    fi
    
    echo "✅ JSON валидный"
    
    # Проверка наличия валидаторов
    validators_count=$(jq '.app_state.genutil.gen_txs | length' "$GENESIS_FILE" 2>/dev/null || echo "0")
    echo "🔍 Количество валидаторов в genesis.json: $validators_count"
    
    if [ "$validators_count" -eq 0 ]; then
        echo "❌ КРИТИЧЕСКАЯ ОШИБКА: В genesis.json НЕТ валидаторов!"
        echo "Это вызывает ошибку: 'validator set is empty after InitGenesis'"
        echo ""
        echo "💡 Решение:"
        echo "1. Создайте ключ валидатора (пункт 7)"
        MIN_VALIDATOR_STAKE=$(get_min_validator_stake)
        echo "2. Добавьте аккаунт в genesis (пункт 9) с суммой >= $MIN_VALIDATOR_STAKE"
        echo "3. Создайте валидатора в genesis (пункт 10)"
        echo ""
    else
        echo "✅ Валидаторы найдены: $validators_count"
        
        # Проверяем каждого валидатора
        for i in $(seq 0 $((validators_count - 1))); do
            echo ""
            echo "--- Валидатор $((i + 1)) ---"
            
            # Извлекаем информацию о валидаторе
            validator_info=$(jq -r ".app_state.genutil.gen_txs[$i]" "$GENESIS_FILE" 2>/dev/null)
            
            if [ "$validator_info" != "null" ]; then
                # Получаем сумму стейкинга
                amount=$(echo "$validator_info" | jq -r '.body.messages[0].value.amount // .body.messages[0].amount // "N/A"' 2>/dev/null)
                delegator_address=$(echo "$validator_info" | jq -r '.body.messages[0].value.delegator_address // .body.messages[0].delegator_address // "N/A"' 2>/dev/null)
                validator_address=$(echo "$validator_info" | jq -r '.body.messages[0].value.validator_address // .body.messages[0].validator_address // "N/A"' 2>/dev/null)
                
                echo "Делегатор: $delegator_address"
                echo "Валидатор: $validator_address"
                echo "Сумма стейкинга: $amount"
                
                # Проверяем сумму стейкинга
                if [ "$amount" != "N/A" ]; then
                    # Извлекаем числовое значение
                    amount_value=$(echo "$amount" | sed 's/[^0-9]*//g')
                    MIN_VALIDATOR_STAKE=$(get_min_validator_stake)
                    if [ -n "$amount_value" ] && (( amount_value >= MIN_VALIDATOR_STAKE )); then
                        echo "✅ Сумма стейкинга достаточна"
                    else
                        echo "❌ ОШИБКА: Сумма стейкинга ($amount_value) меньше минимума ($MIN_VALIDATOR_STAKE)"
                        echo "💡 Решение: Пересоздайте валидатора с большей суммой"
                        echo "💡 Или обновите минимальную сумму через пункт 19.7"
                    fi
                else
                    echo "❌ ОШИБКА: Не удалось получить сумму стейкинга"
                fi
            else
                echo "❌ ОШИБКА: Не удалось получить информацию о валидаторе"
            fi
        done
    fi
    
    # Проверка аккаунтов в genesis
    echo ""
    echo "🔍 Проверка аккаунтов в genesis.json..."
    accounts_count=$(jq '.app_state.bank.balances | length' "$GENESIS_FILE" 2>/dev/null || echo "0")
    echo "Количество аккаунтов: $accounts_count"
    
    if [ "$accounts_count" -eq 0 ]; then
        echo "❌ ВНИМАНИЕ: В genesis.json НЕТ аккаунтов!"
        echo "💡 Решение: Добавьте аккаунт в genesis (пункт 9)"
    else
        echo "✅ Аккаунты найдены: $accounts_count"
        
        # Показываем аккаунты
        for i in $(seq 0 $((accounts_count - 1))); do
            address=$(jq -r ".app_state.bank.balances[$i].address" "$GENESIS_FILE" 2>/dev/null)
            amount=$(jq -r ".app_state.bank.balances[$i].coins[0].amount" "$GENESIS_FILE" 2>/dev/null)
            denom=$(jq -r ".app_state.bank.balances[$i].coins[0].denom" "$GENESIS_FILE" 2>/dev/null)
            
            echo "Аккаунт $((i + 1)): $address"
            echo "  Баланс: $amount $denom"
            
            MIN_VALIDATOR_STAKE=$(get_min_validator_stake)
            if [ -n "$amount" ] && (( amount >= MIN_VALIDATOR_STAKE )); then
                echo "  ✅ Баланс достаточен для валидатора"
            else
                echo "  ❌ Баланс недостаточен для валидатора (минимум $MIN_VALIDATOR_STAKE)"
            fi
        done
    fi
    
    # Проверка bond_denom
    echo ""
    echo "🔍 Проверка bond_denom (валютной деноминации)..."
    bond_denom=$(jq -r '.app_state.staking.params.bond_denom' "$GENESIS_FILE" 2>/dev/null)
    echo "Bond denom: $bond_denom"
    
    if [ -z "$bond_denom" ] || [ "$bond_denom" = "null" ]; then
        echo "❌ ОШИБКА: bond_denom не установлен!"
        echo "💡 Решение: Выполните пункт 6 (Настроить конфигурацию)"
    else
        echo "✅ Bond denom корректный"
    fi
    
    echo ""
    echo "=========================================================="
    echo "                 ИТОГОВАЯ ДИАГНОСТИКА                    "
    echo "=========================================================="
    
    # Итоговая оценка
    if [ "$validators_count" -gt 0 ] && [ "$accounts_count" -gt 0 ]; then
        echo "✅ Genesis.json выглядит корректно для запуска ноды"
    else
        echo "❌ Genesis.json НЕ готов для запуска ноды"
        echo ""
        echo "Следующие шаги:"
        if [ "$validators_count" -eq 0 ]; then
            echo "1. Создайте валидатора (пункт 7 → 9 → 10)"
        fi
        if [ "$accounts_count" -eq 0 ]; then
            echo "2. Добавьте аккаунт в genesis (пункт 9)"
        fi
    fi
    
    echo ""
    pause
}

function update_min_stake_value() {
    echo "=========================================================="
    echo "         ОБНОВЛЕНИЕ МИНИМАЛЬНОЙ СУММЫ ДЛЯ ВАЛИДАТОРА     "
    echo "=========================================================="
    echo ""
    
    echo "🔍 Текущие настройки:"
    current_min=$(get_min_validator_stake)
    echo "   Текущая минимальная сумма: $current_min"
    
    if [ -f ~/.wasmd_min_stake ]; then
        saved_min=$(cat ~/.wasmd_min_stake)
        echo "   Сохраненная сумма: $saved_min"
    else
        echo "   Сохраненная сумма: не установлена"
    fi
    
    echo ""
    echo "Если вы получили ошибку типа:"
    echo "'validator set is empty after InitGenesis, please ensure at least one validator"
    echo "is initialized with a delegation greater than or equal to the DefaultPowerReduction ({ЧИСЛО})'"
    echo ""
    echo "Выберите способ обновления:"
    echo "1. Ввести новое значение вручную"
    echo "2. Извлечь значение из текста ошибки"
    echo "3. Использовать актуальное значение (824639634176)"
    echo "4. Автоматически определить из системы"
    echo "5. Сбросить к значениям по умолчанию"
    echo "6. Вернуться в меню"
    echo ""
    read -p "Ваш выбор (1-6): " update_choice
    
    case $update_choice in
        1)
            echo ""
            read -p "Введите новую минимальную сумму (только цифры): " new_value
            if [[ "$new_value" =~ ^[0-9]+$ ]]; then
                echo "$new_value" > ~/.wasmd_min_stake
                echo "✅ Новое значение сохранено: $new_value"
            else
                echo "❌ Ошибка: введите только цифры"
            fi
            ;;
        2)
            echo ""
            echo "Вставьте полный текст ошибки (нажмите Enter два раза для завершения):"
            error_text=""
            while IFS= read -r line; do
                [ -z "$line" ] && break
                error_text+="$line "
            done
            
            if [ ! -z "$error_text" ]; then
                if extracted_value=$(extract_min_from_error "$error_text"); then
                    echo "$extracted_value" > ~/.wasmd_min_stake
                    echo "✅ Извлечено и сохранено значение: $extracted_value"
                else
                    echo "❌ Не удалось извлечь значение из ошибки"
                    echo "Убедитесь что ошибка содержит 'DefaultPowerReduction ({число})'"
                fi
            else
                echo "❌ Текст ошибки не введен"
            fi
            ;;
        3)
            echo ""
            echo "🔄 Установка актуального значения: 824639634176"
            echo "824639634176" > ~/.wasmd_min_stake
            echo "✅ Актуальное значение установлено: 824639634176"
            ;;
        4)
            echo ""
            echo "🔄 Автоматическое определение..."
            auto_value=$(get_min_validator_stake)
            echo "$auto_value" > ~/.wasmd_min_stake
            echo "✅ Автоматически определено и сохранено: $auto_value"
            ;;
        5)
            echo ""
            echo "🔄 Сброс к значениям по умолчанию..."
            rm -f ~/.wasmd_min_stake 2>/dev/null
            echo "✅ Настройки сброшены"
            ;;
        6)
            echo "Операция отменена"
            pause
            return
            ;;
        *)
            echo "❌ Неверный выбор"
            ;;
    esac
    
    echo ""
    echo "📊 Обновленные настройки:"
    new_min=$(get_min_validator_stake)
    echo "   Новая минимальная сумма: $new_min"
    
    echo ""
    echo "💡 Рекомендации:"
    echo "   - Теперь при создании валидаторов (пункты 10, 15) будет использоваться новое значение"
    echo "   - При добавлении аккаунтов в genesis (пункт 9) используйте сумму >= $new_min"
    echo "   - Если получите новую ошибку с другим значением, повторите этот пункт"
    
    echo ""
    pause
}

function quick_fix_validator_empty() {
    echo "=========================================================="
    echo "          БЫСТРОЕ ИСПРАВЛЕНИЕ 'validator set is empty'   "
    echo "=========================================================="
    echo ""
    
    echo "🔧 Эта функция автоматически исправит ошибку:"
    echo "'validator set is empty after InitGenesis'"
    echo ""
    
    # Предлагаем ввести текст ошибки для извлечения точного значения
    echo "📋 Если у вас есть текст ошибки с точным значением DefaultPowerReduction:"
    read -p "Хотите ввести текст ошибки? (y/n, Enter = n): " input_error
    
    if [[ "$input_error" =~ ^[yYдД]$ ]]; then
        echo ""
        echo "Вставьте полный текст ошибки (нажмите Enter два раза для завершения):"
        error_text=""
        while IFS= read -r line; do
            [ -z "$line" ] && break
            error_text+="$line "
        done
        
        if [ ! -z "$error_text" ]; then
            if extracted_min=$(extract_min_from_error "$error_text"); then
                echo "✅ Извлечено минимальное значение: $extracted_min"
                echo "$extracted_min" > ~/.wasmd_min_stake
                echo "💾 Значение сохранено для будущего использования"
            else
                echo "⚠️ Не удалось извлечь значение из ошибки"
            fi
        fi
        echo ""
    fi
    
    # Определяем текущие значения
    MIN_VALIDATOR_STAKE=$(get_min_validator_stake)
    SAFE_AMOUNT=$(suggest_safe_amount "$MIN_VALIDATOR_STAKE")
    
    echo "📊 Текущие настройки:"
    echo "   Минимальная сумма: $MIN_VALIDATOR_STAKE"
    echo "   Безопасная сумма: $SAFE_AMOUNT"
    echo ""
    
    # Проверяем genesis.json
    GENESIS_FILE="$HOME/.wasmd/config/genesis.json"
    if [ ! -f "$GENESIS_FILE" ]; then
        echo "❌ ПРОБЛЕМА: genesis.json не найден!"
        echo "💡 РЕШЕНИЕ: Выполните пункт 5 (Инициализировать узел)"
        pause
        return
    fi
    
    # Проверяем валидаторов
    if command -v jq &> /dev/null; then
        validators_count=$(jq '.app_state.genutil.gen_txs | length' "$GENESIS_FILE" 2>/dev/null || echo "0")
        accounts_count=$(jq '.app_state.bank.balances | length' "$GENESIS_FILE" 2>/dev/null || echo "0")
        
        echo "🔍 Диагностика genesis.json:"
        echo "   Валидаторов: $validators_count"
        echo "   Аккаунтов: $accounts_count"
        echo ""
        
        if [ "$validators_count" -eq 0 ]; then
            echo "❌ ПРОБЛЕМА: Нет валидаторов в genesis.json"
            echo ""
            echo "🔧 АВТОМАТИЧЕСКОЕ ИСПРАВЛЕНИЕ:"
            echo "Выберите действие:"
            echo "1. Создать валидатора автоматически (если есть ключи и аккаунты)"
            echo "2. Пошаговое исправление (создать ключ → аккаунт → валидатора)"
            echo "3. Вернуться в меню"
            echo ""
            read -p "Ваш выбор (1-3): " fix_choice
            
            case $fix_choice in
                1)
                    echo ""
                    echo "🚀 Автоматическое создание валидатора..."
                    
                    # Проверяем ключи
                    KEYRING_BACKEND=$(detect_keyring_backend)
                    keys_list=$(timeout 10s wasmd keys list --keyring-backend "$KEYRING_BACKEND" 2>/dev/null | head -5)
                    
                    if [ -z "$keys_list" ]; then
                        echo "❌ Нет ключей валидатора. Создайте ключ через пункт 7"
                        pause
                        return
                    fi
                    
                    # Берем первый доступный ключ
                    first_key=$(echo "$keys_list" | head -1 | awk '{print $1}' | sed 's/[^a-zA-Z0-9_-]//g')
                    if [ -z "$first_key" ]; then
                        echo "❌ Не удалось определить имя ключа"
                        pause
                        return
                    fi
                    
                    echo "🔑 Используем ключ: $first_key"
                    
                    # Проверяем есть ли аккаунт в genesis
                    key_address=$(timeout 10s wasmd keys show "$first_key" -a --keyring-backend "$KEYRING_BACKEND" 2>/dev/null)
                    if [ -z "$key_address" ]; then
                        echo "❌ Не удалось получить адрес ключа"
                        pause
                        return
                    fi
                    
                    echo "📍 Адрес ключа: $key_address"
                    
                    # Проверяем баланс в genesis
                    balance=$(jq -r ".app_state.bank.balances[] | select(.address == \"$key_address\") | .coins[0].amount" "$GENESIS_FILE" 2>/dev/null)
                    
                    if [ -z "$balance" ] || [ "$balance" = "null" ]; then
                        echo "❌ Аккаунт $key_address не найден в genesis.json"
                        echo "💡 Добавляем аккаунт с безопасной суммой: $SAFE_AMOUNT"
                        
                        # Добавляем аккаунт
                        cd wasmd 2>/dev/null || cd .
                        STAKE_CLEAN=$(sanitize_input "$STAKE")
                        AMOUNT_WITH_DENOM="${SAFE_AMOUNT}${STAKE_CLEAN}"
                        
                        if wasmd genesis add-genesis-account "$key_address" "$AMOUNT_WITH_DENOM"; then
                            echo "✅ Аккаунт добавлен в genesis"
                            balance="$SAFE_AMOUNT"
                        else
                            echo "❌ Ошибка при добавлении аккаунта"
                            cd .. 2>/dev/null
                            pause
                            return
                        fi
                        cd .. 2>/dev/null
                    else
                        echo "✅ Аккаунт найден в genesis с балансом: $balance"
                    fi
                    
                    # Проверяем достаточность баланса
                    if (( balance < MIN_VALIDATOR_STAKE )); then
                        echo "❌ Баланс ($balance) меньше минимума ($MIN_VALIDATOR_STAKE)"
                        echo "💡 Рекомендуется увеличить баланс через пункт 9"
                        pause
                        return
                    fi
                    
                    # Создаем валидатора
                    echo "🔨 Создание валидатора..."
                    echo "💡 Теперь выполните пункт 10 с ключом '$first_key'"
                    echo "   Используйте безопасную сумму: $SAFE_AMOUNT"
                    echo ""
                    pause
                    ;;
                2)
                    echo ""
                    echo "📋 Пошаговое исправление:"
                    echo "1. Выполните пункт 7 (Создать ключ валидатора)"
                    echo "2. Выполните пункт 9 (Добавить аккаунт с суммой >= $MIN_VALIDATOR_STAKE)"
                    echo "3. Выполните пункт 10 (Создать валидатора в генезисе)"
                    echo "4. Выполните пункт 12 (Запустить ноду)"
                    echo ""
                    pause
                    ;;
                3)
                    return
                    ;;
                *)
                    echo "❌ Неверный выбор"
                    pause
                    ;;
            esac
        else
            echo "✅ Валидаторы найдены в genesis.json"
            echo "💡 Проблема может быть в недостаточной сумме стейкинга"
            echo "   Проверьте детали через пункт 19.5 (Диагностика genesis.json)"
            pause
        fi
    else
        echo "❌ jq не установлен. Невозможно провести диагностику"
        echo "💡 Установите jq: sudo apt install jq"
        pause
    fi
}

# Основной цикл меню
while true; do
    clear
    echo "=========================================================="
    echo "                  WASMD: Меню Установки                   "
    echo "=========================================================="
    echo ""
    echo "🔧 SOLO НАСТРОЙКА (для одиночной/мастер ноды):"
    echo "1.  Клонировать репозиторий блокчейна"
    echo "2.  Установить зависимости для сборки"
    echo "3.  Установить Bech32-префикс"
    echo "4.  Собрать и установить wasmd"
    echo "5.  Инициализировать узел wasmd"
    echo "6.  Настроить конфигурацию wasmd"
    echo "7.  Создать ключ валидатора"
    echo "8.  Создать обычный кошелек"
    echo "9.  Добавить аккаунт в генезис"
    echo "10. Создать валидатора в генезисе (gentx + collect-gentx)"
    echo "11. Показать ID ноды"
    echo "12. Запустить ноду wasmd (solo режим)"
    echo "13. Создать systemd-сервис и добавить в автозагрузку"
    echo ""
    echo "🌐 ПЕРИМЕТР (для сети из нескольких нод):"
    echo "14. Копировать genesis.json на другую ноду"
    echo "15. Создать валидатора через JSON (для подключения к сети)"
    echo "16. Настроить файрвол (nftables) для защиты нод"
    echo "17. Собрать ID нод для config.toml (persistent_peers)"
    echo "18. Отправить монеты (tx bank send)"
    echo ""
    echo "🛠️ УТИЛИТЫ:"
    echo "19. Диагностика ноды (поиск проблем)"
    echo "19.5. Диагностика genesis.json (validator set is empty)"
    echo "19.6. БЫСТРОЕ ИСПРАВЛЕНИЕ 'validator set is empty'"
    echo "19.7. Обновить минимальную сумму для валидатора"
    echo "20. Просмотреть логи"
    echo "21. Резервное копирование файлов"
    echo "22. Проверить статус сервиса"
    echo "23. Тестовый запуск"
    echo "24. Исправить файлы конфигурации"
    echo "25. Очистить конфигурацию wasmd (выбор способа)"
    echo "26. Исправить ошибку Bech32 префикса"
    echo ""
    echo "0.  Выйти"
    echo "=========================================================="
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
        10) create_and_collect_gentx ;;
        11) show_node_id ;;
        12) start_wasmd_node ;;
        13) create_systemd_service ;;
        14) copy_genesis_to_node ;;
        15) create_validator_from_json ;;
        16) setup_nftables ;;
        17) collect_node_ids ;;
        18) send_tokens ;;
        19) diagnose_node ;;
        19.5) diagnose_genesis_problems ;;
        19.6) quick_fix_validator_empty ;;
        19.7) update_min_stake_value ;;
        20) view_logs ;;
        21) backup_files ;;
        22) check_service_status ;;
        23) test_run ;;
        24) fix_config_files ;;
        25) 
            clear
            echo "Выберите способ очистки:"
            echo "1. Полная очистка (с остановкой процессов)"
            echo "2. Быстрая очистка (только удаление файлов)"
            echo "3. Вернуться в меню"
            read -p "Ваш выбор: " clean_choice
            case $clean_choice in
                1) clean_wasmd_config ;;
                2) quick_clean_wasmd ;;
                3) ;;
                *) echo "Неверный выбор!"; pause ;;
            esac
            ;;
        26) fix_bech32_prefix_error ;;
        0) echo "Выход."; exit 0 ;;
        *) echo "Неверный выбор!"; pause ;;
    esac
done


#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run the installer as root or use sudo."
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo "'bc' command is required but not installed."
    exit 1
fi

if ! command -v zip &> /dev/null; then
    echo "'zip' command is required but not installed."
    exit 1
fi

RESET='\e[0m'
GREEN='\e[32m'
RED='\e[31m'

NAME="backup"
MAIN="main.sh"
CONF="conf.ini"

log() {
    echo -ne "${RESET}$1"
}

success() {
    echo -e "${GREEN} Done!${RESET}"
}

error() {
    echo -e "${RED} Error: [$1]${RESET}" >&2
}

ask() {
    echo -ne "$1: ${RESET}"
}


while :; do
    ask "Enter the backup interval in hours [Float values are acceptable]"
    read BACKUP_INTERVAL_HOURS

    if [[ "$BACKUP_INTERVAL_HOURS" =~ ^[0-9]+(\.[0-9]+)?$ ]] && 
       [[ $(echo "$BACKUP_INTERVAL_HOURS >= 0.0014" | bc -l) -eq 1 ]] && 
       [[ $(echo "$BACKUP_INTERVAL_HOURS <= 8760" | bc -l) -eq 1 ]]; then
        break
    else
        error "Invalid interval. Acceptable values are between 0.0014 hours (5sec) and 8760 hours (1year)."
    fi
done

while :; do
    ask "Should webserver configuration be backed up? (y|n)"
    read WEBSERVER_BACKUP

    if [[ "$WEBSERVER_BACKUP" == "y" ]]; then
        WEBSERVER_BACKUP="true"
        break
    elif [[ "$WEBSERVER_BACKUP" == "n" ]]; then
        WEBSERVER_BACKUP="false"
        break
    else
        error "Invalid input. Please enter 'y' or 'n'."
    fi
done

while :; do
    ask "Enter a list of directories to back up, separated by commas [no spaces]"
    read BASE_DIRS

    if [[ -z "$BASE_DIRS" ]]; then
        error "Input cannot be empty. Please enter at least one directory."
        continue
    fi

    IFS=',' read -r -a DIR_ARRAY <<< "$BASE_DIRS"
    IFS=' '
    exist=true
    
    for dir in "${DIR_ARRAY[@]}"; do
        if [[ ! -d "$dir" ]]; then
            error "$dir does not exist!"
            exist=false
        fi
    done

    if $exist; then
        break
    else
        error "One or more directories do not exist. Please try again."
    fi
done

while :; do
    ask "Enter a list of directories within BASE_DIRS to exclude, separated by commas [no spaces]"
    read EXCEPTION_DIRS

    if [[ -z "$EXCEPTION_DIRS" ]]; then
        break
    fi

    IFS=',' read -r -a DIR_ARRAY <<< "$EXCEPTION_DIRS"
    IFS=' '
    exist=true
    
    for dir in "${DIR_ARRAY[@]}"; do
        if [[ ! -d "$dir" ]]; then
            error "$dir does not exist!"
            exist=false
        fi
    done

    if $exist; then
        break
    else
        error "One or more directories do not exist. Please try again."
    fi
done

while :; do
    ask "Enter a list of MySQL databases to back up, separated by commas [no spaces] (leave empty to back up all databases)"
    read MYSQL_BASE_DBS

    if [[ -z "$MYSQL_BASE_DBS" ]]; then
        MYSQL_BASE_DBS=""
        break
    fi

    IFS=',' read -r -a DB_ARRAY <<< "$MYSQL_BASE_DBS"
    IFS=' '
    exist=true
    
    for db in "${DB_ARRAY[@]}"; do
        if ! mysql -e "USE \`$db\`" >/dev/null 2>&1; then
            error "$db does not exist!"
            exist=false
        fi
    done

    if $exist; then
        break
    else
        error "One or more databases do not exist. Please try again."
    fi
done

while :; do
    ask "Enter a list of MySQL databases to exclude from backup, separated by commas [no spaces] (leave empty for none)"
    read MYSQL_EXP_DBS

    if [[ -z "$MYSQL_EXP_DBS" ]]; then
        MYSQL_EXP_DBS=""
        break
    fi

    IFS=',' read -r -a DB_ARRAY <<< "$MYSQL_EXP_DBS"
    IFS=' '
    exist=true
    
    for db in "${DB_ARRAY[@]}"; do
        if ! mysql -e "USE \`$db\`" >/dev/null 2>&1; then
            error "$db does not exist!"
            exist=false
        fi
    done

    if $exist; then
        break
    else
        error "One or more databases do not exist. Please try again."
    fi
done

while :; do
    ask "Enter the destination type [supported: TELEGRAM]"
    read TYPE

    if [[ "$TYPE" == "TELEGRAM" ]]; then
        while :; do
            ask "Enter the bot token"
            read TOKEN
    
            if [[ "$TOKEN" =~ ^[0-9]{1,10}:[a-zA-Z0-9_-]{35}$ ]]; then
                while :; do
                    ask "Enter the chat_id"
                    read CHAT_ID
        
                    if [[ "$CHAT_ID" =~ ^-?[0-9]{1,13}$ ]]; then
                        while :; do
                            ask "Enter the topic_id [can be empty]"
                            read TOPIC_ID
            
                            if [[ -z "$TOPIC_ID" || "$TOPIC_ID" =~ ^[0-9]{1,}$ ]]; then
                                break
                            else
                                error "Invalid topic_id!"
                            fi
                        done
                        break
                    else
                        error "Invalid chat_id!"
                    fi
                done
                break
            else
                error "Invalid bot token!"
            fi
        done
        break
    else
        error "Unsupported destination type! Currently only 'TELEGRAM' is supported"
    fi
done


log "Creating Root Directory"
if mkdir -p "/etc/$NAME"; then
    success
else
    error "Access Denied. Check permissions.";
    exit 1
fi


log "Configuring the basics"
cat <<EOL > "/etc/$NAME/$CONF"
[settings]
; General settings for backup configuration

; Interval in hours between backups
; You can choose a float value for smaller intervals (e.g., 0.5 for 30 minutes)
; Default value is 24 (Hours)
BACKUP_INTERVAL_HOURS = $BACKUP_INTERVAL_HOURS


[destination]
; Define the destination of the backup files.
; Supported destination type(s): TELEGRAM

; TELEGRAM Section
; TOKEN and CHAT_ID are required; TOPIC_ID is optional.
; --------------------
TYPE = $TYPE
TOKEN = $TOKEN
CHAT_ID = $CHAT_ID
TOPIC_ID = $TOPIC_ID


[backup]
; Define the backup main options.

; BASE_DIRS: List of directories to back up, separated by commas [no spaces]
; Example: /var/www/test1,/var/www/test2
BASE_DIRS = $BASE_DIRS

; EXCEPTION_DIRS: Directories within BASE_DIRS to exclude, separated by commas
; Example: /var/www/test1/exp1
EXCEPTION_DIRS = $EXCEPTION_DIRS

; MYSQL_BASE_DBS: Databases to back up, default "all". Exclusions should be defined in MYSQL_EXP_DBS
; Use "all" for all databases or list specific databases separated by commas.
MYSQL_BASE_DBS = $MYSQL_BASE_DBS

; MYSQL_EXP_DBS: Databases to exclude from backup, separated by commas
; These databases are excluded by default: information_schema, performance_schema, mysql, sys
MYSQL_EXP_DBS = $MYSQL_EXP_DBS

; WEBSERVER_BACKUP: Set to true to enable, false to disable
; Supported servers: Apache, nginx
WEBSERVER_BACKUP = $WEBSERVER_BACKUP
EOL

if [ -f "/etc/$NAME/$CONF" ]; then
    success
else
    error "Access Denied. Check permissions."
    exit 1
fi


log "Creating the main file"
cat << 'EOF' > "/etc/$NAME/$MAIN"
#!/bin/bash

CONF="/etc/backup/conf.ini"

parse_ini() {
    eval "$(awk -F'=' '/^[^;# \t]+[ ]*=[ ]*[^;#]+$/ {gsub(/^[ \t]+|[ \t]+$/, "", $1); gsub(/^[ \t]+|[ \t]+$/, "", $2); printf("%s=\"%s\"\n", $1, $2)}' "$CONF")"
}

if [ -f "$CONF" ]; then
    parse_ini
else
    echo "Configuration file $CONF does not exist or access is denied."
    exit 1
fi

if [[ -z "$BACKUP_INTERVAL_HOURS" || -z "$TYPE" || -z "$BASE_DIRS" ]]; then
    echo "Error: Missing required configuration variables."
    exit 1
fi

if [[ "$TYPE" == "TELEGRAM" ]]; then
    if [[ -z "$TOKEN" || -z "$CHAT_ID" ]]; then
        echo "Error: TYPE is set to TELEGRAM, but TOKEN or CHAT_ID is missing."
        exit 1
    fi
fi

TOPIC_ID="${TOPIC_ID:-0}"
EXCEPTION_DIRS="${EXCEPTION_DIRS:-}"
MYSQL_BASE_DBS="${MYSQL_BASE_DBS:-}"
MYSQL_EXP_DBS="${MYSQL_EXP_DBS:-}"
WEBSERVER_BACKUP="${WEBSERVER_BACKUP:-true}"
BACKUP_INTERVAL_SECONDS=$(echo "$BACKUP_INTERVAL_HOURS * 3600" | bc)

backup() {
    TEMP_DIR=$(mktemp -d /tmp/backup.XXXXXX)

    if [[ "$WEBSERVER_BACKUP" == "true" ]]; then
        local WEBSERVER=""
        local BASE_PATH=""

        if command -v apache2 >/dev/null 2>&1; then
            WEBSERVER="apache"
            BASE_PATH="/etc/apache2/sites-available"
        elif command -v nginx >/dev/null 2>&1; then
            WEBSERVER="nginx"
            BASE_PATH="/etc/nginx/sites-available"
        fi

        if [[ -n "$BASE_PATH" && -d "$BASE_PATH" && "$(ls -A "$BASE_PATH")" ]]; then
            SERVER_BACKUP_DIR=""
            mkdir -p "$TEMP_DIR/$WEBSERVER"
            cp -r "$BASE_PATH"/* "$TEMP_DIR/$WEBSERVER"
        fi
    fi

    IFS=',' read -r -a BASE_DIR_ARRAY <<< "$BASE_DIRS"
    IFS=',' read -r -a EXCEPTION_DIR_ARRAY <<< "$EXCEPTION_DIRS"

    for dir in "${BASE_DIR_ARRAY[@]}"; do
        EXCLUDE_PATTERNS=()

        for exc in "${EXCEPTION_DIR_ARRAY[@]}"; do
            if [[ "$exc" == "$dir"* ]]; then
                EXCLUDE_PATTERNS+=(--exclude="${exc#$dir/}")
            fi
        done

        DEST_DIR="$TEMP_DIR/files"
        mkdir -p "$DEST_DIR"

        rsync -a "${EXCLUDE_PATTERNS[@]}" "$dir/" "$DEST_DIR/"
    done

    IFS=',' read -r -a MYSQL_EXP_DBS_ARRAY <<< "$MYSQL_EXP_DBS"
    DEFAULT_MYSQL_EXCLUSIONS=("information_schema" "performance_schema" "mysql" "sys")

    for default_db in "${DEFAULT_MYSQL_EXCLUSIONS[@]}"; do
        if [[ ! " ${MYSQL_EXP_DBS_ARRAY[@]} " =~ " ${default_db} " ]]; then
            MYSQL_EXP_DBS_ARRAY+=("$default_db")
        fi
    done

    if [[ -z "$MYSQL_BASE_DBS" ]]; then
        MYSQL_BASE_DBS_ARRAY=($(mysql -e "SHOW DATABASES;" -s --skip-column-names))
    else
        IFS=',' read -r -a MYSQL_BASE_DBS_ARRAY <<< "$MYSQL_BASE_DBS"
    fi

    MYSQL_BACKUP_DIR="$TEMP_DIR/mysql"
    mkdir -p "$MYSQL_BACKUP_DIR"

    for db in "${MYSQL_BASE_DBS_ARRAY[@]}"; do
        skip_db=false
        for exp_db in "${MYSQL_EXP_DBS_ARRAY[@]}"; do
            if [[ "$db" == "$exp_db" ]]; then
                skip_db=true
                break
            fi
        done

        if ! $skip_db; then
            mysqldump "$db" > "$MYSQL_BACKUP_DIR/$db.sql"
        fi
    done

    BACKUP_ARCHIVE="/tmp/backup_$(date +'%Y%m%d%H%M%S').zip"
    cd "$TEMP_DIR" || exit 1
    zip -r -9 "$BACKUP_ARCHIVE" ./* > /dev/null 2>&1
    rm -rf "$TEMP_DIR"

    echo "$BACKUP_ARCHIVE"
}

while :; do
    ZIP_FILE=$(backup)

    if [[ "$TYPE" == "TELEGRAM" ]]; then
        TELEGRAM_API="https://api.telegram.org/bot${TOKEN}/sendDocument"

        if [[ "$TOPIC_ID" != "0" ]]; then
            curl -s -F "chat_id=${CHAT_ID}" -F "document=@${ZIP_FILE}" -F "message_thread_id=${TOPIC_ID}" "$TELEGRAM_API" > /dev/null 2>&1
        else
            curl -s -F "chat_id=${CHAT_ID}" -F "document=@${ZIP_FILE}" "$TELEGRAM_API" > /dev/null 2>&1
        fi
    fi

    rm "$ZIP_FILE"
    echo "Last backup: $(date +"%Y-%m-%d %H:%M:%S")"
    sleep "$BACKUP_INTERVAL_SECONDS"
done
EOF

if [ -f "/etc/$NAME/$MAIN" ]; then
    success
else
    error "Access Denied. Check permissions."
    exit 1
fi


log "Setting executable permissions for backup"
chmod +x "/etc/$NAME/$MAIN"
if [ -f "/etc/$NAME/$MAIN" ]; then
    success
else
    error "Access Denied. Check permissions."
    exit 1
fi


log "Creating Systemd"
cat <<EOL > "/etc/systemd/system/$NAME.service"
[Unit]
Description=Backup
After=network.target
Wants=network-online.target

[Service]
User=root
Restart=always
ExecStart=/etc/$NAME/$MAIN
WorkingDirectory=/etc/$NAME

[Install]
WantedBy=multi-user.target
EOL

if [ -f "/etc/systemd/system/$NAME.service" ]; then
    success
else
    error "Access Denied. Check permissions."
    exit 1
fi


log "Reloading and Enabling the service"
systemctl daemon-reload
if systemctl enable "$NAME.service"; then
    success
else
    error "Access Denied. Check permissions."
    exit 1
fi


log "Starting backup service"
if systemctl start "$NAME.service"; then
    success
    echo -e "${GREEN}Installation complete.${RESET}"
else
    error "Check Systemd logs for more information."
    exit 1
fi

rm "$0"

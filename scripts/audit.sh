#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "[OK] $desc"
        ((PASS++))
    else
        echo "[FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

# TODO 1: проверка, что port != 22
PORT_VAL="$(sudo sshd -T | awk '/^port/{print $2}')"
if [[ "$PORT_VAL" != "22" ]]; then
    check "Порт SSH отличен от 22 (текущий: $PORT_VAL)" "true" "true"
else
    check "Порт SSH отличен от 22 (текущий: $PORT_VAL)" "true" "false"
fi

# TODO 2: проверка, что maxauthtries == 3
check "Лимит попыток аутентификации MaxAuthTries равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3: проверка входящей политики deny
DEFAULT_INCOMING="$(sudo ufw status verbose | grep -i "Default:" | awk '{print $2}')"
check "Политика по умолчанию для входящего трафика deny" "deny" "$DEFAULT_INCOMING"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf " %s (uid=%s)\n", $1, $3}' /etc/passwd

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

echo "=== [4] Веб-сервер ==="
check "Служба nginx активна" "systemctl is-active --quiet nginx"
check "Конфигурация nginx синтаксически корректна" "sudo nginx -t >/dev/null 2>&1"
check "Сертификат действителен более 30 дней" "openssl x509 -in /etc/ssl/certs/devops.crt -noout -checkend 2592000>/dev/null 2>&1"
check "Права каталога ресурса и закрытого ключа безопасны" "test -z \"\$(find /var/www/devops-site -perm -o+w)\" && test \"\$(sudo stat -c '%a' /etc/ssl/private/devops.key)\" = '600'"

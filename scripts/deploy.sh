#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail
REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
REPO_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"
# 1. Разбор аргумента --dry-run
DRY_RUN_FLAG=()
if [[ "${1:-}" == "--dry-run" ]]; then
DRY_RUN_FLAG=("--dry-run")
elif [[ $# -gt 0 ]]; then
echo "Ошибка: неизвестный параметр $1" >&2
exit 1
fi
# 2. Проверка наличия главного файла site/index.html (Требование 4)
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
echo "Ошибка: файл site/index.html отсутствует!" >&2
exit 1
fi
# Проверка отсутствия незафиксированных изменений в репозитории (Требование 5)
if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain)" ]]; then
echo "Ошибка: в репозитории есть незафиксированные изменения!" >&2
exit 1
fi
# 3. Синхронизация каталога (ровно 1 SSH-соединение, без интерактивного пароля - Требования 3, 8, 9)
rsync -avz --delete --chmod=D755,F644 \
"${DRY_RUN_FLAG[@]}" \
-e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
"${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"
# 4. При --dry-run завершаем работу с кодом 0 без проверки доступности (Требование 1)
if [[ "${1:-}" == "--dry-run" ]]; then
exit 0
fi
# 5. Проверка доступности ресурса с проверкой сертификата (Требование 6)
if ! curl -fsS --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}"; then
echo "Ошибка: ресурс ${SITE_URL} недоступен или сертификат не прошел проверку!" >&2
exit 1
fi
# Вывод короткого хеша доставленного коммита (Требование 7)
COMMIT_HASH="$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"
echo "Деплой успешно завершен. Доставлен коммит: ${COMMIT_HASH}"
exit 0

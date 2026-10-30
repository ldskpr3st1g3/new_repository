# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- Память: 2048 МБ
- Процессоры: 2 vCPU
- Диск: 25 ГБ (VDI, динамический)

## 2. Сетевые интерфейсы
- enp0s3: NAT (DHCP, 10.0.2.15/24) — доступ виртуальной машины в Интернет
- enp0s8: Host-only (DHCP/Static, 192.168.56.101/24) — связь «хост-гость», доступ к веб-сервисам с хоста

## 3. Правило проброса портов
- Имя: ssh
- Протокол: TCP
- Хостовый адрес и порт: 127.0.0.1:2222
- Гостевой адрес и порт: :2222

## 4. Учётные записи
- student: UID 1000, группы student, sudo (первичный пользователь, вход по паролю)
- devops: UID 1001, группы devops, sudo (административный пользователь, вход только по SSH-ключу ed25519)

## 5. Служба SSH
- Порт: 2222
- Изменённые параметры: PermitRootLogin no, PasswordAuthentication no, PubkeyAuthentication yes, MaxAuthTries 3, LoginGraceTime 30, AllowUsers devops
- Конфигурационный файл: /etc/ssh/sshd_config.d/99-hardening.conf

## 6. Правила межсетевого экрана
- Политики по умолчанию: incoming deny, outgoing allow
- Правила:
  - 2222/tcp LIMIT (SSH с ограничением частоты)
  - 80/tcp ALLOW (HTTP)
  - 443/tcp ALLOW (HTTPS)

## 7. Снимки состояния
- 01-clean-install: чистая установленная ОС после обновления пакетов
- 02-keys-configured: создана учётная запись devops, настроен вход по SSH-ключу
- 03-ssh-hardened: усилена конфигурация sshd, изменен порт на 2222

## 8. Веб-сервер

- **Устанавливаемый пакет:** `nginx` (`sudo apt install -y nginx rsync`)
- **Путь к конфигурации ресурса:** `/etc/nginx/sites-available/devops-site` (активируется символической ссылкой в `/etc/nginx/sites-enabled/devops-site`, ссылка `/etc/nginx/sites-enabled/default` удаляется).
- **Каталог ресурса:** `/var/www/devops-site`, владелец и группа — `devops:devops`, права доступа: `755` (`drwxr-xr-x`) для каталогов и `644` (`-rw-r--r--`) для файлов.
- **Сертификат и закрытый ключ TLS:**
  - Путь к сертификату: `/etc/ssl/certs/devops.crt` (владелец `root:root`, права `644`).
  - Путь к закрытому ключу: `/etc/ssl/private/devops.key` (владелец `root:root`, права `600`).
  - Срок действия: 365 дней.
  - Команда выпуска:
    ```bash
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/ssl/private/devops.key \
      -out /etc/ssl/certs/devops.crt \
      -subj "/CN=devops.local" \
      -addext "subjectAltName=DNS:devops.local"
    ```

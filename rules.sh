#!/bin/bash

# IP адреса машин
PROXY_IP="192.168.1.141"
CACHE_IP="192.168.1.142"
BACKEND_IP="192.168.1.143"
DB_IP="192.168.1.144"

IPTABLES=/usr/sbin/iptables

# Проверяем что флаг передан
if [ -z "$1" ]; then
    echo "Использование: $0 [--proxy|--cache|--backend|--db]"
    exit 1
fi

# Сбрасываем текущие правила
$IPTABLES -F
$IPTABLES -X

# Общие правила для всех машин
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A INPUT -p tcp --dport 22 -j ACCEPT

case "$1" in
    --proxy)
        echo "Применяем правила для PROXY (${PROXY_IP})..."
        $IPTABLES -A INPUT -p tcp --dport 5000 -j ACCEPT
        $IPTABLES -A INPUT -j DROP
        ;;

    --cache)
        echo "Применяем правила для CACHE/Redis (${CACHE_IP})..."
        $IPTABLES -A INPUT -p tcp -s $PROXY_IP --dport 6379 -j ACCEPT
        $IPTABLES -A INPUT -j DROP
        ;;

    --backend)
        echo "Применяем правила для BACKEND (${BACKEND_IP})..."
        $IPTABLES -A INPUT -p tcp -s $PROXY_IP --dport 8080 -j ACCEPT
        $IPTABLES -A INPUT -j DROP
        ;;

    --db)
        echo "Применяем правила для DB/PostgreSQL (${DB_IP})..."
        $IPTABLES -A INPUT -p tcp -s $BACKEND_IP --dport 5432 -j ACCEPT
        $IPTABLES -A INPUT -j DROP
        ;;

    *)
        echo "Неизвестный флаг: $1"
        echo "Использование: $0 [--proxy|--cache|--backend|--db]"
        exit 1
        ;;
esac

echo "Правила успешно применены!"
$IPTABLES -L -n -v

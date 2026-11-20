#!/usr/bin/env bash
# Полная проверка задания. Запуск из любой папки: bash /путь/к/starter/verify.sh
set -euo pipefail
cd "$(dirname "$0")"
state="$PWD/state"
assets="$(cd ../assets && pwd)"
mkdir -p "$state"
exec > >(tee "$state/verification.log") 2>&1

docker info >/dev/null
for name in hw2-http hw2-grpc hw2-missing; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    echo "Контейнер $name уже существует. Останови прежнюю проверку и освободи это имя."
    exit 1
  fi
done

# Удаляем только контейнеры, созданные этим запуском. Тома и веса сохраняем.
created=""
empty_dir=""
cleanup() {
  status=$?
  trap - EXIT
  if [[ "$status" -ne 0 ]]; then
    for name in $created; do
      docker logs "$name" 2>&1 || true
    done
    echo "Проверка остановилась. Подробности: starter/state/verification.log"
  fi
  for name in $created; do
    docker rm -f "$name" >/dev/null 2>&1 || true
  done
  if [[ -n "$empty_dir" ]]; then rmdir "$empty_dir" 2>/dev/null || true; fi
  exit "$status"
}
trap cleanup EXIT

wait_ready() {
  name="$1"
  for ((attempt=0; attempt<120; attempt++)); do
    if [[ "$(docker inspect -f '{{.State.Running}}' "$name")" != "true" ]]; then
      echo "$name завершился до готовности"
      return 1
    fi
    if [[ "$name" == hw2-http ]]; then
      if docker exec "$name" python -c \
        'import json, urllib.request; r=json.load(urllib.request.urlopen("http://127.0.0.1:8000/health", timeout=2)); assert r["ready"] is True' \
        >/dev/null 2>&1; then return 0; fi
    elif docker logs "$name" 2>&1 | grep -q 'gRPC ready'; then
      return 0
    fi
    sleep 2
  done
  echo "Не дождались готовности $name"
  return 1
}

start_service() {
  protocol="$1"
  port="$2"
  docker create --name "hw2-$protocol" --network hw2-network \
    -p "127.0.0.1:$port:$port" \
    --mount "type=bind,source=$assets,target=/models,readonly" \
    --mount type=volume,source=hw2-logs,target=/logs \
    hw2:model "$protocol"
  created="$created hw2-$protocol"
  docker start "hw2-$protocol"
  wait_ready "hw2-$protocol"
}

echo '1. Скачивание и проверка весов'
bash run_tools.sh python download_model.py
bash run_tools.sh pytest -q tests/test_given.py 2>&1 | tee "$state/pytest-given.txt"

echo '2. Генерация Protobuf и полный набор тестов'
bash run_tools.sh python -m grpc_tools.protoc -Iproto --python_out=. --grpc_python_out=. proto/predict.proto
bash run_tools.sh pytest -q 2>&1 | tee "$state/pytest-all.txt"

echo '3. Сборка и запуск двух контейнеров'
docker build -t hw2:model .
docker volume create hw2-logs
start_service http 8000
start_service grpc 50051
docker exec hw2-http python -c \
  'import urllib.request; print(urllib.request.urlopen("http://127.0.0.1:8000/health").read().decode())' \
  | tee "$state/health.json"
docker logs hw2-grpc > "$state/grpc-ready.txt" 2>&1
cat "$state/grpc-ready.txt"

echo '4. Сравнение Python, HTTP и gRPC на настоящей модели'
bash run_tools.sh python check.py --http http://hw2-http:8000 --grpc hw2-grpc:50051 \
  --report state/responses.json 2>&1 | tee "$state/client.txt"

echo '5. Попытка записи в каталог модели (ожидается отказ)'
if docker exec hw2-http python -c \
  'from pathlib import Path; Path("/models/write-probe").write_text("x")' \
  > "$state/readonly-error.txt" 2>&1; then
  echo 'Ошибка: каталог модели доступен для записи'
  exit 1
fi
cat "$state/readonly-error.txt"
grep -q 'Read-only file system' "$state/readonly-error.txt"

echo '6. Проверка журнала до и после замены обоих контейнеров'
docker cp hw2-http:/logs/requests.jsonl "$state/log-before.jsonl"
docker rm -f hw2-http hw2-grpc
created=""
start_service http 8000
docker cp hw2-http:/logs/requests.jsonl "$state/log-after.jsonl"
docker rm -f hw2-http
created=""

echo '7. Запуск без весов (ожидается отказ)'
empty_dir="$(mktemp -d "$state/empty-model.XXXXXX")"
created="$created hw2-missing"
if docker run --rm --name hw2-missing \
  --mount "type=bind,source=$empty_dir,target=/models,readonly" hw2:model http \
  > "$state/missing-model-error.txt" 2>&1; then
  echo 'Ошибка: сервис запустился без весов'
  exit 1
fi
cat "$state/missing-model-error.txt"
grep -q 'Model files missing' "$state/missing-model-error.txt"

docker version --format 'Client: {{.Client.Version}}; server: {{.Server.Version}}; platform: {{.Server.Os}}/{{.Server.Arch}}' \
  > "$state/docker-version.txt"
docker image inspect hw2:model --format '{{.Id}}' > "$state/image-id.txt"
bash run_tools.sh python collect_results.py
echo 'ГОТОВО: все проверки прошли. Отчёт: RESULTS.md; полный вывод: starter/state/verification.log'

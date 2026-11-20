# Проверки в среде разработки

Дата: 2026-11-20. Выполнены помощником в Linux x86_64, Python 3.13.5, CPU. Зависимости установлены через `uv sync --locked` из выданного uv.lock. Docker в этой среде недоступен; контейнеры и тома здесь не проверялись.

## Веса модели

`python download_model.py` скачал файлы по зафиксированной ревизии. Проверка всех SHA-256 завершилась строкой:

```text
Model download OK; all SHA-256 match
```

## Готовые тесты

Команда:

```bash
uv run --locked pytest -q tests/test_given.py
```

Вывод:

```text
.........                                                                [100%]
9 passed in 10.48s
```

## Полный набор

Команда:

```bash
uv run --locked pytest -q
```

Вывод:

```text
............................                                             [100%]
=============================== warnings summary ===============================
.venv/lib/python3.13/site-packages/fastapi/testclient.py:1
  /workspace/scratch/440ef4d75a65/mlops-hw02-course/homework/02-model-service/starter/.venv/lib/python3.13/site-packages/fastapi/testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.
    from starlette.testclient import TestClient as TestClient  # noqa

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
28 passed, 1 warning in 9.19s
```

## Сравнение Python, HTTP и gRPC

Команда:

```bash
.venv/bin/python check.py --report state/local-responses.json
```

Вывод:

```text
cats-default: In this image we can see two cats on the couch.
bee-24: In this image there are flowers and plants.
candy-24: In this image we can see a hand with some objects on it.
cats-one-token: In
OK: 4 captions × Python/HTTP/gRPC; 6 shared invalid inputs + invalid HTTP base64
```

Перед тестами классы Protobuf сгенерированы командой `uv run --locked python -m grpc_tools.protoc -Iproto --python_out=. --grpc_python_out=. proto/predict.proto`. Для сетевой проверки были запущены два отдельных процесса `.venv/bin/python service.py http` и `.venv/bin/python service.py grpc` на портах 8000 и 50051. У обоих установлены `HF_HUB_OFFLINE=1`, `TRANSFORMERS_OFFLINE=1` и общий `LOG_PATH`. Прокси-переменные в среде этих локальных процессов отключены: иначе HTTP-клиент этой среды требует необязательный пакет socksio. Клиент и код модели при этом не менялись.

## Общий файл журнала

Проверено, что все восемь сетевых ответов имеют разные ID и соответствующие записи в общем JSONL-файле. Пример записи gRPC:

```json
{"time": 1795175073.4815803, "protocol": "grpc", "max_new_tokens": 24, "caption": "In this image we can see two cats on the couch.", "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1", "request_id": "83fd487985e44c8988fdf48c80655091", "image_sha256": "03e3947df1ec190bbcc1f3cf47e56a5b60f9415be1ba072d1837d49380538b5c"}
```

Это проверка общей записи двумя процессами. Сохранность именованного Docker-тома после удаления контейнеров проверяется отдельно на Mac.

## Ограничения этой проверки

Предупреждение Starlette связано с использованием httpx в выданных тестах и не приводит к падению тестов. Зависимости курса не заменялись. Dockerfile и `verify.sh` подготовлены; `bash -n starter/verify.sh` и компиляция `collect_results.py` завершились успешно. Полный Docker-сценарий ещё предстоит запустить на Mac командой `bash starter/verify.sh`; его результаты будут записаны отдельно в README и RESULTS.md.

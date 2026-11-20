# ДЗ-2. Сервис описания изображений: HTTP и gRPC

Марина, М13-601, GitHub: **Marina-tomato**.

Сервис принимает JPEG или PNG и возвращает описание на английском языке.
HTTP и gRPC запускаются из одного Docker-образа. Ответы сравниваются с прямым
вызовом той же модели `HuggingFaceTB/SmolVLM-256M-Instruct` из Python.

Основа: [задание курса](https://github.com/ekolodin/mlops/tree/b083ea68bec1709bc6f500683862a473736dc312/homework/02-model-service),
коммит `b083ea68bec1709bc6f500683862a473736dc312`.
Исходное условие сохранено в [ASSIGNMENT.md](ASSIGNMENT.md).
Код модели, клиент проверки, изображения, манифест и выданные тесты оставлены без изменений.

## Что реализовано

- В `starter/service.py` добавлены `/health`, `/predict`, обработчик gRPC и регистрация сервиса.
- В `starter/proto/predict.proto` описаны запрос и ответ с номерами полей по условию.
- В `starter/Dockerfile` устанавливаются CPU-зависимости и генерируются классы Protobuf.
- В `starter/tests/test_student.py` добавлены два новых теста.
- `starter/verify.sh` повторяет все проверки задания и сохраняет их вывод.

В HTTP фотография передаётся строкой base64 в JSON. Обработчик строго декодирует
её и создаёт `CaptionInput`. В gRPC передаются исходные байты файла.
Оба обработчика вызывают `ModelRunner.predict`, поэтому проверка изображения
и генерация подписи общие. Ответ содержит подпись, версию модели, SHA-256 исходного
изображения и уникальный ID вызова.

Отсутствующее поле `max_new_tokens` становится `None`, и модель выбирает 24.
Явный ноль остаётся нулём и отклоняется. Для этого поля в Protobuf используется
`optional`, а в обработчике — `HasField`. Ошибки входных данных возвращаются как
HTTP 422 или gRPC `INVALID_ARGUMENT`. Ошибка генерации не маскируется под неверный ввод.

Модель загружается один раз при старте каждого процесса сервиса.
Веса подключаются через bind mount в `/models` с `readonly`: контейнеру нужно
читать уже скачанные на хост файлы. Журнал находится в именованном томе
`hw2-logs`, общем для двух контейнеров. Том сохраняется после их удаления.
После скачивания весов и сборки образа сервисы работают с локальной моделью:
`HF_HUB_OFFLINE=1` и `TRANSFORMERS_OFFLINE=1`.

## Запуск из чистого клона

Нужен запущенный Docker с Linux-контейнерами. Зависимости Python устанавливаются
в контейнерах; локальное Python-окружение не требуется. Первый запуск скачивает
около 518 МБ файлов модели и Docker-образы, поэтому нужны интернет и несколько
гигабайт свободного места. На Mac с Apple Silicon используется ARM64.

Из корня этой папки:

```bash
bash starter/verify.sh
```

Скрипт скачает веса и проверит SHA-256, выполнит тесты, соберёт образ, запустит
два сервиса и клиент сравнения. Затем проверит защиту весов от записи,
общий журнал, его сохранность после замены контейнеров и отказ при запуске без весов.

При успехе появится строка `ГОТОВО: все проверки прошли`.
Скрипт создаст `RESULTS.md` с фактическими результатами и заполнит раздел ниже.
Полный вывод останется в `starter/state/verification.log`.
При ошибке выполнение остановится; непройденная проверка не считается успешной.

Используются контейнеры `hw2-http`, `hw2-grpc`, `hw2-missing`, порты 8000 и 50051,
сеть `hw2-network`, тома `hw2-logs` и `hw2-tools-env`.
Если одно из имён контейнеров уже занято, скрипт остановится до начала работы.
Созданные им контейнеры удаляются по завершении; веса, отчёт и тома сохраняются.
При повторном запуске исправные веса и окружение инструментов используются повторно.

## Основные команды вручную

Все команды этого раздела выполняются из `starter/`.

```bash
bash run_tools.sh python download_model.py
bash run_tools.sh pytest -q tests/test_given.py
bash run_tools.sh python -m grpc_tools.protoc -Iproto --python_out=. --grpc_python_out=. proto/predict.proto
bash run_tools.sh pytest -q

docker build -t hw2:model .
docker volume create hw2-logs

docker run -d --name hw2-http --network hw2-network -p 127.0.0.1:8000:8000 \
  --mount type=bind,source="$PWD/../assets",target=/models,readonly \
  --mount type=volume,source=hw2-logs,target=/logs hw2:model http
docker run -d --name hw2-grpc --network hw2-network -p 127.0.0.1:50051:50051 \
  --mount type=bind,source="$PWD/../assets",target=/models,readonly \
  --mount type=volume,source=hw2-logs,target=/logs hw2:model grpc

curl http://127.0.0.1:8000/health
docker logs hw2-grpc
bash run_tools.sh python check.py --http http://hw2-http:8000 --grpc hw2-grpc:50051 --report state/responses.json
```

Перед клиентом нужно дождаться `ready: true` у HTTP и `gRPC ready` в журнале gRPC.
Команды проверки прав и сохранности журнала приведены в
[исходном условии, шаг 3](ASSIGNMENT.md#3-проверьте-результат)
и включены в `starter/verify.sh`.

## Два новых теста

| Тест | Случай | Какую ошибку ловит |
|---|---|---|
| `test_png_at_pixel_limit_is_valid` | Исправный PNG 1024 × 1024, ровно 1 048 576 пикселей | Отказ на допустимой границе, например при сравнении `>=` вместо `>` |
| `test_valid_gif_is_rejected` | Исправный маленький GIF | Пропуск проверки формата: Pillow читает GIF, но контракт разрешает только JPEG/PNG |

Первый тест также проверяет исходные байты и `None` для пропущенного лимита.
Во втором проверяется причина отказа: случайно повреждённый файл не должен
давать ложноположительный результат. В выданных тестах есть превышение числа
пикселей, но нет допустимой границы и исправного файла неподдерживаемого формата.

## Проверки в среде разработки

Результаты реальных запусков без Docker приведены в [LOCAL_CHECKS.md](LOCAL_CHECKS.md).
Результат: 9 готовых тестов и все 28 тестов прошли. Клиент подтвердил совпадение четырёх подписей в Python, HTTP и gRPC и отклонение неверных запросов.
Эти проверки выполнены помощником в Linux x86_64; они не заменяют проверку контейнеров на Mac.

## Результаты Docker

<!-- DOCKER_RESULTS_START -->
Автоматически собраны `starter/verify.sh` в 2026-11-20T20:09:01.366967+00:00.

Отчёт содержит фактический вывод команд, а не ожидаемые результаты.

## Окружение

```text
Client: 29.9.2; server: 29.9.2; platform: linux/arm64
```

## Общий образ двух сервисов

```text
sha256:522e3cf47d9c106769ece116730cbf4abe5271d00d7b6bf7ab3fc4226bb00882
```

## Готовые тесты

```text
Resolved 50 packages in 1ms
Audited 47 packages in 0.27ms
.........                                                                [100%]
9 passed in 9.16s
```

## Все тесты, включая два новых

```text
Resolved 50 packages in 0.85ms
Audited 47 packages in 0.22ms
............................                                             [100%]
=============================== warnings summary ===============================
../../venv/lib/python3.13/site-packages/fastapi/testclient.py:1
  /venv/lib/python3.13/site-packages/fastapi/testclient.py:1: StarletteDeprecationWarning: Using `httpx` with `starlette.testclient` is deprecated; install `httpx2` instead.
    from starlette.testclient import TestClient as TestClient  # noqa

-- Docs: https://docs.pytest.org/en/stable/how-to/capture-warnings.html
28 passed, 1 warning in 9.01s
```

## HTTP health

```text
{"ready":true,"model_version":"smolvlm-256m-7e3e67edbbed-caption-v1"}
```

## Готовность gRPC

```text
gRPC ready model_version=smolvlm-256m-7e3e67edbbed-caption-v1
```

## Сравнение трёх способов вызова

```text
Resolved 50 packages in 0.88ms
Audited 47 packages in 0.24ms
cats-default: In this image we can see two cats on the couch.
bee-24: In this image there are flowers and plants.
candy-24: In this image we can see a hand with some objects on it.
cats-one-token: In
OK: 4 captions × Python/HTTP/gRPC; 6 shared invalid inputs + invalid HTTP base64
```

## Запись в /models запрещена

```text
Traceback (most recent call last):
  File "<string>", line 1, in <module>
    from pathlib import Path; Path("/models/write-probe").write_text("x")
                              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^
  File "/usr/local/lib/python3.13/pathlib/_local.py", line 555, in write_text
    return PathBase.write_text(self, data, encoding, errors, newline)
           ~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.13/pathlib/_abc.py", line 651, in write_text
    with self.open(mode='w', encoding=encoding, errors=errors, newline=newline) as f:
         ~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/usr/local/lib/python3.13/pathlib/_local.py", line 537, in open
    return io.open(self, mode, buffering, encoding, errors, newline)
           ~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
OSError: [Errno 30] Read-only file system: '/models/write-probe'
```

## Запуск без весов

```text
INFO:     Started server process [1]
INFO:     Waiting for application startup.
ERROR:    Traceback (most recent call last):
  File "/usr/local/lib/python3.13/site-packages/starlette/routing.py", line 654, in lifespan
    async with self.lifespan_context(app) as maybe_state:
               ~~~~~~~~~~~~~~~~~~~~~^^^^^
  File "/usr/local/lib/python3.13/contextlib.py", line 214, in __aenter__
    return await anext(self.gen)
           ^^^^^^^^^^^^^^^^^^^^^
  File "/app/service.py", line 29, in lifespan
    app.state.runner = ModelRunner()
                       ~~~~~~~~~~~^^
  File "/app/model.py", line 73, in __init__
    manifest = verify_model(model_dir)
  File "/app/model.py", line 55, in verify_model
    raise FileNotFoundError(f"Model files missing in {model_dir}")
FileNotFoundError: Model files missing in /models

ERROR:    Application startup failed. Exiting.
```

## Общий журнал и его сохранность

Выбран ответ gRPC с `request_id=221647d0deda47309946eae70b0be1b4`. Запись прочитана из HTTP-контейнера до удаления обоих контейнеров и из нового HTTP-контейнера с тем же томом. Также проверено сохранение всех восьми записей текущего запуска.

До замены:

```json
{"time": 1795205311.0003958, "protocol": "grpc", "max_new_tokens": 24, "caption": "In this image we can see two cats on the couch.", "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1", "request_id": "221647d0deda47309946eae70b0be1b4", "image_sha256": "03e3947df1ec190bbcc1f3cf47e56a5b60f9415be1ba072d1837d49380538b5c"}
```

После замены:

```json
{"time": 1795205311.0003958, "protocol": "grpc", "max_new_tokens": 24, "caption": "In this image we can see two cats on the couch.", "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1", "request_id": "221647d0deda47309946eae70b0be1b4", "image_sha256": "03e3947df1ec190bbcc1f3cf47e56a5b60f9415be1ba072d1837d49380538b5c"}
```

Полные сетевые ответы: [RESULTS.md](RESULTS.md).
<!-- DOCKER_RESULTS_END -->

## Использование ИИ

Для реализации обработчиков, Dockerfile, дополнительных тестов и скрипта проверки
использовался ChatGPT. Автоматические проверки помощника перечислены в `LOCAL_CHECKS.md`.
 Я самостоятельно запустила полный скрипт проверки на своём Mac с Docker Desktop. Все 28 тестов прошли; клиент подтвердил совпадение ответов Python, HTTP и gRPC. Проверены запрет записи в каталог модели, сохранность журнала после замены контейнеров и отказ запуска без весов. Фактический вывод сохранён в RESULTS.md.

## Сдача

После успешного запуска добавьте в Git исходники, `README.md`, `LOCAL_CHECKS.md`
и `RESULTS.md`. Веса, виртуальное окружение, временные журналы и сгенерированные
`*_pb2.py` / `*_pb2_grpc.py` исключены через `.gitignore`.
Для сдачи нужны ссылка на собственный репозиторий и хеш коммита (`git rev-parse HEAD`).

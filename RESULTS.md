# Результаты проверки в Docker

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

## Сетевые ответы

```json
[
  {
    "protocol": "http",
    "caption": "In this image we can see two cats on the couch.",
    "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1",
    "request_id": "a3e248d36a9d4934aeed84b660b292b0",
    "image_sha256": "03e3947df1ec190bbcc1f3cf47e56a5b60f9415be1ba072d1837d49380538b5c"
  },
  {
    "protocol": "grpc",
    "caption": "In this image we can see two cats on the couch.",
    "request_id": "221647d0deda47309946eae70b0be1b4",
    "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1",
    "image_sha256": "03e3947df1ec190bbcc1f3cf47e56a5b60f9415be1ba072d1837d49380538b5c"
  },
  {
    "protocol": "http",
    "caption": "In this image there are flowers and plants.",
    "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1",
    "request_id": "6d4aeccd5bc747029a4adf3554233f53",
    "image_sha256": "819c4825b32253c13b84d8105c0b7ea689b5efe837f354fa212844199c0c83bc"
  },
  {
    "protocol": "grpc",
    "caption": "In this image there are flowers and plants.",
    "request_id": "78bc687d155c47b6bda0c2219261eda3",
    "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1",
    "image_sha256": "819c4825b32253c13b84d8105c0b7ea689b5efe837f354fa212844199c0c83bc"
  },
  {
    "protocol": "http",
    "caption": "In this image we can see a hand with some objects on it.",
    "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1",
    "request_id": "19db26e1f64b43ffae70f57ba8fb3af0",
    "image_sha256": "99cc4f5acf82f5f8a00654abae4aad3cb1d8df173954df612fdbf354869042aa"
  },
  {
    "protocol": "grpc",
    "caption": "In this image we can see a hand with some objects on it.",
    "request_id": "1c7397b067c34c54ab811048a6f10762",
    "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1",
    "image_sha256": "99cc4f5acf82f5f8a00654abae4aad3cb1d8df173954df612fdbf354869042aa"
  },
  {
    "protocol": "http",
    "caption": "In",
    "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1",
    "request_id": "e4c9fd1dda874592a32a5b1744b316c5",
    "image_sha256": "03e3947df1ec190bbcc1f3cf47e56a5b60f9415be1ba072d1837d49380538b5c"
  },
  {
    "protocol": "grpc",
    "caption": "In",
    "request_id": "c710ef7eba4e4c1d924cd8bd208c08ed",
    "model_version": "smolvlm-256m-7e3e67edbbed-caption-v1",
    "image_sha256": "03e3947df1ec190bbcc1f3cf47e56a5b60f9415be1ba072d1837d49380538b5c"
  }
]
```

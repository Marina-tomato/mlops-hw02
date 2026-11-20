"""Собирает фактический вывод verify.sh в отчёт, проверяя общий журнал."""

import json
from datetime import datetime, timezone
from pathlib import Path


def main():
    root = Path(__file__).resolve().parent
    state = root / "state"
    receipts = json.loads((state / "responses.json").read_text())
    assert len(receipts) == 8
    assert len({item["request_id"] for item in receipts}) == 8
    before = [json.loads(line) for line in (state / "log-before.jsonl").read_text().splitlines()]
    after = [json.loads(line) for line in (state / "log-after.jsonl").read_text().splitlines()]
    for receipt in receipts:
        matches = [row for row in before if row["request_id"] == receipt["request_id"]]
        assert len(matches) == 1, f"Missing or repeated log entry: {receipt['request_id']}"
        assert all(matches[0][key] == value for key, value in receipt.items())
        assert matches[0] in after, "Log entry lost after replacing containers"
    grpc_receipt = next(item for item in receipts if item["protocol"] == "grpc")
    request_id = grpc_receipt["request_id"]
    old_record = next(row for row in before if row["request_id"] == request_id)
    new_record = next(row for row in after if row["request_id"] == request_id)

    def output(name):
        return (state / name).read_text().strip()

    assert "9 passed" in output("pytest-given.txt")
    assert "28 passed" in output("pytest-all.txt")
    assert "OK: 4 captions × Python/HTTP/gRPC; 6 shared invalid inputs + invalid HTTP base64" in output("client.txt")
    assert "Read-only file system" in output("readonly-error.txt")
    assert "Model files missing" in output("missing-model-error.txt")
    assert json.loads(output("health.json"))["ready"] is True
    assert "gRPC ready" in output("grpc-ready.txt")

    sections = [
        "# Результаты проверки в Docker",
        f"Автоматически собраны `starter/verify.sh` в {datetime.now(timezone.utc).isoformat()}.",
        "Отчёт содержит фактический вывод команд, а не ожидаемые результаты.",
    ]
    for title, filename in [
        ("Окружение", "docker-version.txt"),
        ("Общий образ двух сервисов", "image-id.txt"),
        ("Готовые тесты", "pytest-given.txt"),
        ("Все тесты, включая два новых", "pytest-all.txt"),
        ("HTTP health", "health.json"),
        ("Готовность gRPC", "grpc-ready.txt"),
        ("Сравнение трёх способов вызова", "client.txt"),
        ("Запись в /models запрещена", "readonly-error.txt"),
        ("Запуск без весов", "missing-model-error.txt"),
    ]:
        sections.append(f"## {title}\n\n```text\n{output(filename)}\n```")
    sections.append(
        "## Общий журнал и его сохранность\n\n"
        f"Выбран ответ gRPC с `request_id={request_id}`. "
        "Запись прочитана из HTTP-контейнера до удаления обоих контейнеров "
        "и из нового HTTP-контейнера с тем же томом. "
        "Также проверено сохранение всех восьми записей текущего запуска.\n\n"
        f"До замены:\n\n```json\n{json.dumps(old_record, ensure_ascii=False)}\n```\n\n"
        f"После замены:\n\n```json\n{json.dumps(new_record, ensure_ascii=False)}\n```"
    )
    sections.append("## Сетевые ответы\n\n```json\n" + json.dumps(receipts, ensure_ascii=False, indent=2) + "\n```")
    (root.parent / "RESULTS.md").write_text("\n\n".join(sections) + "\n")
    readme_path = root.parent / "README.md"
    readme = readme_path.read_text()
    start = "<!-- DOCKER_RESULTS_START -->"
    end = "<!-- DOCKER_RESULTS_END -->"
    prefix, rest = readme.split(start, 1)
    _, suffix = rest.split(end, 1)
    # В README оставляем основные доказательства, полные ответы — в RESULTS.md.
    evidence = "\n\n".join(sections[1:-1])
    evidence += "\n\nПолные сетевые ответы: [RESULTS.md](RESULTS.md)."
    readme_path.write_text(prefix + start + "\n" + evidence + "\n" + end + suffix)
    print(f"Log OK: gRPC request_id={request_id}; all 8 records survived container replacement")


if __name__ == "__main__":
    main()

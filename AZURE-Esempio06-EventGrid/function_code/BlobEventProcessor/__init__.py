import logging
import json
import azure.functions as func


def main(event: func.EventGridEvent) -> None:
    # Event Grid trigger: log basic info about the blob event
    # Version 2.0 - Clean dependencies
    data = event.get_json() or {}
    blob_url = data.get("url") or data.get("data", {}).get("url")

    logging.info(
        "EventGrid: id=%s type=%s subject=%s url=%s",
        event.id,
        event.event_type,
        event.subject,
        blob_url,
    )

    try:
        logging.debug("Event data: %s", json.dumps(data)[:2048])
    except Exception as exc:  # pragma: no cover - defensive logging
        logging.warning("Unable to serialize event data: %s", exc)

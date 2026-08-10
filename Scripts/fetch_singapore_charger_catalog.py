#!/usr/bin/env python3
"""Fetch Singapore EV charger catalog from LTA DataMall and write app JSON."""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from datetime import date
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / "EVAi2" / "Resources" / "SingaporeChargerCatalog.json"

NETWORK_DEFAULTS = [
    {
        "networkAliases": ["Charge+", "SP Group", "SPGroup"],
        "locationKeywords": ["hdb", "mscp", "scp", "carpark"],
        "plugType": "Type 2",
        "powerRating": "AC",
        "chargingSpeedKW": 7.4,
    },
    {
        "networkAliases": ["Charge+", "SP Group", "SPGroup"],
        "locationKeywords": ["orto", "shell", "mall", "centre", "center", "business", "hub", "vivo"],
        "plugType": "CCS",
        "powerRating": "DC",
        "chargingSpeedKW": 50.0,
    },
    {
        "networkAliases": ["MNL"],
        "locationKeywords": ["verandah", "residence", "condo"],
        "plugType": "Type 2",
        "powerRating": "AC",
        "chargingSpeedKW": 7.4,
    },
]


def fetch_json(url: str, account_key: str | None = None):
    request = urllib.request.Request(url)
    request.add_header("Accept", "application/json")
    if account_key:
        request.add_header("AccountKey", account_key)
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


def network_aliases(operator_name: str) -> list[str]:
    aliases = {operator_name.strip()} if operator_name.strip() else set()
    lower = operator_name.lower()
    if "charge" in lower:
        aliases.update({"Charge+", "SP Group", "SPGroup"})
    if "shell" in lower:
        aliases.add("Shell Recharge")
    if "tesla" in lower:
        aliases.add("Tesla")
    return sorted(aliases)


def import_lta_payload(payload) -> list[dict]:
    stations = payload
    if isinstance(payload, dict):
        stations = payload.get("value") or payload.get("data") or payload.get("stations") or []

    entries: list[dict] = []
    seen: set[str] = set()

    for station in stations:
        address = str(station.get("address", "")).strip()
        name = str(station.get("name", "")).strip()
        operator_name = str(station.get("operator", "")).strip()
        position = str(station.get("position", "")).strip()
        location_id = str(station.get("locationId", "")).strip()

        for charger in station.get("chargers", []) or []:
            charger_name = str(charger.get("name", "")).strip()
            for point in charger.get("chargingPoints", []) or []:
                connector_id = str(point.get("evCpId", "")).strip()
                plug_type = str(point.get("plugType", "")).strip()
                power_rating = str(point.get("powerRating", "")).strip()
                charging_speed = float(point.get("chargingSpeed") or 0)
                entry_id = "|".join(
                    part
                    for part in [location_id, connector_id, plug_type, str(charging_speed)]
                    if part
                )
                if not entry_id or entry_id in seen:
                    continue
                seen.add(entry_id)
                entries.append(
                    {
                        "id": entry_id,
                        "name": " · ".join(part for part in [name, charger_name] if part),
                        "address": address,
                        "operator": operator_name,
                        "networkAliases": network_aliases(operator_name),
                        "position": " · ".join(part for part in [position, str(charger.get("position", "")).strip()] if part),
                        "connectorIds": [connector_id] if connector_id else [],
                        "plugType": plug_type,
                        "powerRating": power_rating,
                        "chargingSpeedKW": charging_speed,
                    }
                )

    return sorted(entries, key=lambda item: item["name"].lower())


def main() -> int:
    account_key = os.environ.get("LTA_DATAMALL_ACCOUNT_KEY", "").strip()
    if not account_key:
        print("Set LTA_DATAMALL_ACCOUNT_KEY to fetch the live LTA catalog.", file=sys.stderr)
        return 1

    link_payload = fetch_json(
        "https://datamall2.mytransport.sg/ltaodataservice/EVCBatch",
        account_key=account_key,
    )
    link = link_payload.get("link")
    if not link:
        print("LTA batch link missing from response.", file=sys.stderr)
        return 1

    batch_payload = fetch_json(link)
    entries = import_lta_payload(batch_payload)
    catalog = {
        "version": 1,
        "source": "lta-datamall",
        "updatedAt": date.today().isoformat(),
        "entries": entries,
        "networkDefaults": NETWORK_DEFAULTS,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(catalog, indent=2), encoding="utf-8")
    print(f"Wrote {len(entries)} entries to {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

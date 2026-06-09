# Backend TLS- & Domain-Migrationsplan — `api.gamssinn.app`

> Stand: 2026-06-09. Ziel: Weg vom self-signed Cert auf `https://178.104.159.28`
> hin zu einer echten Subdomain `api.gamssinn.app` mit gueltigem (CA-signiertem)
> Zertifikat.
>
> **Warum zwingend:** RevenueCat liefert Webhooks NUR an Endpoints mit gueltigem,
> oeffentlich vertrauenswuerdigem TLS-Zertifikat aus. Ein self-signed Cert (wie
> aktuell auf der IP) wird von den RevenueCat-Servern abgelehnt → der
> `/revenuecat-webhook`-Endpoint bekommt nie Events → Abo-Status wird nie in
> Supabase gecached → das Entitlement-Gate erkennt Premium nicht. Ohne gueltiges
> Cert ist die gesamte Kostenbremse + Monetarisierung nicht produktiv schaltbar.

---

## IST-Zustand

- Backend laeuft auf Hetzner unter `/opt/waidblick/`, systemd-Service `waidblick`,
  uvicorn auf Port 80 (siehe `backend/install.sh`) bzw. 8080 (Healthcheck im
  `deploy_backend.yml`). TLS aktuell self-signed direkt auf der IP `178.104.159.28`.
- Flutter-Client umgeht das self-signed Cert mit `badCertificateCallback => true`
  (`lib/services/vision_api_service.dart`). RevenueCat kann das **nicht**.
- Deploy: GitHub Actions `deploy_backend.yml` scp't `backend/main.py` nach
  `/opt/waidblick/main.py` und `systemctl restart waidblick`.

## ZIEL-Zustand

```
RevenueCat / Client ──HTTPS──▶ api.gamssinn.app (gueltiges Cert)
                                      │  (Reverse Proxy: Caddy ODER nginx)
                                      ▼
                               127.0.0.1:8080  (uvicorn, waidblick.service)
```

---

## Schritt 1 — Domain & DNS (haengt an Domain-Kauf)

> **GATE — nur Alex:** `gamssinn.app` muss gekauft/registriert sein. Solange die
> Domain nicht in einem DNS-Konto liegt, ist dieser Schritt blockiert.

1. Domain `gamssinn.app` registrieren (falls noch nicht geschehen) — Gate, Kosten.
2. DNS **A-Record** anlegen:
   | Typ | Name | Wert | TTL |
   |-----|------|------|-----|
   | A   | `api` | `178.104.159.28` | 300 |
   → ergibt `api.gamssinn.app → 178.104.159.28`.
3. Propagation abwarten (`dig api.gamssinn.app +short` muss die Hetzner-IP liefern).
   Lets-Encrypt-/Caddy-Cert-Ausstellung schlaegt fehl, solange der A-Record nicht
   aufloest.

> Hinweis `.app`-TLD: ist HSTS-preloaded → erzwingt ohnehin HTTPS. Kein reines
> HTTP moeglich, was die self-signed-Loesung endgueltig ausschliesst.

---

## Schritt 2 — Reverse Proxy mit gueltigem Cert (Empfehlung: Caddy)

**Empfehlung Caddy** (automatisches Lets-Encrypt, minimale Config, Auto-Renewal):

```
# /etc/caddy/Caddyfile
api.gamssinn.app {
    reverse_proxy 127.0.0.1:8080
}
```

Installation auf Hetzner (Ubuntu):
```
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
# Caddy-Repo-Key + Repo hinzufuegen (offizielle Caddy-Doku), dann:
apt-get update && apt-get install -y caddy
# Caddyfile schreiben (siehe oben), dann:
systemctl reload caddy
```
Caddy holt das Cert beim ersten Request automatisch (ACME HTTP-01, Port 80 muss
offen sein) und erneuert es selbst.

**Alternative nginx + certbot** (falls nginx schon laeuft):
```
apt-get install -y nginx certbot python3-certbot-nginx
# server-block fuer api.gamssinn.app mit proxy_pass http://127.0.0.1:8080;
certbot --nginx -d api.gamssinn.app   # stellt Cert aus + konfiguriert TLS + Renewal-Timer
```

### Port-Anpassung am Backend (wichtig!)
Aktuell startet `install.sh` uvicorn auf **Port 80**. Mit Reverse Proxy muss
uvicorn **intern** laufen (z.B. 8080) und Port 80/443 gehoeren dem Proxy:
- `ExecStart=/opt/waidblick/venv/bin/uvicorn main:app --host 127.0.0.1 --port 8080`
  (in `/etc/systemd/system/waidblick.service`, `--host 127.0.0.1` statt `0.0.0.0`,
  damit das Backend NICHT mehr direkt aus dem Netz erreichbar ist — nur ueber den Proxy).
- `systemctl daemon-reload && systemctl restart waidblick`.
- Firewall: Port 80 + 443 offen (fuer Caddy/ACME + HTTPS), 8080 NICHT von aussen.

---

## Schritt 3 — Backend-/Config-Anpassungen

### 3a. CORS (`backend/main.py`)
`allow_origins` um die neue Domain ergaenzen (aktuell nur ngrok + localhost):
```python
allow_origins=[
    "https://api.gamssinn.app",
    "https://gamssinn.app",
    "https://crinal-pervertible-colette.ngrok-free.dev",
    "http://localhost:3000",
    "http://localhost:8900",
    "http://localhost:8080",
],
```

### 3b. ENV (`/opt/waidblick/.env`)
Neu zu setzen (fuer Webhook + Gate, siehe `revenuecat_integration_plan.md`):
```
SUPABASE_SERVICE_KEY=<service-role-key>     # noetig fuer Gate + Webhook-PATCH
REVENUECAT_WEBHOOK_SECRET=<frei waehlbar>   # identisch im RC-Dashboard setzen
ENTITLEMENT_GATE_ENABLED=false              # erst auf true wenn RC/Banking live
FREE_DAILY_LIMIT=5                          # optional, Default 5
```
> `deploy_backend.yml` schreibt aktuell nur `GEMINI_API_KEY` + `OPENAI_API_KEY`
> ins `.env` und **ueberschreibt** die Datei bei jedem Deploy. Vor Scharfschaltung:
> den `Write env file`-Step im Workflow um die obigen Variablen erweitern (Werte
> aus GitHub-Secrets), sonst gehen sie beim naechsten Deploy verloren.

### 3c. Client (`lib/services/vision_api_service.dart`)
- Basis-URL von `https://178.104.159.28` auf `https://api.gamssinn.app` umstellen.
- `badCertificateCallback => true` **entfernen** (mit gueltigem Cert nicht mehr
  noetig und ein Sicherheitsrisiko — akzeptiert sonst jedes MITM-Cert).

### 3d. RevenueCat-Dashboard
- Webhook-URL auf `https://api.gamssinn.app/revenuecat-webhook` setzen,
  Authorization-Header == `REVENUECAT_WEBHOOK_SECRET` (3b).

---

## Reihenfolge / Abhaengigkeiten

| # | Schritt | Wer | Gate |
|---|---------|-----|------|
| 1 | Domain `gamssinn.app` kaufen | **Alex** | Kosten, irreversibel |
| 2 | A-Record `api` → `178.104.159.28` | Alex (DNS-Konsole, 1 Eintrag) | nach 1 |
| 3 | Caddy/nginx + Cert auf Hetzner | Code-Agent (SSH) | nach 2 (DNS muss aufloesen) |
| 4 | uvicorn auf 127.0.0.1:8080, Proxy davor | Code-Agent | nach 3 |
| 5 | CORS + ENV + Client-URL anpassen | Code-Agent | nach 3 |
| 6 | RC-Webhook-URL + Secret setzen | Alex (1 Eingabe) | nach 4+5 |
| 7 | Webhook-Test (RC „Send test event") → profiles-Row | beide | nach 6 |

> Erst wenn Schritt 7 gruen ist (Test-Event landet in Supabase profiles), darf
> `ENTITLEMENT_GATE_ENABLED=true` gesetzt werden.

---

## Fallback ohne Domain-Kauf (Uebergang)

Falls die Domain noch nicht gekauft ist, kann der Webhook uebergangsweise ueber
die **bestehende ngrok-Domain** `https://crinal-pervertible-colette.ngrok-free.dev`
laufen (gueltiges ngrok-Cert, von RevenueCat akzeptiert). Nachteile: ngrok-Free
ist nicht stabil/dauerhaft (Tunnel kann wechseln) und ungeeignet fuer Prod.
Nur als Brueckenloesung fuer Sandbox-Webhook-Tests — die Ziel-Architektur bleibt
`api.gamssinn.app`.

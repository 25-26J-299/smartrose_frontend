## SMARTROSE — IoT + ML Decision Support for Greenhouse Rose Cultivation

SMARTROSE is a multi-component system for **monitoring greenhouse rose cultivation** using **IoT sensor data**, **machine learning**, and a **Flutter mobile app**.

It includes four modules:
- **INM** — Intelligent Nutrient Management
- **EOSM** — Energy-Optimized Stress Monitoring
- **EDAS** — Early Disease Alerting System
- **FM** — Freshness Monitoring


### Project Overview

**High-level flow**: sensors → ESP32/LoRa → backend API → MongoDB → ML inference → recommendations/alerts → mobile dashboard.

This workspace contains:
- **Common/system repos**: `smartrose_backend/` (FastAPI gateway) + `smartrose_frontend/` (Flutter app)
- **Individual component repos**: `smartrose-inm/`, `smartrose-eosm/`, `smartrose-edas/`, `smartrose-fm/` (training/docs/IoT/artifacts)

---

### Architecture

- **Architecture diagram **:

![SMARTROSE System Architecture](https://mysliit-my.sharepoint.com/:i:/g/personal/it22326522_my_sliit_lk/IQBiADF5Sib5T6ZpUIdtIAokAeALnCUDy57DtLRrc1P23lo?e=3xmeR7)

- **Text-based diagram **:

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           Field / Lab Environment                            │
│  IoT Sensors (NPK, EC, pH, soil temp/moisture, air temp/humidity, etc.)     │
└───────────────────────────────┬────────────────────────────────────────────┘
                                │ HTTP/JSON
                                ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                     smartrose_backend (FastAPI + MongoDB)                   │
│                                                                            │
│  API layer (v1)                                                           │
│   - INM  : /api/v1/inm/*                                                  │
│   - EOSM : /api/v1/eosm/*               │
│   - EDAS : /api/v1/edas/*                    │
│   - FM   : /api/v1/fm/*                                                   │
│                                                                            │
│  ML inference layer (per module; depends on local model artifacts)          │
│   - INM  : app/ml/inm/inm_inference.py                                      │
│   - EOSM : app/ml/eosm/eosm_inference.py                                    │
│   - FM   : app/ml/fm/fm_inference.py                                        │
│   - EDAS : app/services/edas_ml_service.py                                  │
│                                                                            │
│  Persistence: MongoDB collections (sensor readings, predictions, actions)   │
└────────────────────────────────────────────────────────────────────────────┘
                                │ JSON over HTTP
                                ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                  smartrose_frontend (Flutter mobile app)                   │
│  - dashboard + module screens + charts                                     │
└────────────────────────────────────────────────────────────────────────────┘
```

---

### Repository Structure

This workspace contains **two common (system-level) repos** and multiple **individual component repos**.

- **Common / system repos**
  - **`smartrose_backend/`**: unified **FastAPI + MongoDB** backend gateway.
    - **Entry point**: `smartrose_backend/app/main.py`
    - **API routing**: `smartrose_backend/app/api/v1/router.py`
    - **Local config template**: `smartrose_backend/env.example` (copy to `smartrose_backend/.env` locally)

  - **`smartrose_frontend/`**: Flutter mobile app (UI + API client).
    - **Entry point**: `smartrose_frontend/lib/main.dart`

- **Individual component repos (training / docs / experiments / artifacts)**
  - **`smartrose-inm/`**: INM (IoT + ML training + artifacts + docs)
  - **`smartrose-eosm/`**: EOSM (training + artifacts + docs; also contains a standalone service)
  - **`smartrose-edas/`**: EDAS (training + docs; integration can be expanded in the gateway)
  - **`smartrose-fm/`**: FM (training + artifacts + docs)

---

### Component Details (INM / EOSM / EDAS / FM)

Below is an evaluator-friendly summary of each component: **goal**, **inputs**, **outputs**, and where the **runtime implementation** lives.

#### INM — Intelligent Nutrient Management

- **Goal**: provide nutrient management support using live sensor values and an EC(24h) forecast model.
- **Main inputs** (per reading): N, P, K, EC, pH, soil_temp, soil_moisture, air_temp, air_hum.
- **Outputs**:
  - `predicted_ec_24h` (ML; **requires artifacts**)
  - `ec_status`, `ec_action`, `ph_action`, `npk_recommendation` (rule-based recommendations)
  - action history (applied/ignored)
- **Gateway endpoints**: `GET /api/v1/inm/status`, `POST /api/v1/inm/sensor-data`, `POST /api/v1/inm/action`, `GET /api/v1/inm/action-history`, `GET/POST /api/v1/inm/growth-stage`
- **Backend implementation (gateway)**:
  - `smartrose_backend/app/api/v1/endpoints/inm.py`
  - `smartrose_backend/app/services/inm_service.py`
  - `smartrose_backend/app/ml/inm/inm_inference.py`
- **Artifacts**: `inm_ec_rf_model.pkl`, `inm_ec_scaler.pkl` loaded via `INM_MODEL_DIR`
- **Training/docs repo**: `smartrose-inm/` (`iot/`, `ml/`, `docs/`)

#### EOSM — Energy-Optimized Stress Monitoring

- **Goal**: classify plant stress from environmental/IoT readings and persist predictions.
- **Typical inputs** (per reading): temperature, humidity, UV voltage, soil voltage, MQ voltage.
- **Outputs**: `stress_label` + `stress_probabilities` (ML) + stored prediction history.
- **Backend implementation (gateway)**:
  - Orchestration: `smartrose_backend/app/services/eosm_ml_service.py`
  - IoT ingest integration: `smartrose_backend/app/services/eosm_iot_service.py`
  - ML inference: `smartrose_backend/app/ml/eosm/eosm_inference.py`
  - DB: `smartrose_backend/app/db/collections/eosm_*`
- **Artifacts (required)**: `stress_model_rf.pkl`, `stress_scaler.pkl`, `stress_label_encoder.pkl`
- **Training/docs repo**: `smartrose-eosm/` (`ml/`, `README.md`)

#### EDAS — Early Disease Alerting System

- **Goal**: predict disease risk early using sensor-driven conditions (temperature/humidity patterns).
- **Typical inputs**: plant_temperature, air_temperature, humidity (+ time features).
- **Outputs**: disease risk level + confidence + alerts + recommendations.
- **Backend implementation (gateway)**:
  - REST: `smartrose_backend/app/api/v1/endpoints/edas_data.py`
    - `POST /api/v1/edas-data/` (ingest)
    - `GET /api/v1/edas-data/latest-with-prediction` (dashboard card)
  - WebSocket live updates: `smartrose_backend/app/api/v1/endpoints/edas_websocket.py`
    - `ws://localhost:8000/api/v1/edas-data/ws/edas/live`
  - Services: `smartrose_backend/app/services/edas_service.py`, `smartrose_backend/app/services/edas_ml_service.py`
- **Training/docs repo**: `smartrose-edas/` (`docs/`, `ml/`)

#### FM — Freshness Monitoring

- **Goal**: predict freshness / vase life from sensor inputs and produce alerts.
- **Inputs** (per reading): air_temperature, water_temperature, humidity, gas_value, water_level.
- **Outputs**: freshness score, vase life estimate, alerts.
- **Backend implementation (gateway)**:
  - Endpoints: `smartrose_backend/app/api/v1/endpoints/fm.py`
  - Local inference wrapper: `smartrose_backend/app/services/fm_ml_service.py`
  - Model inference: `smartrose_backend/app/ml/fm/fm_inference.py`
  - (Legacy) fallback service: `smartrose_backend/app/services/fm_service.py` (uses `FM_MODEL_PATH`)
- **Artifacts**: `freshness_model.pkl`, `vase_life_model.pkl` (via `FM_MODEL_DIR` or auto-detected from `smartrose-fm/ml/models/`)
- **Training/docs repo**: `smartrose-fm/` (`ml/`, `docs/`)

---

### Technologies / Dependencies

- **Backend** (`smartrose_backend/requirements.txt`)
  - FastAPI, Uvicorn, Motor (MongoDB), Pydantic, joblib, scikit-learn, numpy, pandas, python-jose, passlib[bcrypt], httpx
- **Frontend** (`smartrose_frontend/pubspec.yaml`)
  - Flutter (Dart), http/dio, provider, flutter_secure_storage, intl, syncfusion_flutter_charts, geolocator

---

### How to Run Locally

#### Backend (FastAPI gateway)

From `smartrose_backend/`:

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

- **Health check**: `GET /health`

#### Frontend (Flutter)

From `smartrose_frontend/`:

```bash
flutter pub get
flutter run

```

---

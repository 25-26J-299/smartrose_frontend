# **smartrose-frontend**

### *SMARTROSE Mobile & Web Application (Flutter Frontend)*

[![Flutter](https://img.shields.io/badge/flutter-3.x-blue)]()
[![Status](https://img.shields.io/badge/platform-Mobile%20%7C%20Web-green)]()
[![License](https://img.shields.io/badge/license-MIT-black)]()

---

## 📘 **Overview**

**smartrose-frontend** is the official Flutter-based **mobile and web application** for the SMARTROSE greenhouse monitoring system.
It provides real-time plant stress insights, sensor dashboards, history visualization, and energy optimization feedback — all accessible from both smartphones and browsers.

This frontend integrates seamlessly with the SMARTROSE backend APIs, ML inference services, and IoT gateway.

---

## 🎯 **Core Objectives**

* Deliver a **cross-platform Flutter UI** for Android, iOS, and Web
* Visualize real-time and historical greenhouse sensor data
* Display ML-driven plant stress predictions
* Present energy optimization recommendations
* Provide secure, responsive, and user-friendly access to SMARTROSE services

---

## ✨ **Features**

* 📊 **Real-time dashboards** (Temp, Humidity, Soil Moisture, UV, Gas, etc.)
* 🌱 **Plant stress prediction displays**
* ⚡ **Energy optimization insight panels**
* 🌐 **Responsive Web UI** (browser-ready)
* 📁 **Historical data visualization** (charts/logs)
* 🔐 **User authentication & session management**
* 🎨 **Material Design 3 responsive interface**
* 🔗 **REST API integration with SMARTROSE backend**

---

## 🏗️ **Project Structure**

```
smartrose-frontend/
├── lib/
│   ├── ui/                     # Screens, widgets, components
│   ├── models/                 # Data models
│   ├── services/               # API and network logic
│   ├── providers/              # State management (Provider/Riverpod)
│   └── main.dart               # App entry point
│
├── assets/                     # Images, icons, fonts
├── web/                        # Web-specific assets, index.html
├── test/                       # Unit and widget tests
└── pubspec.yaml                # App configuration & dependencies
```

---

## 🧬 **Architecture**

The application follows a **clean, layered architecture**:

* **UI Layer** → Screens, widgets
* **State Layer** → Provider/Riverpod
* **Service Layer** → API client, data fetchers
* **Model Layer** → Strongly typed data structures

This design ensures scalability and maintainability across mobile and web platforms.

---

## ⚙️ **Setup & Installation**

### **1. Install Flutter**

Follow the official guide:
[https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)

### **2. Clone the repository**

```bash
git clone https://github.com/yourusername/smartrose-frontend.git
cd smartrose-frontend
```

### **3. Install dependencies**

```bash
flutter pub get
```

### **4. Run on Mobile**

```bash
flutter run
```

### **5. Run on Web**

```bash
flutter run -d chrome
```

### **Build Web Release**

```bash
flutter build web
```

---

## 📡 **Environment Configuration**

Create a `.env` file (using flutter_dotenv):

```
API_BASE_URL=https://your-api-url.com
AUTH_ENDPOINT=/auth/login
SENSOR_DATA_ENDPOINT=/sensor/readings
STRESS_PREDICTION_ENDPOINT=/ml/stress
```

---

## 🧪 **Testing**

Run all tests:

```bash
flutter test
```

---

## 🎨 **Design Standards**

The UI adheres to:

* Material Design 3
* Responsive breakpoints for **mobile, tablet, and web**
* Consistent color and typography system
* Accessible and scalable widget composition

---

## 💻 **Coding Standards**

* **Dart Lints** enabled
* Follows Flutter style guidelines
* Clean folder structure
* Reusable components
* Google-style documentation comments
* Static analysis required before merge:

  ```bash
  flutter analyze
  ```

---

## 🤝 **Contribution Guidelines**

1. Fork the repository
2. Create a new feature branch
3. Write clean commits (`feat:`, `fix:`, `docs:`)
4. Ensure code passes all lint checks
5. Submit a Pull Request with a detailed description

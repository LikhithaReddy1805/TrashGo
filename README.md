# TrashGo – Garbage Collection & Monitoring App

TrashGo is a Flutter-based garbage collection and monitoring application designed to improve waste management through digital coordination between residents, drivers, and administrators.

## Features

- **Resident Module:** Enables residents to interact with the garbage collection system.
- **Driver Module:** Supports drivers in managing garbage collection activities.
- **Admin Dashboard:** Provides administrative monitoring and management features.
- **Live Location Tracking:** Uses map integration to support location-based monitoring.
- **Firebase Integration:** Uses Firebase services for authentication, database operations, storage, and notifications.

## Technology Stack

- **Frontend:** Flutter, Dart
- **Backend and Database:** Firebase, Cloud Firestore
- **Authentication:** Firebase Authentication
- **Storage:** Firebase Storage
- **Notifications:** Firebase Cloud Messaging
- **Maps:** Google Maps API, OpenStreetMap (`flutter_map`), GeoFire

## Project Structure

```text
lib/
├── dashboards/
│   ├── admin_dashboard.dart
│   ├── driver_dashboard.dart
│   ├── resident_dashboard.dart
│   └── ...
├── services/
├── shared/
├── main.dart
├── login_page.dart
└── ...
assets/
android/
ios/
web/
```

## Getting Started

1. Clone the repository:

   ```bash
   git clone https://github.com/LikhithaReddy1805/TrashGo.git
   ```

2. Navigate to the project directory:

   ```bash
   cd TrashGo
   ```

3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. Configure your own Firebase project and required platform-specific configuration files.

5. Run the application:

   ```bash
   flutter run
   ```

## Project Status

Developed as an academic project.

## Author

**Likhitha Reddy**

- GitHub: https://github.com/LikhithaReddy1805
- LinkedIn: https://linkedin.com/in/likhitha-reddy-b

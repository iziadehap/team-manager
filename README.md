<div align="center">

# ✓ TeamTask

**A modern Flutter app for collaborative task management**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![BLoC](https://img.shields.io/badge/State-BLoC%20%2F%20Cubit-339af0)](https://bloclibrary.dev)
[![License](https://img.shields.io/badge/License-MIT-brightgreen)](LICENSE)

_Collaborate. Track. Achieve._

</div>

---

## 📱 Screenshots

> Coming soon — run the app to see the polished UI in action!

---

## ✨ Features

- 🔐 **Authentication** — Email/password sign-in & registration with Firebase Auth
- 👥 **Teams** — Create teams, invite members via code, manage roles
- 📋 **Tasks** — Create, assign, filter, and track tasks by status
- 💬 **Comments** — Real-time comments on every task
- 🌙 **Dark mode** — Full light & dark theme with persistent preference
- ⚡ **Live updates** — Firestore streams keep everything in sync instantly
- 📊 **Personal stats** — View your completed vs pending task count

---

## 🎨 UI Design

The app uses a custom design system built on Material 3:

| Token         | Value                      |
| ------------- | -------------------------- |
| Primary       | `#6C63FF` (violet)         |
| Accent        | `#00D4AA` (teal)           |
| Font          | Nunito (rounded, friendly) |
| Card radius   | `20px`                     |
| Button radius | `16px`                     |

### Animations

- Staggered list entry animations
- Smooth page transitions
- Elastic splash screen logo
- Password strength indicator
- Press-scale micro-interactions on cards and buttons
- Shimmer skeleton loaders

---

## 🏗️ Architecture

```
lib/
├── app/
│   ├── app.dart                 # App widget + routing
│   └── theme/
│       └── app_theme.dart       # Light/dark themes + AppColors
├── core/
│   ├── constants/               # App-wide constants
│   ├── errors/                  # Custom exceptions
│   ├── router/                  # GoRouter refresh notifier
│   └── utils/                   # Invite code generator
├── cubits/
│   ├── auth/                    # AuthCubit + AuthState
│   └── theme/                   # ThemeCubit + ThemeState
├── features/
│   ├── auth/                    # Login & Register screens
│   ├── profile/                 # Profile screen
│   ├── splash/                  # Animated splash screen
│   ├── tasks/                   # Tasks list, detail, create
│   └── teams/                   # Teams list, create, join, members
├── models/                      # Firestore data models
├── router/                      # GoRouter configuration
├── services/                    # Firebase service layer
└── widgets/                     # Shared UI components
```

**Pattern:** Feature-first with BLoC/Cubit for state management and a service layer for Firebase access.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.10.0`
- Dart SDK `>=3.0.0`
- A Firebase project with Firestore and Authentication enabled

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-username/team-task.git
cd team-task

# 2. Install dependencies
flutter pub get

# 3. Configure Firebase
#    - Create a Firebase project at console.firebase.google.com
#    - Enable Email/Password authentication
#    - Enable Firestore database
#    - Run FlutterFire CLI to generate firebase_options.dart
flutterfire configure

# 4. Run the app
flutter run
```

### Firebase Firestore Rules (recommended)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      allow read: if request.auth != null;
    }
    match /teams/{teamId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    match /teams/{teamId}/tasks/{taskId} {
      allow read, write: if request.auth != null;
    }
    match /teams/{teamId}/tasks/{taskId}/comments/{commentId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 📦 Dependencies

| Package           | Purpose                       |
| ----------------- | ----------------------------- |
| `firebase_core`   | Firebase initialization       |
| `firebase_auth`   | User authentication           |
| `cloud_firestore` | Real-time database            |
| `flutter_bloc`    | State management (BLoC/Cubit) |
| `go_router`       | Declarative navigation        |
| `intl`            | Date formatting               |

---

## 🗺️ Roadmap

- [ ] Push notifications (FCM)
- [ ] Task edit screen
- [ ] File attachments on tasks
- [ ] Team admin controls
- [ ] Password reset email
- [ ] Onboarding flow
- [ ] Offline support

---

## 🤝 Contributing

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<div align="center">
Made with ❤️ and Flutter
</div>

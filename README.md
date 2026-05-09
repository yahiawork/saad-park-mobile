# Phone Saad Park

Flutter mobile client for the Saad Park Flask backend.

The phone app is login-only. Accounts are created from the web app, then the
mobile app keeps the session saved until the user explicitly logs out.

Default backend:

```txt
https://saadpark.pythonanywhere.com
```

Run with another backend:

```bash
flutter run --dart-define=SAADPARK_API_BASE=http://127.0.0.1:5000
```

If this folder was created before Flutter was installed, scaffold platform files once:

```bash
cd "phone saadpark"
flutter create .
flutter pub get
flutter run
```

The app uses the backend API under `/api/mobile/...`.

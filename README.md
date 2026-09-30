# B-Mark

B-Mark is a universal Android bookmarking utility built with Flutter. It solves the problem of losing track of short-form videos (TikToks, Instagram Reels, Facebook Reels) by acting as a central hub. Instead of copying and pasting links, simply use the native Android "Share" menu on any video and select **B-Mark** to instantly save and categorize the link.

## 🚀 Features

* **Native Share Sheet Integration:** Appears directly in the Android share menu when sharing text or URLs from other apps.
* **Auto-Categorization:** Automatically detects and categorizes incoming links based on their source platform (TikTok, Instagram, Facebook, YouTube, etc.).
* **Background Processing:** Captures links whether the app is running in the background or completely closed.
* **Clean UI:** Simple, distraction-free interface to view all your saved bookmarks in one place.

## 🛠️ Tech Stack

* **Framework:** Flutter (Dart)
* **Platform:** Android
* **Key Packages:**
  * [`flutter_sharing_intent`](https://pub.dev/packages/flutter_sharing_intent) (Handles incoming native share intents)

## ⚙️️ Setup and Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Trend74X/b-mark.git
   cd b-mark
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Android Configuration:**
   This app requires specific intent filters in the `AndroidManifest.xml` to receive shared text. This is already configured in `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <intent-filter>
       <action android:name="android.intent.action.SEND" />
       <category android:name="android.intent.category.DEFAULT" />
       <data android:mimeType="text/plain" />
   </intent-filter>
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

## 📱 How to Use

1. Open a social media app (e.g., Instagram, TikTok).
2. Find a reel or video you want to save.
3. Tap the **Share** button.
4. Select **B-Mark** from the list of available apps.
5. Open B-Mark to see your automatically categorized and saved link!
6. Tap on the saved link to open the related app with the post.

## * Features
1. Implemented local database storage SQLite for offline persistence.
2. Fetch and display URL metadata (thumbnails and titles) for a better visual experience.
3. Add link deletion and manual editing capabilities.

## 🚧 Upcoming Features (Roadmap)

* [ ] Cloud sync capabilities (Firebase/Supabase).
* [ ] iOS Support via Swift Package Manager & App Groups.

## 📄 License

This project is licensed under the MIT License.
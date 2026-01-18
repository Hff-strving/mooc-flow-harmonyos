<div align="right">
  <a href="README.md"><img alt="English" src="https://img.shields.io/badge/language-English-blue"></a>
  <a href="README.zh-CN.md"><img alt="简体中文" src="https://img.shields.io/badge/语言-简体中文-red"></a>
</div>

# MOOC Flow (智学流) - HarmonyOS ArkTS Course Project

An efficiency-focused education app based on a trimmed subset of the open **MOOCCube** dataset, featuring **Course Discovery**, **Study Plan (Favorites)**, **Focus Timer**, **White Noise / Music Companion**, **Study Analytics**, and **System Share**.

## Features

- Auth: register & login with local SQLite (HarmonyOS RDB)
- Course discovery: category filters + search + course list (from `entry/src/main/resources/rawfile/mooc_data.json`)
- Course detail: cover/info; favorite (study plan); start focus; share via system messaging ability
- Focus: Pomodoro-style timer (15/25/45 + custom duration), start/pause/resume/stop, writes study records to DB
- Audio: discover audio in `resources/rawfile/` and play via AVPlayer; playback failure does not block the timer (with toast)
- Profile: total focus minutes, study count, favorite count; top-3 ranking; recent study; study plan list

## Tech Stack

- UI: ArkTS + ArkUI (declarative UI)
- Routing: `@ohos.router`
- Local DB: `@ohos.data.relationalStore` (RdbStore / SQLite)
- Audio: `@ohos.multimedia.media` (AVPlayer)
- Resources: `resourceManager` (rawfile / media)

## Pages & Code Structure

Pages (`entry/src/main/ets/pages`):

- `LoginPage.ets`: register / login
- `HomePage.ets`: course discovery + search/filter + stats cards
- `DetailPage.ets`: course detail + favorite + share + jump to focus
- `FocusPage.ets`: focus timer + custom duration + audio selection/playback
- `ProfilePage.ets`: profile + stats + top-3 + recent + study plan

Core utils (`entry/src/main/ets/utils`):

- `DatabaseHelper.ets`: schema + auth + favorites + study records + stats cache refresh
- `FocusSessionManager.ets`: focus session lifecycle (timer, pause, commit on finish)
- `CourseRepository.ets`: loads `mooc_data.json` and caches courses
- `AudioDiscovery.ets`: discovers rawfile audio (manifest fallback)
- `AudioManager.ets`: AVPlayer wrapper (load/play/pause/stop + error callbacks)

## Data & Resources

- Courses: `entry/src/main/resources/rawfile/mooc_data.json` (trimmed MOOCCube subset)
- Audio manifest: `entry/src/main/resources/rawfile/audio_manifest.json`
- Audio files: `entry/src/main/resources/rawfile/*.mp3` / `*.wav`
- Covers/icons: `entry/src/main/resources/base/media/` (and other project folders as used)

## Database (SQLite / RDB)

Database name: `mooc_flow.db` (see `entry/src/main/ets/utils/DatabaseHelper.ets`).

Tables:

- `User` (unique `username`)
- `Favorite` (unique `(user_id, course_id)`)
- `StudyRecord` (`duration` in seconds; `course_id='noise'` for white-noise focus)

The DB file is stored in the app sandbox (bundle name in `AppScope/app.json5`), e.g.:

- `/data/storage/el2/database/<bundleName>/rdb/mooc_flow.db`
- `/data/storage/el1/database/<bundleName>/rdb/mooc_flow.db`

## Build & Run

Recommended: open and run with **DevEco Studio**.

Optional CLI build:

- Set SDK path (example): `DEVECO_SDK_HOME=E:\DevEco Studio\sdk`
- Build: `E:\DevEco Studio\tools\hvigor\bin\hvigorw.bat -p entry assembleHap --no-daemon`

## Notes

This is a course project. Passwords are stored in plaintext for demonstration purposes only; production apps should use salted hashing.

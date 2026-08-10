<p align="center">
  <img src="assets/pusula_app.png" width="140">
</p>

<h1 align="center">Pusula</h1>

<p align="center">
  Your Personal Productivity Companion
</p>

<p align="center">
  AI-powered habit & productivity management application
</p>

<p align="center">
  Flutter • Dart • Groq API • Llama 3.3 • Hive
</p>

<p align="center">
  
[![Live Demo](https://img.shields.io/badge/🌐_Live_Demo-Pusula-6C63FF?style=for-the-badge)](https://mustafablak.github.io/pusula-ai-life-coach-app/)

</p>
## 📱 About the Project

**Pusula** is a cross-platform personal development and habit management
application designed to help users build consistent daily routines,
track their progress, improve focus, and maintain long-term motivation.

The application combines **AI-powered assistance, gamification,
habit tracking, journaling, reading tracking and focus tools** within
a single mobile experience.

Pusula supports both **Turkish 🇹🇷 and English 🇬🇧** interfaces.
---

## ✨ Key Features

### 🤖 Rota AI — Personalized AI Assistant

Pusula includes **Rota**, an AI-powered personal assistant designed
specifically around the user's goals and daily tasks.

Rota can:

- Analyze the user's incomplete daily goals
- Provide information about today's tasks
- Respond to questions related to the application and productivity
- Generate personalized motivational messages
- Provide context-aware responses based on the user's progress

The AI layer is powered by **Groq API** and **Llama 3.3 70B**.

---

### 🌱 Oasis Gamification System

Pusula uses a visual progression system called **Oasis** to encourage
consistent user engagement.

As users complete their daily goals:

`Daily Goals → Water Drops → Oasis Progression`

The user's oasis evolves through multiple stages:

- 🏜️ Dry Land
- 🌱 Sprouting Seed
- 🌳 Growing Tree
- 🌴 Flourishing Oasis

This gamification mechanism transforms abstract habit progress into
a visible and rewarding experience.

---

### 🎯 Daily Goals & Habit Tracking

Users can:

- Select their interests during onboarding
- Receive automatically generated daily goals
- Create custom goals
- Delete unwanted goals
- Mark completed goals
- Track daily completion progress
- Maintain a daily streak

The application dynamically adapts the daily goal experience based
on the user's selected interests.

---

### ⏱️ Focus & Pomodoro

The Focus module provides a customizable study/productivity timer.

Features include:

- Custom countdown duration
- Focus sessions
- Background nature sounds
- Looping audio playback
- Productivity-oriented session tracking

Nature sounds such as rain and river ambience can be played during
focus sessions.

---

### 💧 Health & Activity Tracking

The application provides basic personal tracking features including:

- Water intake tracking
- Daily step tracking
- BMI calculation
- Basic health-oriented informational guidance

> **Note:** Health-related information provided by the application
> is intended for general informational purposes and is not medical
> advice.

---

### 📚 Personal Development Tools

Pusula also includes several personal development modules:

- 📖 Book tracking
- 📝 Daily journaling
- 🎯 Goal tracking
- 🏆 Achievement badges
- 📊 Daily progress
- 🔥 Streak tracking

---

### 🏆 Achievement System

Users can unlock badges by completing specific milestones.

Examples include:

- Completing daily goals
- Maintaining consistent progress
- Reaching Oasis milestones

The achievement system is designed to encourage long-term engagement.

---

### 🌍 Internationalization

Pusula supports dynamic language switching between:

- 🇹🇷 Turkish
- 🇬🇧 English

Users can change the application language directly from their profile.

---

## 🏗️ Technology Stack

### Mobile & Frontend

- **Flutter & Dart** — Cross-platform application development
- **Google Fonts (Nunito)** — Application typography and UI styling

### Artificial Intelligence & API

- **Groq API** — LLM inference infrastructure
- **Llama 3.3 70B** — AI model powering Rota
- **HTTP package** — REST API communication and JSON processing

### Local Data Management

- **Hive / Hive Flutter** — Local NoSQL data storage
- **SharedPreferences** — Lightweight persistent settings and date tracking

### Audio & Media

- **Audioplayers** — Background audio playback for focus sessions

---

## 🧠 Technical Highlights

### 🌙 Virtual Day & Reset Algorithm

Pusula implements a custom daily-cycle mechanism based on a
**03:00 virtual day reset**.

Instead of relying solely on the device's calendar date,
the application determines the active day according to the
defined 03:00 reset boundary.

This allows daily goals, water intake and activity progress
to remain consistent with the application's intended daily cycle.

---

### 🌱 Dynamic Gamification Logic

The Oasis system dynamically calculates visual progression based
on completed daily goals.

```text
Goal Completion
      ↓
Water Drop
      ↓
Oasis Progress
      ↓
Next Growth Stage
text'''

This creates a direct relationship between user activity and
visual progression.

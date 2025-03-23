# Wiki-Tok - AI-Enhanced Knowledge Sharing Platform

![Flutter](https://img.shields.io/badge/Flutter-Latest-02569B)
![Python](https://img.shields.io/badge/Python-Flask-000000)
![MongoDB](https://img.shields.io/badge/MongoDB-Latest-47A248)
![BERT](https://img.shields.io/badge/BERT-NLP-FF6F00)

**Wiki-Tok** is an innovative cross-platform mobile application that combines the power of Wikipedia's vast knowledge base with social media engagement features, creating an immersive and interactive knowledge-sharing experience enhanced by AI.

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Installation](#installation)
- [Project Structure](#project-structure)
- [Modules](#modules)
  - [1. User Interface](#1-user-interface)
  - [2. Backend Services](#2-backend-services)
  - [3. AI & NLP Integration](#3-ai--nlp-integration)
- [Contributing](#contributing)
- [License](#license)
- [Acknowledgments](#acknowledgments)

## Features

- ♾️ **Infinite Scroll** - Seamless browsing experience with continuous content loading
- 💬 **Interactive Comments** - Public comment system on all posts with user profile integration
- 🔍 **Wikipedia Integration** - Global search capability for accessing Wikipedia information
- 🔥 **Trending Posts** - Algorithm-based trending content featuring most liked, commented, and shared posts
- 🌓 **Customizable Themes** - Toggle between dark and light modes for personalized viewing experience
- 📜 **Auto-Scroll** - Customizable auto-scrolling feature with user-defined time intervals
- 🏆 **Gamification System** - Achievement badges for reading and sharing milestones displayed on user profiles
- 📰 **Article Reader** - Comprehensive article viewing with detailed content access
- 🔊 **Listening the Articles** - Audio playback of articles for accessibility and convenience
- 👆 **Fun-Facts** - Quick access to related fun facts with a simple double-tap gesture

## Tech Stack

- **Frontend**: Flutter (Cross-platform development)
- **Backend**: Python with Flask framework
- **Database**: MongoDB (NoSQL database)
- **NLP Engine**: BERT (Bidirectional Encoder Representations from Transformers)
- **API Integration**: RESTful API architecture
- **Authentication**: JWT (JSON Web Tokens)
- **Responsive Design**: Adaptive UI for mobile and tablet

## Installation

### Prerequisites

- Flutter SDK (Latest version)
- Python 3.8+
- MongoDB
- Firebase account (for storage)

### Steps to Set Up

#### 1. Clone the repository:

```bash
git clone https://github.com/ashirwad5555/wiki-tok.git
cd wiki-tok
```

#### 2. Set up backend:

```bash
cd Backend
pip install -r requirements.txt
python app.py
```

#### 3. Set up Flutter frontend:

```bash
# Return to root directory
cd ..
# Get Flutter dependencies
flutter pub get
```

#### 4. Run the Flutter app:

```bash
# Turn on the emulator or connect a physical device before running
flutter run
```

> **Note:** Ensure that you have turned on an Android/iOS emulator or connected a physical device via USB debugging before running the Flutter app.

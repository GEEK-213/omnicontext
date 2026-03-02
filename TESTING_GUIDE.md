# OmniContext Testing Guide

Welcome to the OmniContext QA and Testing Phase! This guide provides a comprehensive breakdown of what the application is, how its features connect, and how to test them end-to-end.

---

## 🚀 What is OmniContext?

**OmniContext** is a developer-centric, AI-native desktop dashboard that bridges your local Git repositories, your IDE (VS Code), and Large Language Models (LLMs) into a single unified interface. 

Instead of copying and pasting code snippets between your editor and ChatGPT, OmniContext lives natively on your machine to continuously "watch" your workspace. When you need help, it automatically gathers everything relevant—your Git diffs, recent terminal commands, and active files—to generate highly accurate, immediate AI context.

### The Big Picture Integration (The "App Flow")
The magic of OmniContext happens when its three main pillars connect:
1. **The Desktop App (Flutter):** The central hub providing the visual Dashboard, LLM querying (Gemini/Ollama), and Semantic Vector search.
2. **The VS Code Extension:** A lightweight tracker that runs inside your editor. It monitors your terminal commands and currently active tabs, then streams that data to the Desktop App via a secure local WebSocket (`ws://localhost:7171`).
3. **The Data Layer:** Uses Local `git` executables to track branch limits, and local `Drift` databases to store your terminal history.

---

## 🧪 Feature Breakdown & How to Test

### 1. The Global Summon Hotkey
**What it does:** OmniContext is meant to feel like a rapid spotlight search. You can summon it from anywhere.
**How to test:**
- While the app is running in the background (or minimized), press **`Alt + Space`** on your keyboard.
- **Expected Result:** The OmniContext window launches to the foreground and automatically selects the "Search codebase..." bar, ready for you to type a query.

### 2. Initial Setup & Onboarding
**What it does:** Secures the necessary environment configurations (like the OpenAI/Gemini API keys) before letting the user into the dashboard.
**How to test:**
- Ensure you have cleared the app's local storage (or run for the first time).
- Input a valid Gemini API Key and select a project folder.
- **Expected Result:** The app transitions to the Dashboard, the layout resizes to `1200x800`, and Onboarding does not reappear on subsequent launches.

### 3. Workspace Explorer & Git Drift
**What it does:** The leftmost "EXPLORER" panel visually represents the current project. It checks your local repository against your remote upstream to detect if you are ahead, behind, or diverged.
**How to test:**
- Look at the "BRANCHES" section. Ensure it correctly identifies your active branch with a blue dot.
- If you have unpushed commits, look for the "COMMITS AHEAD" banner.
- **Expected Result:** The app accurately reflects your local `git status`. (Note: The app enforces `runInShell: true` under the hood to ensure Windows compatibility).

### 4. Semantic Intelligence Console
**What it does:** The center column allows you to search your codebase by "meaning" rather than just text matching, utilizing Vector Embeddings.
**How to test:**
1. Click the small **`LOCAL`** button next to the "INTELLIGENCE UNIT" banner to index your current codebase.
2. Wait for the `Indexed X files` SnackBar notification to appear.
3. Type a conceptual query into the search bar (e.g., `where is the layout defined` or `auth logic`).
4. **Expected Result:** The UI returns relevant code snippets dynamically mapped from your project.

### 5. VS Code Synergy (Terminal History)
**What it does:** Directly integrates with your IDE to track failures and commands.
**How to test:**
1. Ensure the OmniContext VS Code Extension is running in your editor.
2. Execute a command in the VS Code terminal (e.g., `npm run build` or a failing command).
3. Switch back to the OmniContext Dashboard.
4. **Expected Result:** The command instantly appears in the "PROJECT HISTORY" section at the bottom center. **Bonus:** Try clicking the "Copy" icon next to a command to verify clipboard functionality.

### 6. AI Context Generation & Auto-Commits
**What it does:** Condenses your current workspace state down to an optimized prompt that can be pasted into ChatGPT or executed directly.
**How to test:**
- Click the **`GENERATE COMMIT MSG`** button in the bottom right corner (ensure you have staged files via Git first!).
- Alternatively, click the big **`GENERATE CONTEXT`** button to create a massive context block for debugging.
- **Expected Result:** The app analyzes your `git diff` and local history, generates a summary using the selected LLM (Gemini), and copies the packet to your clipboard.

---

## 🐛 Troubleshooting for Testers
- **"RenderFlex Overflow" issues:** If you find the UI stretching out of bounds or clipping, try resizing the window manually. The layouts use flexible containers (`Expanded` flex boxes) to adapt, but minimum widths are enforced.
- **"No Active Search Results":** This is not a bug. It simply means you haven't clicked the `LOCAL` or `GIT` indexing buttons yet on the current project. The app needs to embed the files first!
- **"WebSocket / Port in use":** If the VS Code extension fails to connect, ensure no background ghost instances of the OmniContext flutter app are secretly holding port `7171` hostage.

---
*Happy Testing!*

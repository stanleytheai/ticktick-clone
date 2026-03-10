# TickTick Clone — Feature Specification (1:1 Parity)

**Project:** TickTick Clone
**Status:** Planning
**Hosting:** Google Cloud Platform
**Date:** 2026-03-10

---

## Table of Contents

1. [Platforms & Clients](#1-platforms--clients)
2. [Task Management (Core)](#2-task-management-core)
3. [Lists & Organization](#3-lists--organization)
4. [Views](#4-views)
5. [Calendar](#5-calendar)
6. [Reminders & Notifications](#6-reminders--notifications)
7. [Pomodoro Timer (Focus)](#7-pomodoro-timer-focus)
8. [Habit Tracker](#8-habit-tracker)
9. [Eisenhower Matrix](#9-eisenhower-matrix)
10. [Collaboration & Sharing](#10-collaboration--sharing)
11. [Notes & Content](#11-notes--content)
12. [Tags & Filters](#12-tags--filters)
13. [Smart Lists](#13-smart-lists)
14. [Quick Capture & Input](#14-quick-capture--input)
15. [Integrations](#15-integrations)
16. [Widgets & Native Features](#16-widgets--native-features)
17. [Statistics & Analytics](#17-statistics--analytics)
18. [Account & Settings](#18-account--settings)
19. [Premium vs Free Tiers](#19-premium-vs-free-tiers)
20. [GCP Architecture](#20-gcp-architecture)

---

## 1. Platforms & Clients

| Platform | Details |
|----------|---------|
| Web App | Responsive SPA (primary client) |
| iOS | Native app (Swift/SwiftUI) |
| Android | Native app (Kotlin) |
| macOS | Native desktop app |
| Windows | Native desktop app |
| Browser Extensions | Chrome, Firefox, Edge — quick-add from any page |
| Apple Watch | Companion app |
| Wear OS | Companion app |

---

## 2. Task Management (Core)

### 2.1 Task Properties
- **Title** — text with NLP date parsing ("tomorrow at 3pm")
- **Description** — rich text / markdown support
- **Due date** — date and optional time
- **Start date** — optional
- **Duration** — estimated time for task
- **Priority** — None, Low, Medium, High (4 levels, color-coded)
- **Tags** — multiple per task
- **List assignment** — belongs to one list
- **Subtasks / Checklist items** — nested items with completion tracking
- **Attachments** — images, files (limit varies by tier)
- **Recurring / Repeat** — daily, weekly, monthly, yearly, custom (e.g., "every 3 days", "every Mon/Wed/Fri", "after completion")
- **Completion status** — incomplete / complete
- **Sort order** — manual drag, by date, by priority, by title, by tag
- **Task comments** — text comments on tasks (collaboration)
- **Assignee** — assign to collaborator (premium)
- **Created date / Modified date** — auto-tracked

### 2.2 Task Actions
- Create, edit, delete
- Complete / uncomplete
- Move between lists
- Duplicate
- Batch operations (multi-select, bulk edit, bulk delete, bulk move)
- Undo/redo
- Drag and drop reordering
- Task activity log / history

---

## 3. Lists & Organization

### 3.1 Lists
- Create, rename, delete lists
- List color / icon customization
- List sort order (manual, alphabetical)
- List-level default settings (e.g., default sort)
- Archive lists

### 3.2 Folders (List Groups)
- Group lists into folders
- Collapse/expand folders
- Folder color/icon

### 3.3 Special Lists
- **Inbox** — default capture location for unsorted tasks
- **Today** — tasks due today
- **Tomorrow** — tasks due tomorrow
- **Next 7 Days** — upcoming week view
- **All** — every task across all lists
- **Completed** — completed task archive
- **Trash** — recently deleted (recoverable)
- **Assigned to Me** — tasks assigned by collaborators (premium)

---

## 4. Views

### 4.1 List View
- Traditional vertical task list
- Grouping options (by date, priority, tag, list, assignee)
- Collapsible groups
- Task detail panel (side panel or modal)

### 4.2 Kanban Board View
- Columns based on grouping (status, priority, custom sections)
- Drag and drop between columns
- Card preview with key info (due date, priority, assignee)
- Column WIP limits (optional)

### 4.3 Timeline View
- Gantt-chart-like horizontal timeline
- Task bars showing start/end dates and duration
- Drag to adjust dates
- Dependency visualization (lightweight)

### 4.4 Calendar View (see Section 5)

---

## 5. Calendar

### 5.1 Calendar Layouts
- **Day view** — hourly breakdown
- **Week view** — 7-day grid
- **Month view** — monthly overview
- **Multi-day view** — customizable (3-day, 5-day, etc.)
- **Multi-week view** — 2-week or custom

### 5.2 Calendar Features
- Tasks displayed on calendar by due date/time
- Drag and drop tasks to reschedule
- Drag to adjust duration
- Create tasks directly on calendar
- Unscheduled task panel — drag onto calendar
- Color coding by list/priority
- Mini calendar for navigation

### 5.3 Calendar Sync
- **Google Calendar** — two-way sync
- **Outlook Calendar** — two-way sync
- **Apple Calendar (CalDAV)** — sync support
- Subscribe via iCal URL
- Multiple calendar display (tasks + external events)

---

## 6. Reminders & Notifications

### 6.1 Task Reminders
- Multiple reminders per task (up to 5)
- Reminder timing: at due time, X minutes/hours/days before
- **Constant Reminder** — repeated notifications until handled
- Pin to lock screen (mobile)
- Snooze options

### 6.2 Notification Channels
- Push notifications (mobile)
- Desktop notifications
- Email reminders
- In-app notification center

### 6.3 Reminder Settings
- Default reminder preferences
- Quiet hours / Do Not Disturb schedule
- Per-list reminder defaults

---

## 7. Pomodoro Timer (Focus)

### 7.1 Timer
- Configurable work duration (default 25 min)
- Configurable short break (default 5 min)
- Configurable long break (default 15 min, after N sessions)
- Auto-start next session option
- Timer linked to specific task
- Estimated pomodoros per task

### 7.2 White Noise / Ambient Sounds
- Multiple sound options (rain, forest, cafe, ocean, fireplace, etc.)
- Mix multiple sounds
- Volume control per sound
- Play during focus sessions

### 7.3 Focus Statistics
- Daily/weekly/monthly focus time
- Focus time per task / per list
- Streak tracking
- Focus history log

### 7.4 Sticky Notes
- Quick floating note
- "Start Focus" from sticky note
- Desktop widget-style note

---

## 8. Habit Tracker

### 8.1 Habit Properties
- Habit name and icon
- Frequency: daily, specific days of week, X times per week/month
- Goal: count-based (e.g., "drink 8 glasses of water") or yes/no
- Reminder time
- Section grouping (morning, afternoon, evening)

### 8.2 Habit Tracking
- One-tap check-in
- Partial completion (for count-based)
- Streak tracking (current + longest)
- Calendar heat map view
- Skip vs miss distinction

### 8.3 Habit Statistics
- Completion rate (daily/weekly/monthly)
- Streak history
- Trend charts
- Habit score

---

## 9. Eisenhower Matrix

- Four quadrants: Urgent+Important, Not Urgent+Important, Urgent+Not Important, Not Urgent+Not Important
- Tasks auto-plotted based on priority + due date
- Drag between quadrants to re-prioritize
- Filter by list, tag, date range
- Visual color coding

---

## 10. Collaboration & Sharing

### 10.1 Shared Lists (Premium)
- Share list with other users (by email/username)
- Permission levels: view-only, edit, admin
- Real-time sync across collaborators

### 10.2 Task Collaboration
- Assign tasks to list members
- @mention in task comments
- Activity feed per shared list
- Notification on assignment/comment

### 10.3 Sharing
- Share task/list via link
- Export list to text/CSV

---

## 11. Notes & Content

### 11.1 Task Description
- Markdown support (bold, italic, lists, headers, code blocks)
- Image embedding
- File attachments
- Checklists within description

### 11.2 Standalone Notes (Notepad)
- Quick notes separate from tasks
- Markdown formatting
- Folder organization for notes

---

## 12. Tags & Filters

### 12.1 Tags
- Create custom tags
- Multiple tags per task
- Tag-based task grouping
- Tag management (rename, delete, merge)
- Nested/hierarchical tags

### 12.2 Smart Filters
- Create custom filter views
- Filter criteria: due date, priority, tag, list, assignee, completion status, keyword, created date
- Combine multiple criteria (AND/OR logic)
- Save as custom smart list
- Pin to sidebar

---

## 13. Smart Lists

- **Built-in:** Today, Tomorrow, Next 7 Days, Inbox, All, Assigned to Me
- **Custom smart lists** — user-defined filters saved as lists
- Auto-updating based on criteria
- Sidebar pinning and ordering

---

## 14. Quick Capture & Input

### 14.1 Quick Add
- Global keyboard shortcut (desktop)
- Quick add widget (mobile home screen)
- Lock screen quick add (mobile)
- Floating action button (mobile)
- Browser extension quick add (right-click context menu)

### 14.2 Natural Language Processing
- Parse dates/times from task title ("meeting tomorrow at 2pm")
- Parse priority ("!!" = high)
- Parse tags ("#work")
- Parse list assignment ("/projectname")
- Parse recurrence ("every Monday")

### 14.3 Voice Input
- Speech-to-text task creation
- Voice command support (Siri, Google Assistant, Alexa)

### 14.4 Email to Task
- Dedicated email address for task creation
- Forward emails to create tasks
- Email plugin (Gmail, Outlook) for quick add

---

## 15. Integrations

### 15.1 Calendar
- Google Calendar (two-way sync)
- Outlook Calendar
- Apple Calendar

### 15.2 Import/Export
- Import from: Todoist, Microsoft To Do, Apple Reminders, Notion, Wunderlist, Any.do
- Export to CSV / text / backup file

### 15.3 Third-Party
- Zapier
- IFTTT
- Siri Shortcuts (iOS)
- Amazon Alexa
- Google Assistant
- Spark (email client)
- Apple Health (data integration)
- Notion (integration)
- Slack (optional)

### 15.4 API
- REST API for third-party integrations
- OAuth 2.0 authentication
- Webhook support

---

## 16. Widgets & Native Features

### 16.1 Mobile Widgets
- Task list widget (home screen)
- Quick add widget
- Calendar widget
- Habit tracker widget
- Pomodoro widget

### 16.2 Desktop
- Menu bar app (macOS)
- System tray (Windows)
- Global keyboard shortcuts
- Sticky notes (desktop overlay)

### 16.3 Platform-Specific
- iOS: Siri, Shortcuts, Apple Watch, Lock Screen widgets, Live Activities
- Android: Wear OS, Google Assistant, home screen widgets
- macOS/Windows: native notifications, keyboard shortcuts

---

## 17. Statistics & Analytics

### 17.1 Task Statistics
- Tasks completed (daily/weekly/monthly/all-time)
- Completion trends over time
- Tasks by list / tag / priority breakdown
- Overdue task tracking

### 17.2 Focus Statistics
- Pomodoro sessions completed
- Total focus time
- Focus time by task/list
- Daily/weekly/monthly trends

### 17.3 Habit Statistics
- Completion rates
- Streaks (current + best)
- Historical calendar view

### 17.4 Achievement System
- Milestones (tasks completed, streaks, etc.)
- Badges / rewards

---

## 18. Account & Settings

### 18.1 Account
- Email + password registration
- Social login (Google, Apple, Facebook)
- Two-factor authentication (2FA / TOTP)
- Profile (name, avatar)
- Account deletion
- Data export (full backup)

### 18.2 App Settings
- Theme: light, dark, auto, custom themes (premium)
- Font size options
- Default list for new tasks
- Default reminder settings
- Week start day (Sunday/Monday)
- Date format / time format (12h/24h)
- Language / localization (multiple languages)
- Sidebar customization (show/hide sections, reorder)
- Tab bar customization (mobile)
- Sound settings
- Keyboard shortcut customization

### 18.3 Data & Privacy
- End-to-end sync across devices
- Offline mode with sync on reconnect
- Data encryption at rest and in transit
- GDPR compliance
- Data retention policies

---

## 19. Premium vs Free Tiers

### 19.1 Free Tier
- Unlimited tasks and lists (within limits)
- Up to 9 lists
- Up to 19 tasks per list
- 1 calendar subscription
- 1 member per shared list
- Basic themes
- Multiple reminders (up to 2)
- Pomodoro timer
- Habit tracker (up to 5 habits)
- Tags and basic filters
- Basic statistics

### 19.2 Premium Tier (~$35.99/year equivalent)
- Unlimited lists
- Unlimited tasks per list
- Up to 5 reminders per task
- Calendar view (all layouts)
- Google Calendar two-way sync
- Collaboration (up to 29 members per list)
- Task assignment
- Task comments & @mentions
- Timeline view
- More filter criteria
- Custom smart lists
- Higher attachment limits (per task + total storage)
- More themes & customization
- Advanced statistics
- Priority support
- Multiple calendar subscriptions

---

## 20. GCP Architecture (Proposed)

### 20.1 Infrastructure

| Component | GCP Service | Purpose |
|-----------|-------------|---------|
| **Web Frontend** | Cloud Run / Firebase Hosting | Serve SPA (React/Next.js) |
| **API Backend** | Cloud Run | REST API (Node.js/Go/Python) |
| **Database** | Cloud SQL (PostgreSQL) | Primary data store |
| **Real-time Sync** | Firestore or Cloud Pub/Sub | Live collaboration & cross-device sync |
| **File Storage** | Cloud Storage | Attachments, images, backups |
| **Authentication** | Firebase Auth | User auth, OAuth, 2FA |
| **Push Notifications** | Firebase Cloud Messaging (FCM) | Mobile & web push |
| **Email** | SendGrid / Cloud Tasks | Email reminders & notifications |
| **Search** | Cloud SQL full-text / Elasticsearch on GKE | Task search, NLP parsing |
| **Cron / Scheduling** | Cloud Scheduler + Cloud Tasks | Recurring tasks, reminders |
| **CDN** | Cloud CDN | Static asset delivery |
| **Monitoring** | Cloud Monitoring + Logging | Ops, alerting, SLAs |
| **CI/CD** | Cloud Build | Automated deployments |

### 20.2 Data Model (High-Level)

- **Users** — account, profile, settings, subscription
- **Lists** — name, color, icon, folder, owner, shared members
- **Tasks** — all properties from Section 2, belongs to list
- **Subtasks** — child of task, title, completion
- **Tags** — name, color, user-scoped
- **Habits** — name, frequency, goal, streak data
- **Habit Logs** — date, completion value
- **Pomodoro Sessions** — start, end, task link, duration
- **Comments** — task link, author, text, timestamp
- **Attachments** — task link, file URL, type, size
- **Filters** — user-scoped saved filter criteria
- **Notifications** — type, target, read status
- **Calendar Events** — synced external events

### 20.3 Key Technical Requirements

- **Offline-first** — local storage with conflict resolution sync
- **Real-time collaboration** — WebSocket or Firestore listeners
- **NLP engine** — date/time parsing from natural language input
- **Sub-second API responses** — for core CRUD operations
- **Multi-platform sync** — eventual consistency < 3 seconds
- **99.9% uptime SLA**
- **GDPR compliant** — data export, deletion, consent management
- **Rate limiting & abuse protection**
- **API versioning** (v1, v2, etc.)

---

## Next Steps

1. [ ] Confirm project name and branding
2. [ ] Set up GCP project and initial infrastructure
3. [ ] Define tech stack for each client (web, iOS, Android, desktop)
4. [ ] Create data model / ERD
5. [ ] Build API specification (OpenAPI)
6. [ ] Prioritize MVP features (Phase 1 vs Phase 2)
7. [ ] Set up CI/CD pipeline
8. [ ] Begin development

---

*This document is the source of truth for feature parity with TickTick. Update as features are refined or new ones discovered.*

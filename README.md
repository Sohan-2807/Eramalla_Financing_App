# 🏦 Erramala Finance

> A production-ready, offline-first mobile application built for micro-lenders and collection agents to digitize daily operations, manage loans, and eliminate paper ledgers.

---

## 📌 Overview

**Erramala Finance** addresses the operational challenges faced by small financial businesses, independent lenders, and field collection agents. Managing daily and weekly collection schedules, calculating overdue interest, and migrating legacy paper records often lead to manual accounting errors. 

This app provides a complete digital ledger system that runs **100% offline**, ensuring high performance, zero server dependency, and strict data privacy.

---

## ✨ Key Features

### 📊 Dashboard & Financial Analytics
* **Real-Time KPIs:** Monitor total disbursed capital, outstanding balances, expected daily targets, and overall recovery rates at a glance.
* **Monthly Disbursement Trends:** Interactive visual bar charts tracking monthly capital deployment.

### 📅 Smart Collection Calendar
* **Unpaid-Only Calendar Indicators:** Dynamic visual markers highlight dates with active dues. Indicators automatically clear as collections are finalized.
* **Daily & Weekly Schedules:** Full support for flexible collection frequencies tailored to individual borrower agreements.

### 💬 1-Click Consolidated WhatsApp Reminders
* **Multi-Installment Summaries:** Automatically aggregates all pending and overdue installments for a specific borrower into a single, itemized WhatsApp message.
* **OS-Level Compatibility:** Built-in direct intent routing to bypass Android 11+ package visibility restrictions (`canLaunchUrl` blocks).

### 📄 Automated PDF Generation & Printing
* **A4 Loan Summaries:** Comprehensive statement breakdowns including repayment progress bars, customer profiles, and complete payment histories.
* **A5 Payment Receipts:** On-the-spot printable digital receipts generated immediately upon collection confirmation.

### 🔄 Legacy Paper Migration & Loan Overrides
* **Paper-to-Digital Migration:** Features a "Cleared Upto Date" calculator that automatically computes completed historical cycles without manual counting.
* **Loan Refinancing & Overrides:** Seamlessly close existing loans and transfer remaining balances into new agreements while auto-calculating net cash differences.

---

## 🛠️ Architecture & Tech Stack

* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **Architecture Pattern:** Provider State Management (Reactive UI pipeline)
* **Local Database:** `sqflite` (SQLite) with custom relational schemas, transactional integrity, foreign keys, indexes, and cascade deletion.
* **PDF & Printing:** `pdf` & `printing` packages for dynamic layout rendering and thermal printing integration.
* **Native Interoperability:** `url_launcher` utilizing direct intent modes (`LaunchMode.externalApplication`) for external phone, SMS, and WhatsApp dispatch.

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>=3.0.0`)
* [Android Studio](https://developer.android.com/studio) or VS Code with Flutter extensions installed.
* Java Development Kit (JDK 17 recommended).

### Installation

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/YourUsername/erramala-finance.git](https://github.com/YourUsername/erramala-finance.git)
   cd erramala-finance

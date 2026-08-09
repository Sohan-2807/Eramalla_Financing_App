# Erramala Finance 📱💼

Erramala Finance is a production-ready, offline-first mobile application built with Flutter. It is designed specifically for small-scale lenders and collection agents to digitize their operations, transition away from paper ledgers, and streamline daily loan collections.

## ✨ Key Features
* **100% Offline Architecture:** Powered by `sqflite` with custom transactional integrity and cascade deletions, ensuring your data is safe, fast, and accessible without an internet connection.
* **Smart Dashboard & Analytics:** Real-time tracking of today's collection targets, total outstanding balances, and monthly disbursement trends via interactive UI components.
* **Consolidated WhatsApp Reminders:** A custom 1-click intent system that gathers all pending and overdue installments for a customer and formats them into a single, itemized WhatsApp message (bypassing Android 11+ package visibility restrictions).
* **Automated PDF Generation:** Instantly generate, preview, and share highly detailed A4 Loan Summaries and A5 Payment Receipts directly from the app.
* **Legacy Paper Migration:** Features a smart "Cleared Upto Date" calculator that seamlessly transitions old paper loans into the digital system without manual counting.
* **Loan Overriding:** Built-in logic to close active loans and roll outstanding balances into new loan agreements automatically.

## 🛠️ Tech Stack
* **Framework:** Flutter / Dart
* **State Management:** Provider
* **Local Database:** sqflite & path_provider
* **Document Generation:** pdf & printing
* **Native Interop:** url_launcher (Direct intent execution for WhatsApp, SMS, and Calls)
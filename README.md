# Finance Tracking Application

A comprehensive Flutter-based personal finance management application designed to help users track money given to and received from others. This application provides a complete solution for managing personal loans, debts, and financial transactions with an intuitive user interface and modern design patterns.

## Overview

Finance Tracking is a mobile application that allows users to:
- Track transactions between themselves and other individuals
- Categorize transactions as money given or money taken
- Maintain settlement status for each transaction
- Generate detailed financial reports in Excel format
- Access transaction history with comprehensive filtering options
- Monitor net balance and financial summaries
- Switch between light and dark themes

The application is built using Flutter, providing seamless experience across Android and iOS platforms with consistent functionality and performance.

## Features

### Core Functionality

**User Authentication**
- User signup and session management
- Persistent user sessions using SharedPreferences
- Secure storage of user credentials with password hashing using crypto package

**Transaction Management**
- Add new transactions with date, amount, person name, contact, reason, and transaction type
- Edit existing transactions with full update capability
- Delete transactions with confirmation dialog
- Mark transactions as settled or unsettled
- Transaction categorization as given or taken

**Dashboard**
- Real-time summary of total money given and total money taken
- Net balance calculation and display
- Recent transactions list showing the 10 most recent transactions
- Instant updates when transactions are added, modified, or deleted
- Visual indicators for transaction types with color coding

**Transaction Management Screens**
- All Transactions view with comprehensive listing
- Filter transactions by type: All, Given, Taken, or Unsettled
- View transactions organized by person
- Detailed transaction information display
- Quick access to transaction details

**Person-based Views**
- View all transactions with a specific person
- Person-specific balance calculation
- Summary of given and taken amounts per person
- Track who owes you money and who you owe money to

**Report Generation**
- Generate Excel reports for date ranges
- Excel reports include detailed transaction data with headers
- Automatic summary calculations: Total Given, Total Taken, Net Balance
- Report file naming based on selected date range
- Reports saved to device storage for easy access
- Open generated Excel files directly from the application
- Reports history feature with quick access to previously generated reports
- Click on any report in history to open the Excel sheet

**Theme Support**
- Light theme with clean, professional design
- Dark theme with modern futuristic aesthetic featuring neon colors
- Real-time theme switching
- Theme preference persistence across sessions
- Improved readability in both themes with appropriate color contrast

### Real-time Updates

The application implements comprehensive real-time synchronization using the Provider pattern:
- Dashboard automatically refreshes when transactions are added
- Instant updates when transaction status changes
- Real-time deletion reflection on dashboard
- No manual refresh required for data consistency
- Seamless state management across multiple screens

## Project Structure

The project follows a clean architecture pattern with clear separation of concerns:

```
lib/
├── main.dart                    # Application entry point with Provider setup
├── screens/                     # UI screens
│   ├── signup_screen.dart      # User authentication screen
│   ├── dashboard_screen.dart   # Main dashboard with summary and recent transactions
│   ├── add_transaction_screen.dart     # Add/Edit transaction form
│   ├── transaction_list_screen.dart    # List all transactions with filters
│   ├── transaction_detail_screen.dart  # Individual transaction details
│   ├── person_detail_screen.dart       # Person-specific transaction view
│   └── report_generation_screen.dart   # Report generation with history
├── database/                    # Database layer
│   └── database_helper.dart    # SQLite database operations
├── models/                      # Data models
│   ├── transaction_model.dart  # Transaction data class
│   └── user_model.dart         # User data class
├── utils/                       # Utility functions and constants
│   ├── constants.dart          # Application constants
│   ├── helpers.dart            # Helper functions
│   ├── app_theme.dart          # Theme definitions
│   ├── theme_provider.dart     # Theme state management
│   └── transaction_change_notifier.dart  # Real-time update notifier
└── widgets/                     # Reusable widgets
    ├── transaction_card.dart   # Transaction list item widget
    └── theme_toggle.dart       # Theme switching widget
```

## Technical Architecture

### Database Layer
- SQLite database for local data persistence
- Database helper using sqflite package
- Tables for users and transactions
- Efficient queries for filtered data retrieval

### State Management
- Provider package for dependency injection and state management
- TransactionChangeNotifier for real-time transaction updates
- ThemeProvider for theme state management
- MultiProvider setup in main.dart for multiple providers

### UI/UX
- Flutter ScreenUtil for responsive design across different screen sizes
- Material Design 3 with custom theming
- Consistent spacing and typography
- Theme-aware color schemes for accessibility

### File Operations
- Open file package for accessing generated reports
- Path provider for storage directory access
- Excel package for structured report generation

## Dependencies

**Core Framework**
- flutter: Flutter SDK
- flutter_screenutil: Responsive screen adaptation

**State Management**
- provider: Service locator and state management

**Data Persistence**
- sqflite: SQLite database
- shared_preferences: Lightweight data storage
- path: Path utilities
- path_provider: Storage directory access

**Date and Time**
- intl: Internationalization and date formatting

**Data Processing**
- excel: Excel file generation and manipulation
- crypto: Password hashing and cryptographic operations

**File Handling**
- android_intent_plus: Android intent handling
- open_file: Open files with default applications

**UI/UX**
- cupertino_icons: iOS style icons

## Installation and Setup

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio or Xcode for development
- Android device or emulator / iOS simulator

### Installation Steps

1. Clone the repository
```bash
git clone <repository-url>
cd finance_tracking
```

2. Install dependencies
```bash
flutter pub get
```

3. Generate code if needed
```bash
flutter pub run build_runner build
```

4. Run the application
```bash
flutter run
```

### Building for Release

**Android Release Build**
```bash
flutter build apk --release
```

**iOS Release Build**
```bash
flutter build ios --release
```

## Usage Guide

### Getting Started

1. Launch the application
2. Create a new account on the signup screen
3. Enter your username and password
4. Your session will be saved for future launches

### Adding Transactions

1. Navigate to the dashboard
2. Tap the floating action button to add a new transaction
3. Select transaction type: Money Given or Money Taken
4. Fill in person name, contact, amount, and reason
5. Select the transaction date
6. Tap Save to add the transaction

### Managing Transactions

**View Transaction Details**
- Tap any transaction card to view full details
- Edit or delete transactions from the detail screen
- Change transaction settlement status

**Filter Transactions**
- Open All Transactions screen
- Use filter options to view by type or settlement status
- View transactions organized by person

**Update Settlement Status**
- Open transaction details
- Tap Mark as Settled or Mark as Unsettled button
- Dashboard updates in real-time

### Generating Reports

1. Navigate to Generate Report screen from dashboard
2. Select start date and end date
3. Tap Generate Excel Report
4. Review generated report details
5. Access previously generated reports from history
6. Click any report to open the Excel file

### Theme Management

- Use the theme toggle button in the dashboard
- Light theme for daytime use
- Dark theme for comfortable viewing in low light
- Theme preference is saved automatically

## Application Flow

### Authentication Flow
User launches app -> SharedPreferences check -> Existing user goes to Dashboard -> New user goes to Signup -> Account created -> Dashboard

### Transaction Lifecycle
Add Transaction -> Database stores data -> Dashboard notified via Provider -> Real-time update on dashboard -> User can edit or delete -> Changes instantly reflected

### Report Generation
Select dates -> Fetch transactions for range -> Create Excel spreadsheet -> Calculate summaries -> Save to storage -> Add to history -> User can access immediately or from history

## Database Schema

### Users Table
- id: PRIMARY KEY
- username: UNIQUE TEXT
- password: TEXT (hashed)
- created_at: TEXT

### Transactions Table
- id: PRIMARY KEY
- user_id: FOREIGN KEY
- transaction_type: TEXT (GIVEN/TAKEN)
- person_name: TEXT
- person_contact: TEXT
- amount: REAL
- reason: TEXT
- transaction_date: TEXT
- is_settled: BOOLEAN
- created_at: TEXT

## Design Patterns

### MVC Architecture
- Models define data structure
- Views render UI
- Controllers manage logic

### Provider Pattern
- Centralized state management
- Real-time data synchronization
- Dependency injection

### Repository Pattern
- DatabaseHelper acts as data layer
- Abstraction between UI and database

### Notifier Pattern
- TransactionChangeNotifier broadcasts changes
- Listeners update automatically
- Decoupled event handling

## Theme System

### Light Theme
- Clean, professional design
- High contrast text for readability
- Soft colors for comfortable viewing
- Primary color: Indigo
- Secondary color: Purple

### Dark Theme
- Modern futuristic aesthetic
- Neon accent colors
- Optimized for low-light environments
- Primary color: Neon Blue
- Secondary color: Neon Purple
- Accent colors: Neon Green, Neon Pink, Neon Yellow

## Performance Considerations

- Lazy loading of transaction lists
- Efficient database queries with filtering
- Responsive UI updates using Provider
- Memory management with proper disposal
- Optimized Excel report generation

## Security

- Passwords stored with crypto hashing
- User sessions managed via SharedPreferences
- Local database storage for user data
- No external API calls for sensitive data

## Troubleshooting

### Application won't start
- Clear app data: `flutter clean`
- Rebuild: `flutter run`

### Transactions not updating on dashboard
- Check if you have latest build
- Verify Provider is properly configured
- Restart the application

### Report generation fails
- Ensure storage permissions are granted
- Check available storage space
- Verify Excel package is correctly imported

### Theme not persisting
- Check SharedPreferences storage
- Clear app cache and rebuild

## Future Enhancements

- Multi-currency support
- Cloud synchronization across devices
- Transaction categories and tagging
- Recurring transaction support
- Budget planning and alerts
- Data export to other formats
- Transaction reminders
- Statistical analysis and charts

## Testing

The application has been tested for:
- Core transaction operations
- Real-time update synchronization
- Theme switching functionality
- Report generation and access
- Database persistence
- User session management

## Support and Contribution

For issues, feature requests, or contributions, please follow the standard procedures for your version control system. Ensure all changes maintain code quality and follow the established architecture patterns.

## License

This application is provided as-is for personal finance tracking purposes. Modify and distribute according to your needs while maintaining acknowledgment of original work.

## Version History

Version 1.0.0 (Initial Release)
- Core transaction management
- Dashboard with real-time updates
- Excel report generation with history
- Light and dark theme support
- Person-based transaction views
- Transaction filtering and organization

## Acknowledgments

Built with Flutter and leveraging community packages for enhanced functionality. Special thanks to the Flutter community for excellent documentation and resources.

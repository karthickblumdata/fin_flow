# Flutter Backend Integration Guide

This document explains how the Flutter app (`flutter_project_1`) is connected to the Express.js backend API.

## 📁 Project Structure

```
flutter_project_1/
├── lib/
│   ├── services/
│   │   ├── api_service.dart          # Base HTTP client with auth
│   │   ├── auth_service.dart         # Authentication APIs
│   │   ├── wallet_service.dart       # Wallet operations
│   │   └── collection_service.dart   # Collection operations
│   ├── utils/
│   │   └── api_constants.dart        # API endpoints configuration
│   └── screens/                      # UI screens
└── pubspec.yaml
```

## 🔧 Setup

### 1. Update API Base URL

Edit `lib/utils/api_constants.dart` and update the `baseUrl` based on your setup:

```dart
// For Android Emulator
static const String baseUrl = 'http://10.0.2.2:4455/api';

// For iOS Simulator
static const String baseUrl = 'http://localhost:4455/api';

// For Physical Device (use your computer's IP address)
static const String baseUrl = 'http://192.168.1.100:4455/api';
```

**To find your computer's IP address:**
- Windows: Run `ipconfig` in command prompt
- Mac/Linux: Run `ifconfig` in terminal

### 2. Ensure Dependencies are Installed

Make sure `pubspec.yaml` includes:

```yaml
dependencies:
  http: ^1.2.0
  shared_preferences: ^2.2.2
```

Run:
```bash
flutter pub get
```

### 3. Start Backend Server

Make sure the backend server is running:

```bash
cd backend
npm run dev
```

The server should be running on `http://localhost:4455`

## 🔐 Authentication Flow

### Login

```dart
import 'package:flutter_project_1/services/auth_service.dart';

final result = await AuthService.login(email, password);
if (result['success']) {
  // User logged in successfully
  final user = result['user'];
  final token = result['token'];
  // Navigate to dashboard
} else {
  // Show error: result['message']
}
```

The token is automatically stored in SharedPreferences and included in all subsequent API requests.

### Check Authentication Status

```dart
final isAuthenticated = await AuthService.isAuthenticated();
if (isAuthenticated) {
  // User is logged in
}
```

### Logout

```dart
await AuthService.logout();
// Navigate to login screen
```

## 📡 API Services

### Wallet Service

```dart
import 'package:flutter_project_1/services/wallet_service.dart';

// Get wallet balance
final result = await WalletService.getWallet();
if (result['success']) {
  final wallet = result['wallet'];
  final cashBalance = wallet['cashBalance'];
  final upiBalance = wallet['upiBalance'];
  final bankBalance = wallet['bankBalance'];
}

// Add amount (SuperAdmin only)
await WalletService.addAmount('Cash', 1000.0, 'Initial deposit');

// Withdraw amount (SuperAdmin only)
await WalletService.withdrawAmount('Cash', 500.0, 'Withdrawal');
```

### Collection Service

```dart
import 'package:flutter_project_1/services/collection_service.dart';

// Get all collections
final result = await CollectionService.getCollections(
  status: 'Pending',
  mode: 'Cash',
);

// Create collection (Staff only)
await CollectionService.createCollection(
  customerName: 'John Doe',
  amount: 5000.0,
  mode: 'UPI',
  notes: 'Payment received',
);

// Approve collection
await CollectionService.approveCollection(collectionId);

// Reject collection
await CollectionService.rejectCollection(collectionId, 'Invalid proof');
```

## 🔄 How It Works

1. **ApiService**: Base HTTP client that handles:
   - Adding Authorization header with JWT token
   - Making GET, POST, PUT, DELETE, PATCH requests
   - Error handling and response parsing

2. **Token Storage**: JWT tokens are stored in SharedPreferences and automatically included in API requests.

3. **Service Classes**: Each service (AuthService, WalletService, etc.) uses ApiService to make API calls to specific endpoints.

4. **Error Handling**: All service methods return a Map with `success` and `message` fields for consistent error handling.

## 📝 Example: Using in a Screen

```dart
import 'package:flutter/material.dart';
import '../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? wallet;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => isLoading = true);
    final result = await WalletService.getWallet();
    
    if (result['success']) {
      setState(() {
        wallet = result['wallet'];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Text('Cash: ₹${wallet?['cashBalance'] ?? 0}'),
        Text('UPI: ₹${wallet?['upiBalance'] ?? 0}'),
        Text('Bank: ₹${wallet?['bankBalance'] ?? 0}'),
      ],
    );
  }
}
```

## 🐛 Troubleshooting

### Connection Refused

**Error**: `Network error: Connection refused`

**Solution**:
- Ensure backend server is running on port 4455
- Check if the baseUrl in `api_constants.dart` is correct
- For physical devices, ensure your computer and phone are on the same network

### Unauthorized (401)

**Error**: `Invalid token` or `Access denied`

**Solution**:
- Token might be expired (tokens expire after 24 hours)
- User needs to login again
- Clear app data and login again

### CORS Error (Web Only)

**Error**: CORS policy blocked

**Solution**:
- Backend CORS is already configured to allow all origins
- If issues persist, check backend `server.js` CORS settings

## 📚 Next Steps

1. **Create More Services**: Add service files for Transactions, Expenses, Reports, etc.
2. **Error Handling**: Implement global error handling using a state management solution
3. **Token Refresh**: Implement automatic token refresh before expiry
4. **Offline Support**: Add local caching for offline functionality

## 🔗 Related Files

- `backend/server.js` - Backend server configuration
- `backend/routes/*` - API route definitions
- `backend/controllers/*` - API business logic

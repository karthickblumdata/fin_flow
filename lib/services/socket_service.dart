import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_constants.dart';
import 'api_service.dart';

class SocketService {
  static IO.Socket? _socket;
  static bool _isConnected = false;

  /// Initialize Socket.IO connection
  static Future<void> initialize() async {
    if (_socket != null && _isConnected) {
      return; // Already connected
    }

    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        // Silently return - this is expected when user is not logged in
        return;
      }

      // Extract base URL from ApiConstants
      final baseUrl = ApiConstants.baseUrl.replaceAll('/api', '');
      final socketUrl = baseUrl.startsWith('http://') || baseUrl.startsWith('https://')
          ? baseUrl
          : 'http://$baseUrl';

      print('🔌 Connecting to Socket.IO: $socketUrl');

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .enableReconnection()
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setReconnectionAttempts(5)
            .disableAutoConnect()
            .build(),
      );

      _setupListeners();
      _socket!.connect();
    } catch (e) {
      print('❌ Socket initialization error: $e');
    }
  }

  /// Setup socket event listeners
  static void _setupListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      _isConnected = true;
      print('✅ Socket connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('⚠️ Socket disconnected');
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      print('❌ Socket connection error: $error');
    });

    _socket!.onError((error) {
      print('❌ Socket error: $error');
    });
  }

  /// Listen to amount updates (for Super Admin)
  static void onAmountUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Silently try to initialize - this is expected behavior
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('amountUpdate', (data) {
            print('📊 Amount update received: $data');
            callback(data);
          });
        }
      });
      return;
    }

    _socket!.on('amountUpdate', (data) {
      print('📊 Amount update received: $data');
      callback(data);
    });
  }

  /// Listen to dashboard updates (for Super Admin)
  static void onDashboardUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Silently try to initialize - this is expected behavior
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('dashboardUpdate', (data) {
            print('📈 Dashboard update received: $data');
            callback(data);
          });
        }
      });
      return;
    }

    _socket!.on('dashboardUpdate', (data) {
      print('📈 Dashboard update received: $data');
      callback(data);
    });
  }

  /// Listen to dashboard summary updates (for Super Admin)
  static void onDashboardSummaryUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Silently try to initialize - this is expected behavior
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('dashboardSummaryUpdate', (data) {
            print('📊 Dashboard summary update received: $data');
            callback(data);
          });
        }
      });
      return;
    }

    _socket!.on('dashboardSummaryUpdate', (data) {
      print('📊 Dashboard summary update received: $data');
      callback(data);
    });
  }

  /// Listen to expense type updates (for all users)
  static void onExpenseTypeUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Silently try to initialize - this is expected behavior
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('expenseTypeUpdate', (data) {
            print('📋 Expense type update received: $data');
            callback(data);
          });
        }
      });
      return;
    }

    _socket!.on('expenseTypeUpdate', (data) {
      print('📋 Expense type update received: $data');
      callback(data);
    });
  }

  /// Listen to user creation events (for Super Admin)
  /// Note: Backend emits user_created via amountUpdate event with type: 'user_created'
  static void onUserCreated(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Silently try to initialize - this is expected behavior
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('amountUpdate', (data) {
            if (data is Map<String, dynamic> && data['type'] == 'user_created') {
              print('👤 User created event received: ${data['details']}');
              // Pass the details object which contains user information
              callback(data['details'] ?? data);
            }
          });
        }
      });
      return;
    }

    _socket!.on('amountUpdate', (data) {
      if (data is Map<String, dynamic> && data['type'] == 'user_created') {
        print('👤 User created event received: ${data['details']}');
        // Pass the details object which contains user information
        callback(data['details'] ?? data);
      }
    });
  }

  /// Remove user created listener
  /// Note: This removes the amountUpdate listener, so use carefully if other listeners exist
  static void offUserCreated() {
    if (_socket != null) {
      // We can't selectively remove just the user_created filter from amountUpdate
      // So we'll need to handle this differently - the listener will remain but won't trigger
      // for user_created if we check the type. Alternatively, we can track our own listener.
      print('⚠️ offUserCreated called - amountUpdate listener remains active');
    }
  }

  /// Listen to self wallet updates (for all users)
  static void onSelfWalletUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Initialize socket if not already initialized
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('selfWalletUpdate', (data) {
            print('💰 Self wallet update received: $data');
            callback(data);
          });
        }
      });
      return;
    }

    _socket!.on('selfWalletUpdate', (data) {
      print('💰 Self wallet update received: $data');
      callback(data);
    });
  }

  /// Remove self wallet update listener
  static void offSelfWalletUpdate() {
    if (_socket != null) {
      _socket!.off('selfWalletUpdate');
    }
  }

  /// Listen to All Wallet Reports updates (for Super Admin)
  static void onAllWalletReportsUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Initialize socket if not already initialized
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('allWalletReportsUpdate', (data) {
            print('📊 [ALL WALLET REPORTS] Socket update received: $data');
            callback(data);
          });
        }
      });
      return;
    }

    _socket!.on('allWalletReportsUpdate', (data) {
      print('📊 [ALL WALLET REPORTS] Socket update received: $data');
      callback(data);
    });
  }

  /// Remove All Wallet Reports update listener
  static void offAllWalletReportsUpdate() {
    if (_socket != null) {
      _socket!.off('allWalletReportsUpdate');
    }
  }

  /// Listen to expense report stats update (for Super Admin)
  /// Lightweight update with summary statistics only
  static void onExpenseReportStatsUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Silently try to initialize - this is expected behavior
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('expenseReportStatsUpdate', (data) {
            print('📊 Expense report stats update received: $data');
            callback(data);
          });
        }
      });
      return;
    }

    _socket!.on('expenseReportStatsUpdate', (data) {
      print('📊 Expense report stats update received: $data');
      callback(data);
    });
  }

  /// Listen to expense report full update (for Super Admin)
  /// Full report data with all expenses, transactions, and collections
  static void onExpenseReportUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Silently try to initialize - this is expected behavior
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('expenseReportUpdate', (data) {
            print('📈 Expense report update received: $data');
            callback(data);
          });
        }
      });
      return;
    }

    _socket!.on('expenseReportUpdate', (data) {
      print('📈 Expense report update received: $data');
      callback(data);
    });
  }

  /// Listen to expense updates (for all users)
  /// Individual expense changes (created, updated, deleted, approved, rejected, flagged)
  static void onExpenseUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket == null) {
      // Silently try to initialize - this is expected behavior
      initialize().then((_) {
        if (_socket != null) {
          _socket!.on('expenseUpdate', (data) {
            print('💰 Expense update received: $data');
            callback(data);
          });
        }
      });
      return;
    }

    _socket!.on('expenseUpdate', (data) {
      print('💰 Expense update received: $data');
      callback(data);
    });
  }

  /// Remove expense report listeners
  static void offExpenseReportStatsUpdate() {
    if (_socket != null) {
      _socket!.off('expenseReportStatsUpdate');
    }
  }

  static void offExpenseReportUpdate() {
    if (_socket != null) {
      _socket!.off('expenseReportUpdate');
    }
  }

  static void offExpenseUpdate() {
    if (_socket != null) {
      _socket!.off('expenseUpdate');
    }
  }

  /// Remove all listeners
  static void removeAllListeners() {
    if (_socket != null) {
      _socket!.clearListeners();
    }
  }

  /// Disconnect socket
  static void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      print('🔌 Socket disconnected and disposed');
    }
  }

  /// Check if socket is connected
  static bool get isConnected => _isConnected && _socket != null;

  /// Get socket instance (for advanced usage)
  static IO.Socket? get socket => _socket;

  /// Reconnect socket with new token
  static Future<void> reconnect() async {
    disconnect();
    await Future.delayed(const Duration(seconds: 1));
    await initialize();
  }
}


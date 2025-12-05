import 'package:flutter/foundation.dart';

/// Global filter provider that manages filter state across all screens
/// This ensures filters persist when navigating between screens
class FilterProvider extends ChangeNotifier {
  // ============================================================================
  // USER FILTER
  // ============================================================================
  final Set<String> _selectedUserIds = <String>{};
  final Map<String, String> _selectedUserDisplayLabels = <String, String>{};
  String _selectedUserStatus = 'Active'; // 'All', 'Active', 'Inactive'

  // ============================================================================
  // DATE RANGE FILTER
  // ============================================================================
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedQuickRange; // 'This Month', 'Last Month', 'This FY', etc.
  int? _selectedQuarter; // 1, 2, 3, 4

  // ============================================================================
  // COMMON FILTERS
  // ============================================================================
  String? _selectedMode; // 'Cash', 'UPI', 'Bank', null = All
  String? _selectedStatus; // 'Approved', 'Unapproved', 'Pending', etc.
  String? _selectedType; // 'Expenses', 'Transactions', 'Collections', null = All

  // ============================================================================
  // GETTERS
  // ============================================================================
  Set<String> get selectedUserIds => Set<String>.from(_selectedUserIds);
  Map<String, String> get selectedUserDisplayLabels => Map<String, String>.from(_selectedUserDisplayLabels);
  String get selectedUserStatus => _selectedUserStatus;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get selectedQuickRange => _selectedQuickRange;
  int? get selectedQuarter => _selectedQuarter;
  String? get selectedMode => _selectedMode;
  String? get selectedStatus => _selectedStatus;
  String? get selectedType => _selectedType;

  // ============================================================================
  // USER FILTER METHODS
  // ============================================================================
  /// Set selected users
  void setSelectedUsers(Set<String> userIds, {Map<String, String>? labels}) {
    _selectedUserIds.clear();
    _selectedUserIds.addAll(userIds);
    if (labels != null) {
      _selectedUserDisplayLabels.clear();
      _selectedUserDisplayLabels.addAll(labels);
    }
    notifyListeners();
  }

  /// Add a user to selection
  void addUser(String userId, {String? label}) {
    _selectedUserIds.add(userId);
    if (label != null) {
      _selectedUserDisplayLabels[userId] = label;
    }
    notifyListeners();
  }

  /// Remove a user from selection
  void removeUser(String userId) {
    _selectedUserIds.remove(userId);
    _selectedUserDisplayLabels.remove(userId);
    notifyListeners();
  }

  /// Clear user filter
  void clearUserFilter() {
    _selectedUserIds.clear();
    _selectedUserDisplayLabels.clear();
    notifyListeners();
  }

  /// Set user status filter
  void setUserStatus(String status) {
    if (_selectedUserStatus != status) {
      _selectedUserStatus = status;
      notifyListeners();
    }
  }

  // ============================================================================
  // DATE RANGE METHODS
  // ============================================================================
  /// Set date range
  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    // Clear quick range when manually setting dates
    if (start != null || end != null) {
      _selectedQuickRange = null;
      _selectedQuarter = null;
    }
    notifyListeners();
  }

  /// Clear date range
  void clearDateRange() {
    _startDate = null;
    _endDate = null;
    _selectedQuickRange = null;
    _selectedQuarter = null;
    notifyListeners();
  }

  /// Set quick date range (This Month, Last Month, etc.)
  void setQuickRange(String? range, {int? quarter}) {
    _selectedQuickRange = range;
    _selectedQuarter = quarter;
    notifyListeners();
  }

  // ============================================================================
  // MODE FILTER METHODS
  // ============================================================================
  /// Set mode filter
  void setMode(String? mode) {
    if (_selectedMode != mode) {
      _selectedMode = mode;
      notifyListeners();
    }
  }

  // ============================================================================
  // STATUS FILTER METHODS
  // ============================================================================
  /// Set status filter
  void setStatus(String? status) {
    if (_selectedStatus != status) {
      _selectedStatus = status;
      notifyListeners();
    }
  }

  // ============================================================================
  // TYPE FILTER METHODS
  // ============================================================================
  /// Set type filter
  void setType(String? type) {
    if (_selectedType != type) {
      _selectedType = type;
      notifyListeners();
    }
  }

  // ============================================================================
  // CLEAR ALL FILTERS
  // ============================================================================
  /// Clear all filters
  void clearAllFilters() {
    _selectedUserIds.clear();
    _selectedUserDisplayLabels.clear();
    _selectedUserStatus = 'Active';
    _startDate = null;
    _endDate = null;
    _selectedQuickRange = null;
    _selectedQuarter = null;
    _selectedMode = null;
    _selectedStatus = null;
    _selectedType = null;
    notifyListeners();
  }

  /// Reset to default values
  void resetToDefaults() {
    clearAllFilters();
    _selectedUserStatus = 'Active';
    notifyListeners();
  }

  /// Check if any filters are active
  bool get hasActiveFilters {
    return _selectedUserIds.isNotEmpty ||
        _startDate != null ||
        _endDate != null ||
        _selectedMode != null ||
        _selectedStatus != null ||
        _selectedType != null ||
        _selectedQuickRange != null;
  }
}


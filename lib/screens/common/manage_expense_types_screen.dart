import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/edit_expense_type_dialog.dart';
import '../../widgets/add_expense_type_dialog.dart';
import '../../services/expense_type_service.dart';
import '../../services/socket_service.dart';
import '../super_admin/super_admin_dashboard.dart';
import '../../constants/nav_item.dart';

class ManageExpenseTypesScreen extends StatelessWidget {
  const ManageExpenseTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ManageExpenseTypesScreenContent();
  }
}

class _ManageExpenseTypesScreenContent extends StatefulWidget {
  const _ManageExpenseTypesScreenContent();

  @override
  State<_ManageExpenseTypesScreenContent> createState() => _ManageExpenseTypesScreenContentState();
}

class _ManageExpenseTypesScreenContentState extends State<_ManageExpenseTypesScreenContent> {
  String _selectedFilter = 'All';
  String _selectedStatus = 'Active';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _filters = ['All']; // Will be populated dynamically from expense types
  final List<String> _statusFilters = ['All', 'Active', 'Inactive'];
  static const int _maxDesktopCardsPerRow = 4;
  static const double _desktopCardWidth = 280;
  static const double _mobileCardWidth = 320;
  static const double _desktopCardHeightEstimate = 150;
  static const double _mobileCardHeightEstimate = 200;
  static const double _gridSpacing = 20;

  List<Map<String, dynamic>> _expenseTypes = [];
  bool _isLoading = true;
  
  // Debounce configuration for socket-based refresh
  static const Duration _debounceRefreshDelay = Duration(seconds: 2); // Debounce to prevent rapid refreshes
  DateTime? _lastRefreshTime;

  @override
  void initState() {
    super.initState();
    _loadExpenseTypes();
    _setupSocketListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setupSocketListener() {
    SocketService.onExpenseTypeUpdate((data) {
      if (!mounted) return;
      
      final event = data['event']?.toString() ?? '';
      final expenseType = data['expenseType'];
      
      if (event == 'created' || event == 'updated') {
        // Reload the list to get updated data
        _autoRefreshExpenseTypes();
      } else if (event == 'deleted') {
        // Remove from list
        setState(() {
          final expenseTypeId = expenseType['_id'] ?? expenseType['id'];
          _expenseTypes.removeWhere(
            (element) => element['id'] == expenseTypeId || element['_id'] == expenseTypeId,
          );
        });
      }
    });
    
    // Listen to dashboard updates (general updates)
    SocketService.onDashboardUpdate((data) {
      if (mounted) {
        _autoRefreshExpenseTypes();
      }
    });
    
    // Listen to expense updates (expense changes that might affect expense type counts)
    SocketService.onExpenseUpdate((data) {
      if (mounted) {
        _autoRefreshExpenseTypes();
      }
    });
  }

  /// Auto-refresh method with debouncing to prevent excessive API calls
  /// This method is called by socket events when expense types data changes
  void _autoRefreshExpenseTypes() {
    if (!mounted) return;
    
    // Debounce: Don't refresh if we just refreshed recently
    if (_lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < _debounceRefreshDelay) {
        // Too soon since last refresh, skip this one
        return;
      }
    }
    
    // Don't refresh if already loading
    if (_isLoading) {
      return;
    }
    
    // Update last refresh time
    _lastRefreshTime = DateTime.now();
    
    // Refresh expense types data silently
    _loadExpenseTypes();
  }

  Future<void> _loadExpenseTypes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ExpenseTypeService.getExpenseTypes();
      
      if (result['success'] == true && mounted) {
        final expenseTypes = result['expenseTypes'] as List<dynamic>? ?? [];
        setState(() {
          _expenseTypes = expenseTypes.map((et) {
            final rawExpenseType = _normalizeExpenseTypeMap(et);
            return {
              'id': rawExpenseType['_id'] ?? rawExpenseType['id'],
              'name': rawExpenseType['name'] ?? 'Unknown',
              'description': rawExpenseType['description'] ?? '',
              'status': rawExpenseType['isActive'] == true ? 'Active' : 'Inactive',
              'isActive': rawExpenseType['isActive'] ?? true,
              'expenseCount': rawExpenseType['expenseCount'] ?? 0,
              'imageUrl': rawExpenseType['imageUrl'],
              'proofRequired': rawExpenseType['proofRequired'] ?? rawExpenseType['isProofRequired'] ?? false,
            };
          }).toList();
          
          // Update filters dynamically from loaded expense types
          _filters = ['All'];
          final uniqueNames = _expenseTypes.map((et) => et['name']?.toString() ?? '').where((name) => name.isNotEmpty).toSet().toList();
          _filters.addAll(uniqueNames..sort());
          
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          if (result['message'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load expense types: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _normalizeExpenseTypeMap(dynamic expenseType) {
    if (expenseType is Map<String, dynamic>) {
      return Map<String, dynamic>.from(expenseType);
    }
    if (expenseType is Map) {
      final normalized = <String, dynamic>{};
      expenseType.forEach((key, value) {
        final normalizedKey = key is String ? key : key?.toString() ?? '';
        if (normalizedKey.isNotEmpty) {
          normalized[normalizedKey] = value;
        }
      });
      return normalized;
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> get _filteredExpenseTypes {
    Iterable<Map<String, dynamic>> filtered = _expenseTypes;

    if (_selectedFilter != 'All') {
      filtered = filtered.where(
        (type) => _typeMatchesFilter(type['name']?.toString()),
      );
    }

    if (_selectedStatus != 'All') {
      filtered = filtered.where(_matchesSelectedStatus);
    }

    if (_searchQuery.trim().isNotEmpty) {
      filtered = filtered.where(_matchesSearchQuery);
    }

    return filtered.toList();
  }

  bool _typeMatchesFilter(String? type) {
    if (_selectedFilter == 'All') {
      return true;
    }

    final normalizedType = _normalizeFilterValue(type);
    final normalizedFilter = _normalizeFilterValue(_selectedFilter);

    if (normalizedType.isEmpty) {
      return false;
    }

    return normalizedType == normalizedFilter;
  }

  bool _matchesSelectedStatus(Map<String, dynamic> type) {
    final normalizedFilter = _normalizeFilterValue(_selectedStatus);
    if (normalizedFilter.isEmpty || normalizedFilter == 'all') {
      return true;
    }

    final directStatus = _normalizeFilterValue(type['status']?.toString());
    if (directStatus.isNotEmpty) {
      return _statusMatchesFilterValue(directStatus, normalizedFilter);
    }

    final bool? isActive = type['isActive'] as bool?;
    if (isActive != null) {
      final normalized = isActive ? 'active' : 'inactive';
      return _statusMatchesFilterValue(normalized, normalizedFilter);
    }

    return false;
  }

  bool _statusMatchesFilterValue(String normalizedStatus, String normalizedFilter) {
    if (normalizedStatus.isEmpty || normalizedFilter.isEmpty) {
      return false;
    }

    if (normalizedStatus == normalizedFilter) {
      return true;
    }

    if (normalizedFilter == 'active') {
      return normalizedStatus == 'true' ||
          normalizedStatus.contains('active') ||
          normalizedStatus.contains('verified') ||
          normalizedStatus.contains('enable') ||
          normalizedStatus.contains('approve');
    }

    if (normalizedFilter == 'inactive') {
      return normalizedStatus == 'false' ||
          normalizedStatus.contains('inactive') ||
          normalizedStatus.contains('pending') ||
          normalizedStatus.contains('disable') ||
          normalizedStatus.contains('suspend');
    }

    return false;
  }

  String _normalizeFilterValue(String? value) {
    return value == null
        ? ''
        : value
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  bool _matchesSearchQuery(Map<String, dynamic> type) {
    final normalizedQuery = _normalizeFilterValue(_searchQuery);
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final valuesToSearch = <String?>[
      type['name']?.toString(),
      type['description']?.toString(),
    ];

    for (final value in valuesToSearch) {
      final normalizedCandidate = _normalizeFilterValue(value);
      if (normalizedCandidate.contains(normalizedQuery)) {
        return true;
      }
    }

    return false;
  }

  void _clearSearch() {
    if (_searchQuery.isEmpty) return;
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _clearAllFilters() {
    final hasChanges = _selectedFilter != 'All' ||
        _selectedStatus != 'Active' ||
        _searchQuery.trim().isNotEmpty;

    if (!hasChanges) {
      return;
    }

    setState(() {
      _selectedFilter = 'All';
      _selectedStatus = 'Active';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      border: Border(
                        bottom: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // First row: Filter by Type and Filter by Status
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.filter_list,
                                          size: 18,
                                          color: AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Type:',
                                          style: AppTheme.labelMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceColor,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.borderColor.withValues(alpha: 0.5),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: DropdownButton<String>(
                                              value: _selectedFilter,
                                              underline: const SizedBox(),
                                              isDense: true,
                                              isExpanded: true,
                                              icon: const Icon(Icons.arrow_drop_down, size: 20),
                                              iconEnabledColor: AppTheme.primaryColor,
                                              style: AppTheme.bodySmall.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              items: _filters.map((String filter) {
                                                return DropdownMenuItem<String>(
                                                  value: filter,
                                                  child: Text(
                                                    filter,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (String? newValue) {
                                                if (newValue != null) {
                                                  setState(() {
                                                    _selectedFilter = newValue;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          'Status:',
                                          style: AppTheme.labelMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceColor,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppTheme.borderColor.withValues(alpha: 0.5),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: DropdownButton<String>(
                                              value: _selectedStatus,
                                              underline: const SizedBox(),
                                              isDense: true,
                                              isExpanded: true,
                                              icon: const Icon(Icons.arrow_drop_down, size: 20),
                                              iconEnabledColor: AppTheme.primaryColor,
                                              style: AppTheme.bodySmall.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                              items: _statusFilters.map((String filter) {
                                                return DropdownMenuItem<String>(
                                                  value: filter,
                                                  child: Text(
                                                    filter,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (String? newValue) {
                                                if (newValue != null) {
                                                  setState(() {
                                                    _selectedStatus = newValue;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Second row: Search field
                              Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.borderColor.withValues(alpha: 0.4),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.search, size: 18, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (value) {
                                          setState(() {
                                            _searchQuery = value;
                                          });
                                        },
                                        style: AppTheme.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          hintText: 'Search name, description',
                                          hintStyle: AppTheme.bodySmall.copyWith(
                                            color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_searchQuery.trim().isNotEmpty)
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        splashRadius: 16,
                                        icon: Icon(
                                          Icons.clear_rounded,
                                          size: 16,
                                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                        ),
                                        onPressed: _clearSearch,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Third row: Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _clearAllFilters,
                                      icon: Icon(Icons.refresh_outlined, size: 16),
                                      label: Text(
                                        'Clear All',
                                        style: AppTheme.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.textSecondary,
                                        side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _onAddExpenseType,
                                      icon: Icon(Icons.add_outlined, size: 16),
                                      label: Text(
                                        'Add New',
                                        style: AppTheme.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primaryColor,
                                        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.6)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.filter_list,
                                size: 20,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Filter by Type:',
                                style: AppTheme.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Material(
                                elevation: 8,
                                color: Colors.transparent,
                                shadowColor: Colors.transparent,
                                child: PopupMenuButton<String>(
                                  offset: const Offset(0, 50), // Position menu at bottom of button
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.08),
                                  surfaceTintColor: Colors.transparent,
                                  color: Colors.white,
                                  constraints: const BoxConstraints(
                                    minWidth: 200,
                                    maxWidth: 200,
                                    maxHeight: 300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onSelected: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedFilter = newValue;
                                      });
                                    }
                                  },
                                  itemBuilder: (context) {
                                    return _filters.map<PopupMenuEntry<String>>((String filter) {
                                      final isSelected = filter == _selectedFilter;
                                      return PopupMenuItem<String>(
                                        value: filter,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            if (isSelected)
                                              Icon(
                                                Icons.check,
                                                size: 18,
                                                color: AppTheme.primaryColor,
                                              )
                                            else
                                              const SizedBox(width: 18),
                                            if (isSelected) const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                filter,
                                                style: AppTheme.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor,
                                      borderRadius: BorderRadius.zero,
                                      border: Border.all(
                                        color: AppTheme.borderColor.withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _selectedFilter,
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 24,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Filter by Status:',
                                style: AppTheme.labelMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Material(
                                elevation: 8,
                                color: Colors.transparent,
                                shadowColor: Colors.transparent,
                                child: PopupMenuButton<String>(
                                  offset: const Offset(0, 50), // Position menu at bottom of button
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.08),
                                  surfaceTintColor: Colors.transparent,
                                  color: Colors.white,
                                  constraints: const BoxConstraints(
                                    minWidth: 200,
                                    maxWidth: 200,
                                    maxHeight: 300,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onSelected: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedStatus = newValue;
                                      });
                                    }
                                  },
                                  itemBuilder: (context) {
                                    return _statusFilters.map<PopupMenuEntry<String>>((String filter) {
                                      final isSelected = filter == _selectedStatus;
                                      return PopupMenuItem<String>(
                                        value: filter,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            if (isSelected)
                                              Icon(
                                                Icons.check,
                                                size: 18,
                                                color: AppTheme.primaryColor,
                                              )
                                            else
                                              const SizedBox(width: 18),
                                            if (isSelected) const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                filter,
                                                style: AppTheme.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor,
                                      borderRadius: BorderRadius.zero,
                                      border: Border.all(
                                        color: AppTheme.borderColor.withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _selectedStatus,
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 24,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Flexible(
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.borderColor.withValues(alpha: 0.4),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.search, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchController,
                                          onChanged: (value) {
                                            setState(() {
                                              _searchQuery = value;
                                            });
                                          },
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            hintText: 'Search name, description',
                                            hintStyle: AppTheme.bodyMedium.copyWith(
                                              color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_searchQuery.trim().isNotEmpty)
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          splashRadius: 18,
                                          icon: Icon(
                                            Icons.clear_rounded,
                                            size: 18,
                                            color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                          ),
                                          onPressed: _clearSearch,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: _clearAllFilters,
                                icon: Icon(Icons.refresh_outlined, size: 20),
                                label: Text(
                                  'Clear All',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.textSecondary,
                                  side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                onPressed: _onAddExpenseType,
                                icon: Icon(Icons.add_outlined, size: 20),
                                label: Text(
                                  'Add New Expenses Type',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryColor,
                                  side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                          reverseCurve: Curves.easeIn,
                        );
                        final offsetAnimation = Tween<Offset>(
                          begin: const Offset(-0.04, 0),
                          end: Offset.zero,
                        ).animate(curved);
                        return ClipRect(
                          child: FadeTransition(
                            opacity: curved,
                            child: SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: _isLoading
                          ? const Center(
                              key: ValueKey('loading'),
                              child: CircularProgressIndicator(),
                            )
                          : _filteredExpenseTypes.isEmpty
                              ? Center(
                                  key: const ValueKey('empty'),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.category_outlined,
                                        size: 64,
                                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No expense types found',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                )
                              : LayoutBuilder(
                                  key: ValueKey(
                                    'grid-${_filteredExpenseTypes.length}-${_selectedFilter}-${_selectedStatus}',
                                  ),
                                  builder: (context, constraints) {
                                    final gridConfig = _calculateGridConfiguration(
                                      maxWidth: constraints.maxWidth,
                                      isMobile: isMobile,
                                    );
                                    return GridView.builder(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 16 : 24,
                                        vertical: isMobile ? 12 : 20,
                                      ),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: gridConfig.crossAxisCount,
                                        crossAxisSpacing: _gridSpacing,
                                        mainAxisSpacing: _gridSpacing,
                                        childAspectRatio: gridConfig.childAspectRatio,
                                      ),
                                      itemCount: _filteredExpenseTypes.length,
                                      itemBuilder: (context, index) => _buildExpenseTypeCard(
                                        context,
                                        _filteredExpenseTypes[index],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTypeCard(BuildContext context, Map<String, dynamic> expenseType) {
    final isMobileView = Responsive.isMobile(context);
    final isActive = expenseType['status'] == 'Active' || expenseType['isActive'] == true;
    final typeColor = _getTypeColor(expenseType['name']?.toString() ?? '');
    final typeName = expenseType['name']?.toString() ?? '';
    final description = expenseType['description']?.toString() ?? '';
    final expenseCount = expenseType['expenseCount'] ?? 0;

    final bannerMessage = isActive ? 'ACTIVE' : 'INACTIVE';
    final bannerColor = isActive ? AppTheme.secondaryColor : AppTheme.errorColor;
    // Increased right padding to account for Banner widget (typically ~50-60px)
    final EdgeInsets cardPadding = isMobileView
        ? const EdgeInsets.fromLTRB(18, 10, 20, 10)
        : const EdgeInsets.fromLTRB(18, 8, 20, 8);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: null,
            borderRadius: BorderRadius.circular(20),
            child: Banner(
              message: bannerMessage,
              location: BannerLocation.topEnd,
              color: bannerColor,
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
              child: Container(
                padding: cardPadding,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.35),
                    width: 0.9,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTypeIcon(
                              name: typeName,
                              typeColor: typeColor,
                              imageUrl: expenseType['imageUrl'],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    typeName,
                                    style: AppTheme.headingSmall.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (description.isNotEmpty)
                                    _buildInfoLine(
                                      label: description,
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      _buildEditButton(
                                        onTap: () => _onEditExpenseType(expenseType),
                                        isMobileView: isMobileView,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon({
    required String name,
    required Color typeColor,
    String? imageUrl,
  }) {
    final finalImageUrl = imageUrl ?? _getTypeImageUrl(name);
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 100,
        maxHeight: 100,
        minWidth: 80,
        minHeight: 80,
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
            child: Container(
            color: typeColor.withValues(alpha: 0.14),
            child: finalImageUrl != null && finalImageUrl.isNotEmpty
                ? Image.network(
                    finalImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image fails to load
                      final icon = _getTypeIcon(name);
                      return icon != null
                          ? Icon(
                              icon,
                              size: 48,
                              color: typeColor,
                            )
                          : _TypeInitials(
                              name: name,
                              typeColor: typeColor,
                            );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                        ),
                      );
                    },
                  )
                : _TypeInitials(
                    name: name,
                    typeColor: typeColor,
                  ),
          ),
        ),
      ),
    );
  }

  String? _getTypeImageUrl(String type) {
    // Using Unsplash images for real photos - specific and recognizable images based on name
    final normalizedType = type.trim().toLowerCase();
    
    // Office related images - coffee/office break
    if (normalizedType.contains('office') || normalizedType.contains('coffee') || normalizedType.contains('cafe')) {
      return 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&h=400&fit=crop';
    }
    
    // Travel related images - tour bus
    if (normalizedType.contains('travel') || normalizedType.contains('bus') || normalizedType.contains('transport')) {
      return 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=400&h=400&fit=crop';
    }
    
    // Marketing related images - team with sticky notes/whiteboard
    if (normalizedType.contains('marketing') || normalizedType.contains('advert') || normalizedType.contains('promo')) {
      return 'https://images.unsplash.com/photo-1552664730-d307ca884978?w=400&h=400&fit=crop';
    }
    
    // Maintenance related images - tools/drill
    if (normalizedType.contains('maintenance') || normalizedType.contains('repair') || normalizedType.contains('tool')) {
      return 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=400&h=400&fit=crop';
    }
    
    // Misc related images - desk with papers/calculator
    if (normalizedType.contains('misc') || normalizedType.contains('miscellaneous') || normalizedType.contains('other')) {
      return 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400&h=400&fit=crop';
    }
    
    // Food related images
    if (normalizedType.contains('food') || normalizedType.contains('meal') || normalizedType.contains('restaurant')) {
      return 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=400&h=400&fit=crop';
    }
    
    // Medical related images
    if (normalizedType.contains('medical') || normalizedType.contains('health') || normalizedType.contains('hospital')) {
      return 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1f?w=400&h=400&fit=crop';
    }
    
    // Fuel related images
    if (normalizedType.contains('fuel') || normalizedType.contains('petrol') || normalizedType.contains('gas')) {
      return 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&h=400&fit=crop';
    }
    
    // Stationery related images
    if (normalizedType.contains('stationery') || normalizedType.contains('supplies') || normalizedType.contains('office supply')) {
      return 'https://images.unsplash.com/photo-1586953208448-b95a79798f07?w=400&h=400&fit=crop';
    }
    
    // Default fallback for unknown types - desk with papers
    return 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=400&h=400&fit=crop';
  }

  IconData? _getTypeIcon(String type) {
    switch (type) {
      case 'Office':
        return Icons.business_outlined;
      case 'Travel':
        return Icons.flight_outlined;
      case 'Marketing':
        return Icons.campaign_outlined;
      case 'Maintenance':
        return Icons.build_outlined;
      case 'Misc':
        return Icons.category_outlined;
      default:
        return null;
    }
  }

  Widget _buildInfoLine({
    IconData? icon,
    required String label,
  }) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 14,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEditButton({
    required VoidCallback onTap,
    required bool isMobileView,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: isMobileView ? 2 : 0),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          padding: EdgeInsets.all(isMobileView ? 8 : 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobileView ? 10 : 8),
          ),
          minimumSize: Size(isMobileView ? 36 : 34, isMobileView ? 36 : 34),
        ),
        child: const Icon(Icons.edit_outlined, size: 16),
      ),
    );
  }

  Widget _buildDeleteButton({
    required VoidCallback onTap,
    required bool isMobileView,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: isMobileView ? 2 : 0),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
          padding: EdgeInsets.all(isMobileView ? 8 : 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobileView ? 10 : 8),
          ),
          minimumSize: Size(isMobileView ? 36 : 34, isMobileView ? 36 : 34),
        ),
        child: const Icon(Icons.delete_outlined, size: 16),
      ),
    );
  }

  _GridConfiguration _calculateGridConfiguration({
    required double maxWidth,
    required bool isMobile,
  }) {
    // Account for horizontal padding (left + right) and Banner overhead
    final horizontalPadding = isMobile ? 32.0 : 48.0; // 16*2 or 24*2
    final effectiveMaxWidth = maxWidth - horizontalPadding;
    final targetCardWidth = isMobile ? _mobileCardWidth : _desktopCardWidth;
    int crossAxisCount = (effectiveMaxWidth / targetCardWidth).floor();
    if (crossAxisCount < 1) {
      crossAxisCount = 1;
    }
    if (!isMobile) {
      crossAxisCount = crossAxisCount.clamp(1, _maxDesktopCardsPerRow);
    }
    final effectiveSpacing = _gridSpacing * (crossAxisCount - 1);
    final availableWidth = effectiveMaxWidth - effectiveSpacing;
    final cardWidth = availableWidth > 0 ? availableWidth / crossAxisCount : targetCardWidth;
    final estimatedHeight =
        isMobile ? _mobileCardHeightEstimate : _desktopCardHeightEstimate;
    final childAspectRatio = cardWidth / estimatedHeight;
    return _GridConfiguration(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio > 0 ? childAspectRatio : 1,
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Office':
        return Colors.blue;
      case 'Travel':
        return Colors.orange;
      case 'Marketing':
        return Colors.purple;
      case 'Maintenance':
        return Colors.green;
      case 'Misc':
        return Colors.grey;
      default:
        return AppTheme.textSecondary;
    }
  }

  Future<void> _onAddExpenseType() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: const AddExpenseTypeDialog(),
        );
      },
    );

    if (!mounted) return;

    if (result is Map<String, dynamic>) {
      final event = result['event'];

      if (event == 'created') {
        await _loadExpenseTypes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense type created successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    }
  }

  void _navigateToExpenseReport(Map<String, dynamic> expenseType) {
    final typeName = expenseType['name']?.toString() ?? '';
    if (typeName.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SuperAdminDashboard(
          initialSelectedItem: NavItem.expenseReport,
          initialSelectedType: 'Expenses',
          initialSelectedExpenseTypeCategory: typeName,
          // No status filter - show all expenses of this type
        ),
      ),
    );
  }

  Future<void> _onEditExpenseType(Map<String, dynamic> expenseType) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: EditExpenseTypeDialog(
            expenseType: Map<String, dynamic>.from(expenseType),
          ),
        );
      },
    );

    if (!mounted) return;

    if (result is Map<String, dynamic>) {
      final event = result['event'];

      if (event == 'updated') {
        await _loadExpenseTypes();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense type updated successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else if (event == 'deleted') {
        await _loadExpenseTypes();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Expense type deleted successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      }
    }
  }

  Future<void> _onDeleteExpenseType(Map<String, dynamic> expenseType) async {
    final expenseTypeId = expenseType['id'] ?? expenseType['_id'];
    final expenseTypeName = expenseType['name'] ?? 'this expense type';

    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense Type'),
        content: Text(
          'Are you sure you want to delete "$expenseTypeName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete != true || expenseTypeId == null) return;

    try {
      final result = await ExpenseTypeService.deleteExpenseType(expenseTypeId.toString());

      if (!mounted) return;

      if (result['success'] == true) {
        await _loadExpenseTypes();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Expense type deleted successfully'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to delete expense type'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting expense type: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

class _TypeInitials extends StatelessWidget {
  const _TypeInitials({
    required this.name,
    required this.typeColor,
  });

  final String name;
  final Color typeColor;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
            .trim()
            .substring(0, 1)
            .toUpperCase();

    return Container(
      color: typeColor.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTheme.headingMedium.copyWith(
          color: typeColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GridConfiguration {
  const _GridConfiguration({
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  final int crossAxisCount;
  final double childAspectRatio;
}


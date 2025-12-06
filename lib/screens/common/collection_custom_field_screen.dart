import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/add_custom_field_dialog.dart';
import '../../widgets/add_collection_dialog.dart';
import '../../services/custom_field_service.dart';

class CollectionCustomFieldScreen extends StatefulWidget {
  final bool showAppBar;
  final VoidCallback? onBackPressed;
  
  const CollectionCustomFieldScreen({
    super.key,
    this.showAppBar = true,
    this.onBackPressed,
  });

  @override
  State<CollectionCustomFieldScreen> createState() => CollectionCustomFieldScreenState();
}

class CollectionCustomFieldScreenState extends State<CollectionCustomFieldScreen> {
  final GlobalKey<_CollectionCustomFieldScreenContentState> _contentKey = GlobalKey<_CollectionCustomFieldScreenContentState>();

  void refresh() {
    _contentKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return _CollectionCustomFieldScreenContent(
      key: _contentKey,
      showAppBar: widget.showAppBar,
      onBackPressed: widget.onBackPressed,
    );
  }
}

class _CollectionCustomFieldScreenContent extends StatefulWidget {
  final bool showAppBar;
  final VoidCallback? onBackPressed;
  
  const _CollectionCustomFieldScreenContent({
    super.key,
    required this.showAppBar,
    this.onBackPressed,
  });

  @override
  State<_CollectionCustomFieldScreenContent> createState() => _CollectionCustomFieldScreenContentState();
}

class _CollectionCustomFieldScreenContentState extends State<_CollectionCustomFieldScreenContent> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _customFields = [];
  bool _isLoading = true;
  
  static const int _maxDesktopCardsPerRow = 4;
  static const double _desktopCardWidth = 280;
  static const double _mobileCardWidth = 320;
  static const double _desktopCardHeightEstimate = 150;
  static const double _mobileCardHeightEstimate = 200;
  static const double _gridSpacing = 20;

  @override
  void initState() {
    super.initState();
    _loadCustomFields();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void refresh() {
    _loadCustomFields();
  }

  Future<void> _loadCustomFields() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CustomFieldService.getCustomFields();
      
      if (mounted) {
        if (result['success'] == true) {
          final customFields = result['customFields'] as List<dynamic>? ?? [];
          setState(() {
            _customFields = customFields.map((field) {
              return {
                'id': field['_id'] ?? field['id'],
                'name': field['name'] ?? '',
                'isActive': field['isActive'] ?? true,
                'createdAt': field['createdAt'] != null 
                    ? (field['createdAt'] is String 
                        ? field['createdAt'] 
                        : DateTime.parse(field['createdAt'].toString()).toString().split(' ')[0])
                    : null,
              };
            }).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _customFields = [];
          });
          final errorMessage = result['message'] ?? 'Failed to load custom fields';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _customFields = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading custom fields: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCustomFields {
    if (_searchQuery.trim().isEmpty) {
      return _customFields;
    }
    final query = _searchQuery.toLowerCase();
    return _customFields.where((field) {
      final name = field['name']?.toString().toLowerCase() ?? '';
      return name.contains(query);
    }).toList();
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _onAddCustomField() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddCustomFieldDialog(
        onSuccess: () {
          _loadCustomFields();
        },
      ),
    );
  }

  void _onEditCustomField(Map<String, dynamic> customField) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddCustomFieldDialog(
        customField: customField,
        onSuccess: () {
          _loadCustomFields();
        },
      ),
    );
  }

  Future<void> _onToggleActive(Map<String, dynamic> customField, bool isActive) async {
    final fieldName = customField['name']?.toString() ?? '';
    final customFieldId = customField['id']?.toString() ?? '';
    
    try {
      final result = await CustomFieldService.updateCustomField(
        customFieldId,
        isActive: isActive,
      );

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            final index = _customFields.indexWhere((field) => field['id'] == customField['id']);
            if (index != -1) {
              _customFields[index]['isActive'] = isActive;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 
                  (isActive 
                      ? 'Custom field "$fieldName" activated successfully'
                      : 'Custom field "$fieldName" deactivated successfully')),
              backgroundColor: AppTheme.secondaryColor,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Error updating custom field status'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating custom field: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _onDeleteCustomField(Map<String, dynamic> customField) async {
    final fieldName = customField['name']?.toString() ?? 'this field';
    
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Custom Field'),
        content: Text('Are you sure you want to delete "$fieldName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete == true && mounted) {
      try {
        final customFieldId = customField['id']?.toString() ?? '';
        final result = await CustomFieldService.deleteCustomField(customFieldId);

        if (mounted) {
          if (result['success'] == true) {
            setState(() {
              _customFields.removeWhere((field) => field['id'] == customField['id']);
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Custom field "$fieldName" deleted successfully'),
                backgroundColor: AppTheme.secondaryColor,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Error deleting custom field'),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting custom field: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Map<String, dynamic> _calculateGridConfiguration({
    required double maxWidth,
    required bool isMobile,
  }) {
    if (isMobile) {
      return {
        'crossAxisCount': 1,
        'childAspectRatio': _mobileCardWidth / _mobileCardHeightEstimate,
      };
    }

    int crossAxisCount = 4;
    if (maxWidth < 1200) {
      crossAxisCount = 3;
    }
    if (maxWidth < 900) {
      crossAxisCount = 2;
    }

    return {
      'crossAxisCount': crossAxisCount,
      'childAspectRatio': _desktopCardWidth / _desktopCardHeightEstimate,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          color: AppTheme.textPrimary,
          tooltip: 'Back',
        ),
        automaticallyImplyLeading: false,
        title: const Text(
          'Collection Custom Field',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        iconTheme: const IconThemeData(
          color: AppTheme.textPrimary,
          size: 24,
        ),
      ) : null,
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search bar and Add Custom Field button on same line
            Row(
              children: [
                // Search bar - expands to fill available space
                Expanded(
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
                        Icon(
                          Icons.search,
                          size: 18,
                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        ),
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
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Search custom fields...',
                              hintStyle: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary.withValues(alpha: 0.6),
                                fontSize: 13,
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
                // Add Custom Field button
                ElevatedButton.icon(
                  onPressed: _onAddCustomField,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Custom Field'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Button Reference Guide
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Button Reference:',
                          style: AppTheme.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildButtonReferenceItem(
                              icon: Icons.toggle_on,
                              color: AppTheme.secondaryColor,
                              label: 'Active/Inactive Toggle',
                            ),
                            _buildButtonReferenceItem(
                              icon: Icons.edit_outlined,
                              color: AppTheme.primaryColor,
                              label: 'Edit',
                            ),
                            _buildButtonReferenceItem(
                              icon: Icons.delete_outlined,
                              color: AppTheme.errorColor,
                              label: 'Delete',
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Text(
                          'Button Reference: ',
                          style: AppTheme.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildButtonReferenceItem(
                          icon: Icons.toggle_on,
                          color: AppTheme.secondaryColor,
                          label: 'Active/Inactive Toggle',
                        ),
                        const SizedBox(width: 12),
                        _buildButtonReferenceItem(
                          icon: Icons.edit_outlined,
                          color: AppTheme.primaryColor,
                          label: 'Edit',
                        ),
                        const SizedBox(width: 12),
                        _buildButtonReferenceItem(
                          icon: Icons.delete_outlined,
                          color: AppTheme.errorColor,
                          label: 'Delete',
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            // Content area - Custom Fields Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCustomFields.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.text_fields_outlined,
                                size: 64,
                                color: AppTheme.textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.trim().isEmpty
                                    ? 'No custom fields found'
                                    : 'No custom fields match your search',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              if (_searchQuery.trim().isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Click "+ Add Custom Field" to create your first custom field',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final gridConfig = _calculateGridConfiguration(
                              maxWidth: constraints.maxWidth,
                              isMobile: isMobile,
                            );
                            return GridView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 0 : 0,
                                vertical: isMobile ? 12 : 20,
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: gridConfig['crossAxisCount'] as int,
                                crossAxisSpacing: _gridSpacing,
                                mainAxisSpacing: _gridSpacing,
                                childAspectRatio: gridConfig['childAspectRatio'] as double,
                              ),
                              itemCount: _filteredCustomFields.length,
                              itemBuilder: (context, index) => _buildCustomFieldCard(
                                context,
                                _filteredCustomFields[index],
                                isMobile,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFieldCard(BuildContext context, Map<String, dynamic> customField, bool isMobileView) {
    final isActive = customField['isActive'] == true;
    final fieldName = customField['name']?.toString() ?? '';
    final createdAt = customField['createdAt']?.toString() ?? '';

    final bannerMessage = isActive ? 'ACTIVE' : 'INACTIVE';
    final bannerColor = isActive ? AppTheme.secondaryColor : AppTheme.errorColor;
    final cardPadding = isMobileView
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.text_fields,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                fieldName,
                                style: AppTheme.headingSmall.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (createdAt.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Created: $createdAt',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Active/Inactive Toggle Switch
                                  Row(
                                    children: [
                                      Text(
                                        isActive ? 'Active' : 'Inactive',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: isActive ? AppTheme.secondaryColor : AppTheme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Switch(
                                        value: isActive,
                                        onChanged: (value) => _onToggleActive(customField, value),
                                        activeColor: AppTheme.secondaryColor,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  // Edit Button
                                  _buildEditButton(
                                    onTap: () => _onEditCustomField(customField),
                                    isMobileView: isMobileView,
                                  ),
                                  const SizedBox(width: 4),
                                  // Delete Button
                                  _buildDeleteButton(
                                    onTap: () => _onDeleteCustomField(customField),
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
                ),
              ),
            ),
          ),
        ),
      ),
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


  Widget _buildButtonReferenceItem({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}


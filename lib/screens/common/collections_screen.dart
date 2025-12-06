import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../services/collection_service.dart';
import '../../widgets/screen_back_button.dart';

class CollectionsScreen extends StatefulWidget {
  final String role;
  final bool embedInDashboard;
  
  const CollectionsScreen({super.key, required this.role, this.embedInDashboard = false});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await CollectionService.getCollections();
      if (result['success'] == true && mounted) {
        final collections = result['collections'] as List<dynamic>? ?? [];
        setState(() {
          _collections = collections.map((c) => _formatCollection(c)).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _formatCollection(dynamic collection) {
    final date = collection['createdAt'] != null 
        ? DateTime.parse(collection['createdAt']).toLocal()
        : DateTime.now();
    
    // Check if this is a system collection or systematic entry (created by System)
    final collectedBy = collection['collectedBy'];
    final isSystemCollection = collection['isSystemCollection'] == true || collectedBy == null;
    final isSystematicEntry = collection['isSystematicEntry'] == true || collection['collectionType'] == 'systematic';
    String createdByName = 'Unknown';
    if (isSystemCollection || isSystematicEntry) {
      createdByName = 'System';
    } else if (collectedBy is Map) {
      final collectedByMap = collectedBy as Map;
      createdByName = (collectedByMap['name']?.toString()) ?? 'Unknown';
    }
    
    // Get 'from' field (collector name)
    // For system collections, 'from' field should always be populated with collector
    // Handle cases where 'from' might be an ObjectId string or not populated
    String fromName = 'Unknown';
    final fromField = collection['from'];
    if (fromField != null) {
      if (fromField is Map<String, dynamic>) {
        final fromMap = fromField as Map<String, dynamic>;
        fromName = fromMap['name']?.toString() ?? 'Unknown';
      } else if (fromField is Map) {
        final fromMap = fromField as Map;
        fromName = (fromMap['name']?.toString()) ?? 'Unknown';
      }
    }
    
    // For system collections, if 'from' is not available, try to get from parent collection
    // For regular collections, fallback to collectedBy if from is not set
    if (fromName == 'Unknown') {
      if (isSystemCollection) {
        // System collection: if 'from' is not available, we can't determine collector
        // This should not happen if backend sets 'from' correctly
        fromName = 'Unknown';
      } else {
        // Regular collection: fallback to collectedBy
        final collectedBy = collection['collectedBy'];
        if (collectedBy is Map) {
          final collectedByMap = collectedBy as Map;
          fromName = (collectedByMap['name']?.toString()) ?? 'Unknown';
        } else {
          fromName = 'Unknown';
        }
      }
    }
    
    // Safely get receiver name
    String receiverName = 'Unknown';
    final assignedReceiver = collection['assignedReceiver'];
    if (assignedReceiver is Map) {
      final receiverMap = assignedReceiver as Map;
      receiverName = (receiverMap['name']?.toString()) ?? 'Unknown';
    }
    
    return {
      'id': collection['_id']?.toString() ?? collection['id']?.toString() ?? '',
      'voucherNumber': collection['voucherNumber']?.toString() ?? 'N/A',
      'date': '${date.day}-${_getMonthAbbr(date.month)}-${date.year.toString().substring(2)}',
      'time': '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
      'user': fromName, // From field (collector)
      'receiver': receiverName,
      'mode': collection['mode']?.toString() ?? 'Unknown',
      'amount': '₹${_formatAmount((collection['amount'] ?? 0).toDouble())}',
      'description': collection['customerName']?.toString() ?? 'Collection',
      'status': collection['status']?.toString() ?? 'Pending',
      'autoPay': collection['isAutoPay'] == true,
      'createdBy': createdByName, // Created by (System or collector name)
      'customerName': collection['customerName']?.toString() ?? '',
      'from': fromName, // From field for display
      'collectionType': collection['collectionType']?.toString() ?? 'collection',
    };
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isDesktop = Responsive.isDesktop(context);

    final content = SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Back button and title - only show if not embedded in dashboard
            if (!widget.embedInDashboard)
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
                child: Row(
                  children: [
                    const ScreenBackButton(),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: Text(
                        '${widget.role} Collections',
                        style: AppTheme.headingMedium.copyWith(
                          fontSize: isMobile ? 20 : isTablet ? 22 : 24,
                        ),
                      ),
                    ),
                    if (widget.role == 'Admin')
                      IconButton(
                        icon: Icon(Icons.add, size: isMobile ? 20 : 24),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Add Collection feature is currently unavailable'),
                            ),
                          );
                        },
                        tooltip: 'Add Collection',
                      ),
                  ],
                ),
              ),

            // Recent Collections Table Section
            Container(
              padding: widget.embedInDashboard 
                  ? EdgeInsets.fromLTRB(
                      isMobile ? 8 : isTablet ? 10 : 12, 
                      0, 
                      isMobile ? 8 : isTablet ? 10 : 12, 
                      isMobile ? 8 : isTablet ? 10 : 12
                    )
                  : EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row with "Collections" title - only show when embedded
                  if (widget.embedInDashboard)
                    Padding(
                      padding: EdgeInsets.zero,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Collections',
                            style: AppTheme.headingMedium.copyWith(
                              fontSize: isMobile ? 16 : isTablet ? 17 : 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.role == 'Admin' || widget.role == 'Super Admin')
                            IconButton(
                              icon: Icon(Icons.add, size: isMobile ? 18 : isTablet ? 19 : 20),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Add Collection feature is currently unavailable'),
                                  ),
                                );
                              },
                              tooltip: 'Add Collection',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                  _buildCollectionsTable(context),
                ],
              ),
            ),
            ],
          ),
        ),
      );

    if (widget.embedInDashboard) {
      return content;
    }
    
    return Scaffold(
      body: content,
    );
  }

  // Flag Popup
  void _showFlagPopup(BuildContext context, String collectionId, String description) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flag_outlined, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text('Flag Collection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collection: $description'),
            const SizedBox(height: 16),
            const Text('Reason for flagging:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context);
                final result = await CollectionService.flagCollection(collectionId, reasonController.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['success'] == true 
                          ? 'Collection flagged successfully'
                          : result['message'] ?? 'Failed to flag collection'),
                      backgroundColor: result['success'] == true 
                          ? AppTheme.warningColor 
                          : AppTheme.errorColor,
                    ),
                  );
                  if (result['success'] == true) {
                    _loadCollections();
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
            child: const Text('Flag', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Reject Popup
  void _showRejectPopup(BuildContext context, String collectionId, String description) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.close, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Reject Collection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collection: $description'),
            const SizedBox(height: 16),
            const Text('Reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context);
                final result = await CollectionService.rejectCollection(collectionId, reasonController.text);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['success'] == true 
                          ? 'Collection rejected successfully'
                          : result['message'] ?? 'Failed to reject collection'),
                      backgroundColor: result['success'] == true 
                          ? AppTheme.errorColor 
                          : AppTheme.errorColor,
                    ),
                  );
                  if (result['success'] == true) {
                    _loadCollections();
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Approve Collection
  Future<void> _approveCollection(BuildContext context, String collectionId) async {
    final result = await CollectionService.approveCollection(collectionId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['success'] == true 
              ? 'Collection approved successfully'
              : result['message'] ?? 'Failed to approve collection'),
          backgroundColor: result['success'] == true 
              ? AppTheme.secondaryColor 
              : AppTheme.errorColor,
        ),
      );
      if (result['success'] == true) {
        _loadCollections();
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.headingMedium.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildCollectionCard({
    required String mode,
    required String amount,
    required String description,
    required String user,
    required bool showActions,
    required VoidCallback onFlag,
    required VoidCallback onReject,
    required VoidCallback onApprove,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getModeColor(mode).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getModeIcon(mode),
                  size: 14,
                  color: _getModeColor(mode),
                ),
                const SizedBox(width: 6),
                Text(
                  mode,
                  style: AppTheme.bodySmall.copyWith(
                    color: _getModeColor(mode),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Amount
          Text(
            amount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 6),

          // Description
          Text(
            description,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          // User info
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                user,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),

          // Action buttons (only for pending approvals)
          if (showActions) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                  icon: Icons.flag_outlined,
                  label: 'Flag',
                  color: AppTheme.warningColor,
                  onPressed: onFlag,
                ),
                _buildActionButton(
                  icon: Icons.close,
                  label: 'Reject',
                  color: AppTheme.errorColor,
                  onPressed: onReject,
                ),
                _buildActionButton(
                  icon: Icons.check,
                  label: 'Approve',
                  color: AppTheme.secondaryColor,
                  onPressed: onApprove,
                  isPrimary: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollectionsTable(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    final isDesktop = Responsive.isDesktop(context);

    if (_isLoading) {
      return Padding(
        padding: widget.embedInDashboard 
            ? EdgeInsets.symmetric(
                vertical: isMobile ? 12 : isTablet ? 14 : 16, 
                horizontal: isMobile ? 8 : isTablet ? 10 : 12
              )
            : EdgeInsets.all(isMobile ? 24 : isTablet ? 28 : 32),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_collections.isEmpty) {
      return Padding(
        padding: widget.embedInDashboard 
            ? EdgeInsets.symmetric(
                vertical: isMobile ? 6 : isTablet ? 7 : 8, 
                horizontal: isMobile ? 8 : isTablet ? 10 : 12
              )
            : EdgeInsets.symmetric(
                vertical: isMobile ? 12 : isTablet ? 14 : 16, 
                horizontal: isMobile ? 24 : isTablet ? 28 : 32
              ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: widget.embedInDashboard 
                  ? (isMobile ? 28 : isTablet ? 30 : 32)
                  : (isMobile ? 40 : isTablet ? 44 : 48),
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: widget.embedInDashboard ? 4 : (isMobile ? 6 : 8)),
            Text(
              'No collections found',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontSize: widget.embedInDashboard 
                    ? (isMobile ? 11 : isTablet ? 11.5 : 12)
                    : (isMobile ? 13 : isTablet ? 13.5 : 14),
              ),
            ),
          ],
        ),
      );
    }

    // Responsive Column widths
    final double colDate = isMobile ? 90 : isTablet ? 100 : 110;
    final double colTime = isMobile ? 80 : isTablet ? 90 : 100;
    final double colReceiver = isMobile ? 90 : isTablet ? 100 : 110;
    final double colAutoPay = isMobile ? 75 : isTablet ? 82 : 90;
    final double colAmount = isMobile ? 90 : isTablet ? 100 : 110;
    final double colMode = isMobile ? 75 : isTablet ? 82 : 90;
    final double colDescription = isMobile ? 140 : isTablet ? 160 : 180;
    final double colCreatedBy = isMobile ? 90 : isTablet ? 100 : 110;
    final double colStatus = isMobile ? 90 : isTablet ? 100 : 110;
    final double colActions = isMobile ? 120 : isTablet ? 130 : 140;

    return SingleChildScrollView(
      scrollDirection: isMobile ? Axis.horizontal : Axis.vertical,
      child: Column(
        children: [
          // Table Header - No background, no border
          Padding(
            padding: widget.embedInDashboard
                ? EdgeInsets.only(
                    top: 0, 
                    bottom: isMobile ? 6 : isTablet ? 7 : 8, 
                    left: isMobile ? 4 : isTablet ? 5 : 6, 
                    right: isMobile ? 4 : isTablet ? 5 : 6
                  )
                : EdgeInsets.symmetric(
                    vertical: isMobile ? 10 : isTablet ? 11 : 12, 
                    horizontal: isMobile ? 12 : isTablet ? 14 : 16
                  ),
            child: Row(
              children: [
                _buildHeaderCell(context, 'Date', colDate),
                _buildHeaderCell(context, 'Time', colTime),
                _buildHeaderCell(context, 'Receiver', colReceiver),
                _buildHeaderCell(context, 'Auto Pay', colAutoPay),
                _buildHeaderCell(context, 'Amount', colAmount),
                _buildHeaderCell(context, 'Mode', colMode),
                _buildHeaderCell(context, 'Description', colDescription),
                _buildHeaderCell(context, 'Created By', colCreatedBy),
                _buildHeaderCell(context, 'Status', colStatus),
                if (widget.role != 'Staff') _buildHeaderCell(context, 'Actions', colActions),
              ],
            ),
          ),
          
          // Table Body - Non-scrollable, show all rows
          // For Staff, filter to show only their own collections (history only)
          ...(widget.role == 'Staff' 
              ? _collections.where((c) => c['createdBy'] == 'Staff 1').toList()
              : _collections)
              .map((collection) {
            final status = collection['status'] as String;
            final description = collection['description'] as String;
            final showActions = status == 'Pending';

            return Padding(
              padding: widget.embedInDashboard
                  ? EdgeInsets.symmetric(
                      vertical: isMobile ? 6 : isTablet ? 7 : 8, 
                      horizontal: isMobile ? 4 : isTablet ? 5 : 6
                    )
                  : EdgeInsets.symmetric(
                      vertical: isMobile ? 10 : isTablet ? 11 : 12, 
                      horizontal: isMobile ? 12 : isTablet ? 14 : 16
                    ),
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildDataCell(context, collection['date'].toString(), colDate),
                _buildDataCell(context, collection['time'].toString(), colTime),
                _buildDataCell(context, collection['receiver'].toString(), colReceiver),
                SizedBox(
                  width: colAutoPay,
                  child: Center(
                    child: Icon(
                      collection['autoPay'] ? Icons.check_circle : Icons.cancel,
                      color: collection['autoPay'] ? AppTheme.secondaryColor : AppTheme.errorColor,
                      size: isMobile ? 18 : isTablet ? 20 : 22,
                    ),
                  ),
                ),
                SizedBox(
                  width: colAmount,
                  child: Text(
                    collection['amount'].toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: isMobile ? 12 : isTablet ? 13 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                _buildDataCell(context, collection['mode'].toString(), colMode),
                _buildDataCell(context, collection['description'].toString(), colDescription, isDescription: true),
                _buildDataCell(context, collection['createdBy']?.toString() ?? 'N/A', colCreatedBy),
                SizedBox(
                  width: colStatus,
                  child: Center(child: _buildStatusChip(context, status)),
                ),
                if (widget.role != 'Staff')
                  SizedBox(
                    width: colActions,
                    child: showActions
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildActionIconButton(
                                context,
                                Icons.check,
                                AppTheme.secondaryColor,
                                'Approve',
                                () => _approveCollection(context, collection['id'] as String),
                              ),
                              SizedBox(width: isMobile ? 6 : 8),
                              _buildActionIconButton(
                                context,
                                Icons.close,
                                AppTheme.errorColor,
                                'Reject',
                                () => _showRejectPopup(context, collection['id'] as String, description),
                              ),
                              SizedBox(width: isMobile ? 6 : 8),
                              _buildActionIconButton(
                                context,
                                Icons.flag_outlined,
                                AppTheme.warningColor,
                                'Flag',
                                () => _showFlagPopup(context, collection['id'] as String, description),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          );
        }).toList(),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, String text, double width) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    
    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : isTablet ? 10 : 12, 
          vertical: isMobile ? 10 : isTablet ? 12 : 14
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isMobile ? 12 : isTablet ? 13 : 14,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildDataCell(BuildContext context, String text, double width, {bool isDescription = false}) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    
    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : isTablet ? 10 : 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isMobile ? 11 : isTablet ? 12 : 13,
            color: Colors.black87,
          ),
          textAlign: isDescription ? TextAlign.left : TextAlign.center,
          maxLines: isDescription ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildActionIconButton(BuildContext context, IconData icon, Color color, String tooltip, VoidCallback onPressed) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 5 : isTablet ? 5.5 : 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Icon(
            icon,
            size: isMobile ? 16 : isTablet ? 17 : 18,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);
    Color color;
    switch (status) {
      case 'Approved':
        color = AppTheme.secondaryColor;
        break;
      case 'Pending':
        color = AppTheme.warningColor;
        break;
      case 'Rejected':
        color = AppTheme.errorColor;
        break;
      default:
        color = AppTheme.textSecondary;
    }
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : isTablet ? 7 : 8, 
        vertical: isMobile ? 3 : isTablet ? 3.5 : 4
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 10 : isTablet ? 11 : 12,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      height: 32,
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
    );
  }

  Color _getModeColor(String mode) {
    switch (mode) {
      case 'UPI':
        return Colors.purple;
      case 'Cash':
        return Colors.green;
      case 'Bank':
        return Colors.blue;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'UPI':
        return Icons.qr_code;
      case 'Cash':
        return Icons.money;
      case 'Bank':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }
}
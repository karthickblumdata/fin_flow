class SmartApprovalItem {
  final String id;
  final String type; // 'Expenses', 'Transactions', 'Collections'
  final double amount;
  final DateTime date;
  final String status;
  final bool isSystematicEntry;
  final bool isAutoPay;
  final Map<String, dynamic> details;
  final Map<String, dynamic>? metadata;
  final String? systemTransactionId;
  final bool flagged;
  final String? notes;

  SmartApprovalItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.status,
    this.isSystematicEntry = false,
    this.isAutoPay = false,
    required this.details,
    this.metadata,
    this.systemTransactionId,
    this.flagged = false,
    this.notes,
  });

  // Factory constructor to create from API response
  factory SmartApprovalItem.fromCollection(Map<String, dynamic> collection) {
    final paymentMode = collection['paymentModeId'];
    final autoPay = paymentMode is Map ? (paymentMode['autoPay'] ?? false) : false;
    final isSystematicEntry = collection['isSystematicEntry'] ?? false;
    
    return SmartApprovalItem(
      id: collection['_id']?.toString() ?? collection['id']?.toString() ?? '',
      type: 'Collections',
      amount: (collection['amount'] ?? 0).toDouble(),
      date: collection['createdAt'] != null
          ? DateTime.parse(collection['createdAt']).toLocal()
          : DateTime.now(),
      status: collection['status'] ?? 'Pending',
      isSystematicEntry: isSystematicEntry || (autoPay && collection['mode'] != 'Cash'),
      isAutoPay: autoPay,
      systemTransactionId: collection['systemTransactionId']?.toString(),
      flagged: collection['status'] == 'Flagged',
      notes: collection['notes'],
      details: {
        'customerName': collection['customerName'] ?? '',
        'voucherNumber': collection['voucherNumber'] ?? '',
        'mode': collection['mode'] ?? '',
        'paymentModeName': paymentMode is Map ? (paymentMode['modeName'] ?? '') : '',
        'collectedBy': collection['collectedBy'] is Map
            ? (collection['collectedBy']['name'] ?? 'Unknown')
            : 'Unknown',
        'assignedReceiver': collection['assignedReceiver'] is Map
            ? (collection['assignedReceiver']['name'] ?? 'Unknown')
            : 'Unknown',
        'proofUrl': collection['proofUrl'],
      },
      metadata: {
        'collectedById': collection['collectedBy'] is Map
            ? (collection['collectedBy']['_id'] ?? collection['collectedBy']['id'])
            : null,
        'assignedReceiverId': collection['assignedReceiver'] is Map
            ? (collection['assignedReceiver']['_id'] ?? collection['assignedReceiver']['id'])
            : null,
        'paymentModeId': collection['paymentModeId'] is Map
            ? (collection['paymentModeId']['_id'] ?? collection['paymentModeId']['id'])
            : collection['paymentModeId'],
      },
    );
  }

  factory SmartApprovalItem.fromTransaction(Map<String, dynamic> transaction) {
    final isAutoPay = transaction['isAutoPay'] ?? false;
    final isSystemTransaction = transaction['isSystemTransaction'] ?? false;
    
    return SmartApprovalItem(
      id: transaction['_id']?.toString() ?? transaction['id']?.toString() ?? '',
      type: 'Transactions',
      amount: (transaction['amount'] ?? 0).toDouble(),
      date: transaction['createdAt'] != null
          ? DateTime.parse(transaction['createdAt']).toLocal()
          : DateTime.now(),
      status: transaction['status'] ?? 'Pending',
      isSystematicEntry: isSystemTransaction || isAutoPay,
      isAutoPay: isAutoPay,
      flagged: transaction['status'] == 'Flagged',
      notes: transaction['purpose'],
      details: {
        'sender': transaction['sender'] is Map
            ? (transaction['sender']['name'] ?? 'Unknown')
            : 'Unknown',
        'receiver': transaction['receiver'] is Map
            ? (transaction['receiver']['name'] ?? 'Unknown')
            : 'Unknown',
        'purpose': transaction['purpose'] ?? '',
        'mode': transaction['mode'] ?? '',
        'proofUrl': transaction['proofUrl'],
      },
      metadata: {
        'senderId': transaction['sender'] is Map
            ? (transaction['sender']['_id'] ?? transaction['sender']['id'])
            : null,
        'receiverId': transaction['receiver'] is Map
            ? (transaction['receiver']['_id'] ?? transaction['receiver']['id'])
            : null,
        'initiatedBy': transaction['initiatedBy'] is Map
            ? (transaction['initiatedBy']['name'] ?? 'Unknown')
            : 'Unknown',
        'linkedCollectionId': transaction['linkedCollectionId']?.toString(),
      },
    );
  }

  factory SmartApprovalItem.fromExpense(Map<String, dynamic> expense) {
    return SmartApprovalItem(
      id: expense['_id']?.toString() ?? expense['id']?.toString() ?? '',
      type: 'Expenses',
      amount: (expense['amount'] ?? 0).toDouble(),
      date: expense['createdAt'] != null
          ? DateTime.parse(expense['createdAt']).toLocal()
          : DateTime.now(),
      status: expense['status'] ?? 'Pending',
      isSystematicEntry: false, // Expenses don't have auto pay
      isAutoPay: false,
      flagged: expense['status'] == 'Flagged',
      notes: expense['description'] ?? expense['notes'],
      details: {
        'expenseType': expense['expenseType'] is Map
            ? (expense['expenseType']['name'] ?? 'Unknown')
            : expense['expenseType'] ?? 'Unknown',
        'category': expense['category'] ?? '',
        'user': expense['userId'] is Map
            ? (expense['userId']['name'] ?? 'Unknown')
            : 'Unknown',
        'mode': expense['mode'] ?? '',
        'proofUrl': expense['proofUrl'],
      },
      metadata: {
        'userId': expense['userId'] is Map
            ? (expense['userId']['_id'] ?? expense['userId']['id'])
            : null,
        'createdBy': expense['createdBy'] is Map
            ? (expense['createdBy']['name'] ?? 'Unknown')
            : 'Unknown',
        'expenseTypeId': expense['expenseType'] is Map
            ? (expense['expenseType']['_id'] ?? expense['expenseType']['id'])
            : null,
      },
    );
  }

  String get title {
    switch (type) {
      case 'Collections':
        return details['customerName'] ?? 'Collection';
      case 'Transactions':
        return details['purpose'] ?? 'Transaction';
      case 'Expenses':
        return details['expenseType'] ?? 'Expense';
      default:
        return 'Approval Item';
    }
  }

  String get subtitle {
    switch (type) {
      case 'Collections':
        return 'Voucher: ${details['voucherNumber'] ?? 'N/A'}';
      case 'Transactions':
        return '${details['sender']} → ${details['receiver']}';
      case 'Expenses':
        return details['category'] ?? 'Expense';
      default:
        return '';
    }
  }

  String get formattedAmount {
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}';
  }
}


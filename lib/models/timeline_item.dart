import 'package:flutter/material.dart';

enum TimelineItemType {
  info,
  warning,
  flagged,
  success,
  error,
  bot,
}

enum TimelineItemStatus {
  sending,
  waiting,
  completed,
  failed,
  reviewRequired,
}

class TimelineItem {
  final String id;
  final TimelineItemType type;
  final String message;
  final DateTime timestamp;
  final String? title;
  final TimelineItemStatus? status;
  final String? statusText;
  final List<String>? checklistItems;
  final String? substatusText;
  final Color? substatusColor;
  final TimelineAttachment? attachment;

  TimelineItem({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    this.title,
    this.status,
    this.statusText,
    this.checklistItems,
    this.substatusText,
    this.substatusColor,
    this.attachment,
  });
}

class TimelineAttachment {
  final String filename;
  final String? fileSize;
  final String? fileType;
  final VoidCallback? onDownload;

  TimelineAttachment({
    required this.filename,
    this.fileSize,
    this.fileType,
    this.onDownload,
  });
}


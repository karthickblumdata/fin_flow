import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/timeline_item.dart';
import '../theme/app_theme.dart';

class TimelineItemWidget extends StatelessWidget {
  final TimelineItem item;
  final bool isMobile;
  final bool isTablet;

  const TimelineItemWidget({
    super.key,
    required this.item,
    required this.isMobile,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple Icon (No Circle Background)
          _buildSimpleIcon(),
          const SizedBox(width: 12),
          // Right Content Area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Timestamp Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title (if exists)
                          if (item.title != null) ...[
                            Text(
                              item.title!,
                              style: AppTheme.bodyMedium.copyWith(
                                fontSize: isMobile ? 14 : 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          // Message
                          Text(
                            item.message,
                            style: AppTheme.bodyMedium.copyWith(
                              fontSize: isMobile ? 13 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatTimestamp(item.timestamp),
                      style: AppTheme.bodySmall.copyWith(
                        fontSize: isMobile ? 11 : 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                // Status Text (if exists)
                if (item.statusText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.statusText!,
                    style: AppTheme.bodySmall.copyWith(
                      fontSize: isMobile ? 12 : 13,
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                // Substatus Text (Simple - No Badge)
                if (item.substatusText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.substatusText!,
                    style: AppTheme.bodySmall.copyWith(
                      color: item.substatusColor ?? AppTheme.warningColor,
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 12 : 13,
                    ),
                  ),
                ],
                // Checklist Items (for flagged entries)
                if (item.checklistItems != null && item.checklistItems!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...item.checklistItems!.map((checklistItem) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_box_outline_blank,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                checklistItem,
                                style: AppTheme.bodySmall.copyWith(
                                  fontSize: isMobile ? 12 : 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                // File Attachment (Simple)
                if (item.attachment != null) ...[
                  const SizedBox(height: 12),
                  _buildSimpleAttachment(item.attachment!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleIcon() {
    Color iconColor;
    IconData iconData;

    switch (item.type) {
      case TimelineItemType.info:
        iconColor = AppTheme.accentBlue;
        iconData = Icons.info_outline;
        break;
      case TimelineItemType.warning:
        iconColor = AppTheme.warningColor;
        iconData = Icons.warning_amber_outlined;
        break;
      case TimelineItemType.flagged:
        iconColor = AppTheme.errorColor;
        iconData = Icons.flag_outlined;
        break;
      case TimelineItemType.success:
        iconColor = AppTheme.secondaryColor;
        iconData = Icons.check_circle_outline;
        break;
      case TimelineItemType.error:
        iconColor = AppTheme.errorColor;
        iconData = Icons.error_outline;
        break;
      case TimelineItemType.bot:
        iconColor = AppTheme.textSecondary;
        iconData = Icons.smart_toy_outlined;
        break;
    }

    return Icon(
      iconData,
      color: iconColor,
      size: isMobile ? 20 : 22,
    );
  }

  Widget _buildSimpleAttachment(TimelineAttachment attachment) {
    return Row(
      children: [
        Icon(
          Icons.insert_drive_file_outlined,
          size: 16,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attachment.filename,
                style: AppTheme.bodySmall.copyWith(
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (attachment.fileSize != null) ...[
                const SizedBox(height: 2),
                Text(
                  attachment.fileSize!,
                  style: AppTheme.bodySmall.copyWith(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (attachment.onDownload != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: attachment.onDownload,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.download_outlined,
                size: 16,
                color: AppTheme.accentBlue,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${DateFormat('h:mm a').format(timestamp)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE, h:mm a').format(timestamp);
    } else {
      return DateFormat('dd MMM, h:mm a').format(timestamp);
    }
  }
}


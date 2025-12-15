import 'package:flutter/material.dart';
import '../models/permission_node.dart';
import '../theme/app_theme.dart';

class HierarchicalCheckbox extends StatefulWidget {
  final PermissionNode node;
  final Function(PermissionNode) onChanged;
  final int level;
  final bool isMobile;

  const HierarchicalCheckbox({
    super.key,
    required this.node,
    required this.onChanged,
    this.level = 0,
    this.isMobile = false,
  });

  @override
  State<HierarchicalCheckbox> createState() => _HierarchicalCheckboxState();
}

class _HierarchicalCheckboxState extends State<HierarchicalCheckbox> {
  late PermissionNode _currentNode;

  @override
  void initState() {
    super.initState();
    _currentNode = widget.node;
  }

  /// Get icon for action permission labels
  IconData? _getActionIcon(String label) {
    switch (label) {
      case 'Add':
      case 'Add/Create':
        return Icons.add_circle_outline;
      case 'Edit':
        return Icons.edit_outlined;
      case 'Delete':
      case 'Remove':
        return Icons.delete_outline;
      case 'Reject':
        return Icons.close;
      case 'Flag':
        return Icons.flag_outlined;
      case 'Approve':
        return Icons.check_circle_outline;
      case 'Export As':
        return Icons.download_outlined;
      case 'View':
        return Icons.visibility_outlined;
      default:
        return null;
    }
  }

  /// Check if this is an action permission (has no children and matches action labels)
  bool _isActionPermission() {
    if (_currentNode.children.isNotEmpty) return false;
    return _getActionIcon(_currentNode.label) != null;
  }

  @override
  void didUpdateWidget(HierarchicalCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      // Update current node and ensure selection state is recalculated
      _currentNode = widget.node;
      // Update selection state to ensure indeterminate state is correct
      _currentNode.updateSelectionState();
    }
  }

  void _handleCheckboxChanged(bool? value) {
    setState(() {
      _currentNode = _updateNodeSelection(_currentNode, value ?? false);
      _currentNode.updateSelectionState();
    });
    widget.onChanged(_currentNode);
  }

  PermissionNode _updateNodeSelection(PermissionNode node, bool selected) {
    // Update this node
    final updatedNode = node.copyWith(isSelected: selected);

    // Update all children recursively
    final updatedChildren = node.children.map((child) {
      final updatedChild = _updateNodeSelection(child, selected);
      // Update selection state for each child to ensure proper indeterminate state
      updatedChild.updateSelectionState();
      return updatedChild;
    }).toList();

    final result = updatedNode.copyWith(children: updatedChildren);
    // Update selection state after all children are updated
    result.updateSelectionState();
    return result;
  }

  void _toggleExpansion() {
    setState(() {
      // Only toggle this node's expansion state
      // Children maintain their own independent expansion states
      _currentNode = _currentNode.copyWith(
        isExpanded: !_currentNode.isExpanded,
      );
      // Ensure children remain in their own expansion state (don't auto-expand)
      // Children are already created with isExpanded: false, so no need to modify them
    });
  }

  bool? _getCheckboxValue() {
    if (_currentNode.isIndeterminate == true) {
      return null; // Indeterminate state
    }
    return _currentNode.isSelected;
  }

  @override
  Widget build(BuildContext context) {
    final hasChildren = _currentNode.children.isNotEmpty;
    final indent = widget.level * 24.0;
    final fontSize = widget.isMobile ? 13.0 : 14.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            // Row click behavior: Toggle expand/collapse for parent nodes
            // For action nodes (leaf nodes), toggle checkbox
            if (hasChildren) {
              // Toggle this node's expansion - children will be shown but remain in their own state
              _toggleExpansion();
            } else {
              // For leaf nodes, clicking the row toggles the checkbox
              _handleCheckboxChanged(!_currentNode.isSelected);
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: widget.isMobile ? 6 : 8,
              horizontal: 8,
            ),
            child: Row(
              children: [
                SizedBox(width: indent),
                // Expand/Collapse icon for parent nodes
                // This icon provides independent control over expansion
                if (hasChildren)
                  GestureDetector(
                    onTap: () {
                      // Expand/collapse icon click: Toggle this node's expansion only
                      // GestureDetector naturally consumes the tap, preventing parent InkWell from firing
                      _toggleExpansion();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: _currentNode.isExpanded
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                      child: Icon(
                        _currentNode.isExpanded
                            ? Icons.remove
                            : Icons.add,
                        size: 18,
                        color: _currentNode.isExpanded
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 26),
                const SizedBox(width: 8),
                // Checkbox
                // Checkbox click: Selects/deselects node (and all children if parent)
                // Flutter's Checkbox onChanged naturally prevents parent InkWell from firing
                Checkbox(
                  value: _getCheckboxValue(),
                  onChanged: _currentNode.isLocked ? null : (value) {
                    // Ensure state is updated properly
                    _handleCheckboxChanged(value);
                  },
                  tristate: true,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                // Lock icon for locked permissions
                if (_currentNode.isLocked)
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                if (_currentNode.isLocked)
                  const SizedBox(width: 4),
                // Label or Icon
                Expanded(
                  child: _isActionPermission()
                      ? Row(
                          children: [
                            Icon(
                              _getActionIcon(_currentNode.label)!,
                              size: fontSize + 2,
                              color: _currentNode.isLocked 
                                  ? AppTheme.textSecondary 
                                  : AppTheme.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentNode.label,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.normal,
                                      color: _currentNode.isLocked 
                                          ? AppTheme.textSecondary 
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (_currentNode.description != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      _currentNode.description!,
                                      style: TextStyle(
                                        fontSize: fontSize - 2,
                                        color: AppTheme.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentNode.label,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: hasChildren
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: _currentNode.isLocked 
                                    ? AppTheme.textSecondary 
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            if (_currentNode.description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _currentNode.description!,
                                style: TextStyle(
                                  fontSize: fontSize - 2,
                                  color: AppTheme.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        // Children - rendered when parent is expanded
        // Each child maintains its own independent expansion state
        if (_currentNode.isExpanded && hasChildren)
          ..._currentNode.children.asMap().entries.map((entry) {
            final childIndex = entry.key;
            final child = entry.value;
            // Ensure child maintains its own expansion state
            // Child is already created with isExpanded: false by default
            // Each child will control its own expansion independently
            return HierarchicalCheckbox(
              key: ValueKey('${child.id}_$childIndex'),
              node: child, // Child's isExpanded state is independent
              onChanged: (updatedChild) {
                setState(() {
                  // Use index from map entry instead of indexOf for reliability
                  final updatedChildren = List<PermissionNode>.from(
                    _currentNode.children,
                  );
                  updatedChildren[childIndex] = updatedChild;
                  // Update the updated child's selection state first
                  updatedChild.updateSelectionState();
                  _currentNode = _currentNode.copyWith(
                    children: updatedChildren,
                  );
                  // Then update parent's selection state based on all children
                  _currentNode.updateSelectionState();
                });
                // Notify parent widget of the change
                widget.onChanged(_currentNode);
              },
              level: widget.level + 1,
              isMobile: widget.isMobile,
            );
          }).toList(),
      ],
    );
  }
}


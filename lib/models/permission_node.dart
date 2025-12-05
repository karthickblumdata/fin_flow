class PermissionNode {
  final String id;
  final String label;
  final String? description;
  final List<PermissionNode> children;
  bool isSelected;
  bool isExpanded;
  bool? isIndeterminate; // For parent nodes with partial selection

  PermissionNode({
    required this.id,
    required this.label,
    this.description,
    this.children = const [],
    this.isSelected = false,
    this.isExpanded = false,
    this.isIndeterminate,
  });

  PermissionNode copyWith({
    String? id,
    String? label,
    String? description,
    List<PermissionNode>? children,
    bool? isSelected,
    bool? isExpanded,
    bool? isIndeterminate,
  }) {
    return PermissionNode(
      id: id ?? this.id,
      label: label ?? this.label,
      description: description ?? this.description,
      children: children ?? this.children,
      isSelected: isSelected ?? this.isSelected,
      isExpanded: isExpanded ?? this.isExpanded,
      isIndeterminate: isIndeterminate ?? this.isIndeterminate,
    );
  }

  // Get all selected permission IDs (including children)
  List<String> getSelectedPermissionIds() {
    final List<String> selected = [];
    if (isSelected) {
      selected.add(id);
    }
    for (final child in children) {
      selected.addAll(child.getSelectedPermissionIds());
    }
    return selected;
  }

  // Check if this node has any selected children
  bool hasSelectedChildren() {
    if (children.isEmpty) return false;
    return children.any((child) => child.isSelected || child.hasSelectedChildren());
  }

  // Get all permission IDs in this tree (for building complete list)
  List<String> getAllPermissionIds() {
    final List<String> all = [id];
    for (final child in children) {
      all.addAll(child.getAllPermissionIds());
    }
    return all;
  }

  // Update selection state based on children
  void updateSelectionState() {
    if (children.isEmpty) {
      isIndeterminate = null;
      return;
    }

    // First, update all children's states recursively
    for (final child in children) {
      child.updateSelectionState();
    }

    final selectedCount = children.where((c) => c.isSelected).length;
    final indeterminateCount = children.where((c) => c.isIndeterminate == true).length;
    final totalCount = children.length;

    if (selectedCount == totalCount && indeterminateCount == 0) {
      // All children selected
      isSelected = true;
      isIndeterminate = false;
    } else if (selectedCount == 0 && indeterminateCount == 0) {
      // No children selected
      isSelected = false;
      isIndeterminate = false;
    } else {
      // Some children selected (partial selection)
      isSelected = false;
      isIndeterminate = true;
    }
  }
}


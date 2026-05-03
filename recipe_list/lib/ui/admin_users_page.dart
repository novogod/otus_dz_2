import 'package:flutter/material.dart';

import '../auth/admin_session.dart';
import '../i18n.dart';
import 'app_theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    required this.adminLogin,
    required this.adminPassword,
  });

  final String adminLogin;
  final String adminPassword;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<AdminRecipeUser> _users = const [];
  final Set<String> _selectedIds = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      final users = await fetchRecipeAdminUsers(
        adminLogin: widget.adminLogin,
        adminPassword: widget.adminPassword,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _selectedIds.removeWhere((id) => !_users.any((u) => u.id == id));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _allSelected =>
      _users.isNotEmpty && _selectedIds.length == _users.length;

  void _toggleSelectAll(bool value) {
    setState(() {
      if (value) {
        _selectedIds
          ..clear()
          ..addAll(_users.map((u) => u.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _deleteOne(AdminRecipeUser user) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.adminDeleteUserTitle),
        content: Text(s.adminDeleteUserPrompt(user.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.dismiss),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.adminDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await deleteRecipeAdminUser(
        adminLogin: widget.adminLogin,
        adminPassword: widget.adminPassword,
        id: user.id,
      );
      if (!mounted) return;
      setState(() {
        _users = _users.where((u) => u.id != user.id).toList(growable: false);
        _selectedIds.remove(user.id);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkDeleteSelected() async {
    final s = S.of(context);
    if (_selectedIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.adminDeleteSelectedUsersTitle),
        content: Text(s.adminDeleteSelectedUsersPrompt(_selectedIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.dismiss),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.adminDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final ids = _selectedIds.toList(growable: false);
    setState(() => _busy = true);
    try {
      await bulkDeleteRecipeAdminUsers(
        adminLogin: widget.adminLogin,
        adminPassword: widget.adminPassword,
        ids: ids,
      );
      if (!mounted) return;
      setState(() {
        _users = _users
            .where((u) => !ids.contains(u.id))
            .toList(growable: false);
        _selectedIds.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editUser(AdminRecipeUser user) async {
    final s = S.of(context);
    final nameController = TextEditingController(text: user.fullName);
    String selectedLang = user.preferredLanguage;
    bool active = user.isActive;

    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: Text(s.adminEditUserTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.adminEditAccountFields,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: s.adminFullName),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLang,
                    decoration: InputDecoration(
                      labelText: s.adminPreferredLanguage,
                    ),
                    items: AppLang.values
                        .map(
                          (l) => DropdownMenuItem<String>(
                            value: l.name,
                            child: Text('${l.label} (${l.name})'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (v) {
                      if (v == null) return;
                      setLocalState(() => selectedLang = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.adminActive),
                    value: active,
                    onChanged: (v) => setLocalState(() => active = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(s.dismiss),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(s.addRecipeSubmit),
              ),
            ],
          ),
        );
      },
    );

    if (save != true) return;
    setState(() => _busy = true);
    try {
      final updated = await updateRecipeAdminUser(
        adminLogin: widget.adminLogin,
        adminPassword: widget.adminPassword,
        id: user.id,
        fullName: nameController.text.trim(),
        preferredLanguage: selectedLang,
        status: active ? 'active' : 'inactive',
      );
      if (!mounted || updated == null) return;
      setState(() {
        _users = _users
            .map((u) => u.id == user.id ? updated : u)
            .toList(growable: false);
      });
    } finally {
      nameController.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.adminUsersTitle),
        actions: [
          IconButton(
            tooltip: s.retry,
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Checkbox(
                    value: _allSelected,
                    onChanged: _busy
                        ? null
                        : (v) => _toggleSelectAll(v ?? false),
                  ),
                  Text(s.adminSelectAll),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _busy || _selectedIds.isEmpty
                        ? null
                        : _bulkDeleteSelected,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      s.adminDeleteSelectedButton(_selectedIds.length),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _busy && _users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                  ? Center(child: Text(s.adminNoUsersFound))
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final selected = _selectedIds.contains(user.id);
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: selected,
                                  onChanged: _busy
                                      ? null
                                      : (v) {
                                          setState(() {
                                            if (v == true) {
                                              _selectedIds.add(user.id);
                                            } else {
                                              _selectedIds.remove(user.id);
                                            }
                                          });
                                        },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.email,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(user.fullName),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        s.adminLangAndStatus(
                                          user.preferredLanguage,
                                          user.status,
                                        ),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: s.adminEditAction,
                                  onPressed: _busy
                                      ? null
                                      : () => _editUser(user),
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  tooltip: s.adminDeleteAction,
                                  onPressed: _busy
                                      ? null
                                      : () => _deleteOne(user),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemCount: _users.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

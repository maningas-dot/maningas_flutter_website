import 'package:flutter/material.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import 'support_center_mock_data.dart';

class SupportCenterPage extends StatefulWidget {
  const SupportCenterPage({this.tickets, super.key});

  final List<DemoSupportTicket>? tickets;

  @override
  State<SupportCenterPage> createState() => _SupportCenterPageState();
}

class _SupportCenterPageState extends State<SupportCenterPage> {
  late final List<DemoSupportTicket> _tickets;
  String? _selectedTicketId;
  int _nextTicketNumber = 103;
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tickets = List.of(widget.tickets ?? SupportCenterMockData.tickets);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  DemoSupportTicket? get _selectedTicket {
    for (final ticket in _tickets) {
      if (ticket.id == _selectedTicketId) return ticket;
    }
    return null;
  }

  bool get _mobile => MediaQuery.sizeOf(context).width <= 640;

  void _selectTicket(DemoSupportTicket ticket) {
    setState(() => _selectedTicketId = ticket.id);
  }

  Future<void> _showNewTicketDialog() async {
    final ticket = await showDialog<_NewTicketDraft>(
      context: context,
      builder: (context) => const _NewTicketDialog(),
    );
    if (ticket == null || !mounted) return;

    final now = DateTime.now();
    final id = 'DEMO-${_nextTicketNumber++}';
    final created = DemoSupportTicket(
      id: id,
      subject: ticket.subject,
      category: ticket.category,
      status: 'Open',
      priority: ticket.priority,
      updatedAt: now,
      messages: [
        DemoSupportMessage(
          body: ticket.description,
          senderName: 'You',
          sentAt: now,
          isMine: true,
        ),
      ],
    );
    setState(() {
      _tickets.insert(0, created);
      _selectedTicketId = id;
    });
    _showDemoNotice(
      'Demo ticket preview added locally. Nothing was submitted.',
    );
  }

  void _sendMessage() {
    final ticket = _selectedTicket;
    final text = _messageController.text.trim();
    if (ticket == null || text.isEmpty || !_canSendMessage(ticket)) return;

    final updated = DemoSupportTicket(
      id: ticket.id,
      subject: ticket.subject,
      category: ticket.category,
      status: ticket.status,
      priority: ticket.priority,
      updatedAt: DateTime.now(),
      messages: [
        ...ticket.messages,
        DemoSupportMessage(
          body: text,
          senderName: 'You',
          sentAt: DateTime.now(),
          isMine: true,
        ),
      ],
    );
    setState(() {
      final index = _tickets.indexWhere((item) => item.id == ticket.id);
      _tickets[index] = updated;
      _messageController.clear();
    });
    _showDemoNotice('Message preview added locally. Nothing was sent.');
  }

  void _showDemoNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width <= PatientPortalBreakpoints.mobile;
    final pagePadding = width <= PatientPortalBreakpoints.mobileNavigation
        ? (compact ? 17.0 : 22.0)
        : width <= PatientPortalBreakpoints.tablet
        ? 25.0
        : 32.0;
    final mobile = _mobile;
    final chatOpen = mobile && _selectedTicket != null;
    final cardHeight = mobile
        ? (MediaQuery.sizeOf(context).height * 0.68).clamp(400.0, 580.0)
        : 620.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: PatientPortalBreakpoints.contentMaxWidth,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageHeader(onNewTicket: _showNewTicketDialog),
              const SizedBox(height: 18),
              const _PrivacyNotice(),
              const SizedBox(height: 20),
              if (mobile)
                SizedBox(
                  height: cardHeight,
                  child: chatOpen
                      ? _ConversationPanel(
                          ticket: _selectedTicket,
                          mobile: true,
                          messageController: _messageController,
                          onBack: () =>
                              setState(() => _selectedTicketId = null),
                          onSend: _sendMessage,
                        )
                      : _InboxPanel(
                          tickets: _tickets,
                          selectedTicketId: _selectedTicketId,
                          mobile: true,
                          onSelect: _selectTicket,
                          onRefresh: () => _showDemoNotice(
                            'Demo ticket list refreshed. No server data was requested.',
                          ),
                          onCancel: _showCancelPreview,
                        ),
                )
              else
                SizedBox(
                  height: cardHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: width <= PatientPortalBreakpoints.tablet
                            ? 280
                            : 320,
                        child: _InboxPanel(
                          tickets: _tickets,
                          selectedTicketId: _selectedTicketId,
                          mobile: false,
                          onSelect: _selectTicket,
                          onRefresh: () => _showDemoNotice(
                            'Demo ticket list refreshed. No server data was requested.',
                          ),
                          onCancel: _showCancelPreview,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _ConversationPanel(
                          ticket: _selectedTicket,
                          mobile: false,
                          messageController: _messageController,
                          onBack: () {},
                          onSend: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelPreview(DemoSupportTicket ticket) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.info_outline),
        title: const Text('Demo action only'),
        content: Text(
          'Cancel Ticket is available for open tickets in the original portal. '
          'This demo does not connect cancellation for ${ticket.id}; no ticket '
          'was changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onNewTicket});

  final VoidCallback onNewTicket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Support Center',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage your support requests and communicate with our clinic team.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: secondary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onNewTicket,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New Ticket'),
        ),
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'For your privacy, do not share passwords or sensitive payment '
        'information in support messages.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: secondary,
          height: 1.55,
        ),
      ),
    );
  }
}

class _InboxPanel extends StatelessWidget {
  const _InboxPanel({
    required this.tickets,
    required this.selectedTicketId,
    required this.mobile,
    required this.onSelect,
    required this.onRefresh,
    required this.onCancel,
  });

  final List<DemoSupportTicket> tickets;
  final String? selectedTicketId;
  final bool mobile;
  final ValueChanged<DemoSupportTicket> onSelect;
  final VoidCallback onRefresh;
  final ValueChanged<DemoSupportTicket> onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Support Tickets',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Track your requests and view their current status.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onRefresh, child: const Text('Refresh')),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: const _DemoDataBadge(),
          ),
          Expanded(
            child: tickets.isEmpty
                ? const _EmptyInbox()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: tickets.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      return _TicketListItem(
                        ticket: ticket,
                        selected: ticket.id == selectedTicketId,
                        mobile: mobile,
                        onSelect: () => onSelect(ticket),
                        onCancel: () => onCancel(ticket),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TicketListItem extends StatelessWidget {
  const _TicketListItem({
    required this.ticket,
    required this.selected,
    required this.mobile,
    required this.onSelect,
    required this.onCancel,
  });

  final DemoSupportTicket ticket;
  final bool selected;
  final bool mobile;
  final VoidCallback onSelect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOpen = ticket.status.toLowerCase() == 'open';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onSelect,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: mobile ? 260 : 190,
                        ),
                        child: Text(
                          ticket.subject.isEmpty
                              ? 'Ticket #${ticket.id}'
                              : ticket.subject,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _StatusBadge(status: ticket.status),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _TicketMeta(text: '#${ticket.id}'),
                      _TicketMeta(text: ticket.category),
                      _TicketMeta(
                        text: _formatDateTime(context, ticket.updatedAt),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isOpen)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              child: const Text('Cancel Ticket'),
            ),
          ),
      ],
    );
  }
}

class _TicketMeta extends StatelessWidget {
  const _TicketMeta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context)
        .extension<PatientPortalTextColors>()!
        .secondary;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: secondary, fontSize: 11),
    );
  }
}

class _ConversationPanel extends StatelessWidget {
  const _ConversationPanel({
    required this.ticket,
    required this.mobile,
    required this.messageController,
    required this.onBack,
    required this.onSend,
  });

  final DemoSupportTicket? ticket;
  final bool mobile;
  final TextEditingController messageController;
  final VoidCallback onBack;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    final canSend = ticket != null && _canSendMessage(ticket!);
    final readOnly = ticket != null && _isReadOnly(ticket!.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 12 : 20,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            child: Row(
              children: [
                if (mobile) ...[
                  OutlinedButton(
                    onPressed: onBack,
                    child: const Text('← Back to Tickets'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ticket == null
                            ? 'Support Chat'
                            : '${ticket!.subject} · Ticket #${ticket!.id}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _conversationSubtitle(ticket),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ticket == null
                ? const _EmptyConversation()
                : ticket!.messages.isEmpty
                ? _NoMessages(canSend: canSend, status: ticket!.status)
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: ticket!.messages.length,
                    itemBuilder: (context, index) =>
                        _MessageBubble(message: ticket!.messages[index]),
                  ),
          ),
          if (ticket != null && readOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: theme.scaffoldBackgroundColor,
              child: Text(
                'This conversation is read-only.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ),
          if (ticket != null && !canSend && !readOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: theme.scaffoldBackgroundColor,
              child: Text(
                ticket!.status.toLowerCase() == 'open'
                    ? 'Waiting for Super Admin to accept your ticket.'
                    : 'Messaging is currently unavailable.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ),
          _MessageComposer(
            controller: messageController,
            enabled: canSend,
            onSend: onSend,
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                labelText: 'Type your support message',
                counterText: '',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: enabled ? (_) => onSend() : null,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: enabled ? onSend : null,
              child: const Text('Send'),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.lock_outline,
            size: 14,
            color: theme.disabledColor.withValues(alpha: 0.65),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final DemoSupportMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    final primary = theme.colorScheme.primary;
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.62,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: message.isMine ? primary : theme.scaffoldBackgroundColor,
          border: message.isMine
              ? null
              : Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(message.isMine ? 12 : 4),
            bottomRight: Radius.circular(message.isMine ? 4 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: message.isMine ? Colors.white : null,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${message.senderName} · ${_formatDateTime(context, message.sentAt)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: message.isMine
                    ? Colors.white.withValues(alpha: 0.82)
                    : secondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context)
        .extension<PatientPortalTextColors>()!
        .secondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          'You have no support tickets yet. Create a new ticket to get started.',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondary, height: 1.7),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context)
        .extension<PatientPortalTextColors>()!
        .secondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          'No Conversation Selected\nSelect a support ticket to view its messages.',
          textAlign: TextAlign.center,
          style: TextStyle(color: secondary, height: 1.7),
        ),
      ),
    );
  }
}

class _NoMessages extends StatelessWidget {
  const _NoMessages({required this.canSend, required this.status});

  final bool canSend;
  final String status;

  @override
  Widget build(BuildContext context) {
    final statusLower = status.toLowerCase();
    final message = canSend
        ? 'No messages yet. You can send a message below.'
        : statusLower == 'open'
        ? 'No messages yet. You can reply after Super Admin accepts your ticket.'
        : _isReadOnly(status)
        ? 'No messages yet. This conversation is read-only.'
        : 'No messages yet. Messaging is currently unavailable.';
    final secondary = Theme.of(context)
        .extension<PatientPortalTextColors>()!
        .secondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: secondary, height: 1.7),
        ),
      ),
    );
  }
}

class _DemoDataBadge extends StatelessWidget {
  const _DemoDataBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'DEMO DATA',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _NewTicketDraft {
  const _NewTicketDraft({
    required this.category,
    required this.subject,
    required this.priority,
    required this.description,
  });

  final String category;
  final String subject;
  final String priority;
  final String description;
}

class _NewTicketDialog extends StatefulWidget {
  const _NewTicketDialog();

  @override
  State<_NewTicketDialog> createState() => _NewTicketDialogState();
}

class _NewTicketDialogState extends State<_NewTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _category;
  String _priority = 'Medium';

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _NewTicketDraft(
        category: _category!,
        subject: _subjectController.text.trim(),
        priority: _priority,
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.extension<PatientPortalTextColors>()!.secondary;
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: (viewport.height * 0.88).clamp(360, 760),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create a Support Ticket',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Provide the details below so our team can assist you.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondary,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close form',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outline),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        hint: const Text('Select a category'),
                        items: SupportCenterMockData.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'Select a category' : null,
                        onChanged: (value) => setState(() => _category = value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _subjectController,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'Subject',
                          hintText: 'Enter a short title for your concern',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a subject'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        items: SupportCenterMockData.priorities
                            .map(
                              (priority) => DropdownMenuItem(
                                value: priority,
                                child: Text(priority),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _priority = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLength: 4000,
                        minLines: 4,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe your concern in detail...',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          alignLabelWithHint: true,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a description'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outline),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Wrap(
                alignment: WrapAlignment.end,
                runAlignment: WrapAlignment.end,
                spacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(82, 42),
                      foregroundColor: secondary,
                      side: BorderSide(color: theme.colorScheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(132, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text('Submit Ticket'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _canSendMessage(DemoSupportTicket ticket) {
  final status = ticket.status.toLowerCase();
  return status == 'in progress' || status == 'pending';
}

bool _isReadOnly(String status) {
  final normalized = status.toLowerCase();
  return normalized == 'resolved' || normalized == 'closed';
}

String _conversationSubtitle(DemoSupportTicket? ticket) {
  if (ticket == null) return 'Select a ticket to view your conversation.';
  if (_canSendMessage(ticket)) {
    return '${ticket.status} · ${ticket.priority} priority';
  }
  if (ticket.status.toLowerCase() == 'open') {
    return 'Waiting for Super Admin to accept your ticket.';
  }
  if (_isReadOnly(ticket.status)) {
    return '${ticket.status} · This conversation is read-only.';
  }
  return 'Messaging is currently unavailable.';
}

String _formatDateTime(BuildContext context, DateTime date) {
  final local = date.toLocal();
  final time = TimeOfDay.fromDateTime(local).format(context);
  return '${MaterialLocalizations.of(context).formatMediumDate(local)} · $time';
}

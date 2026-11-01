import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/contact_messagerie.dart';
import '../../models/message.dart';
import '../../services/alerte_message_service.dart';
import '../../services/messagerie_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/rafraichissement_periodique.dart';
import '../bandeau_demonstration.dart';
import 'conversation_page.dart';

class ConversationsPage extends StatefulWidget {
  /// Le menu du rôle connecté : il remplace la flèche de retour.
  final Widget? menu;

  const ConversationsPage({super.key, this.menu});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage>
    with RafraichissementPeriodique {
  final _service = MessagerieService.instance;
  List<Message> _messages = [];
  List<ContactMessagerie> _contacts = [];
  bool _loading = true;
  bool _messagesDemo = false;
  bool _contactsDemo = false;
  Object? _erreurChargement;
  StreamSubscription<void>? _nouveauxMessages;

  bool get _estDemonstration => _messagesDemo || _contactsDemo;

  @override
  void initState() {
    super.initState();
    _loadData();
    _nouveauxMessages = alerteMessages.nouveauxMessages.listen(
      (_) => rechargerEnSilence(),
    );
  }

  @override
  void dispose() {
    _nouveauxMessages?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final messages = await _service.fetchMessages();
      final contacts = await _service.fetchContacts();
      if (!mounted) return;
      setState(() {
        _messages = messages.donnees;
        _contacts = contacts.donnees;
        _messagesDemo = messages.estDemonstration;
        _contactsDemo = contacts.estDemonstration;
        _erreurChargement = null;
        _loading = false;
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreurChargement = erreur;
        _loading = false;
      });
    }
  }

  @override
  Future<void> rechargerEnSilence() async {
    try {
      final messages = await _service.fetchMessages();
      final contacts = await _service.fetchContacts();
      if (!mounted ||
          (messages.estDemonstration && !_messagesDemo) ||
          (contacts.estDemonstration && !_contactsDemo)) {
        return;
      }
      setState(() {
        _messages = messages.donnees;
        _contacts = contacts.donnees;
        _messagesDemo = messages.estDemonstration;
        _contactsDemo = contacts.estDemonstration;
        _erreurChargement = null;
      });
    } catch (_) {}
  }

  Future<void> _openContactPicker() async {
    try {
      final contacts = await _service.fetchContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts.donnees;
        _contactsDemo = contacts.estDemonstration;
      });
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _ContactPicker(
          contacts: _contacts,
          onSelect: (contact) {
            Navigator.pop(context);
            _openConversation(contact);
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contacts indisponibles : $error'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<_ConversationView> get _conversations {
    final contactsById = {for (final contact in _contacts) contact.id: contact};
    final grouped = <String, List<Message>>{};

    for (final message in _messages) {
      final otherId = contactsById.containsKey(message.expediteur)
          ? message.expediteur
          : contactsById.containsKey(message.destinataire)
          ? message.destinataire
          : null;
      if (otherId == null) continue;
      grouped.putIfAbsent(otherId, () => []).add(message);
    }

    final conversations = grouped.entries.map((entry) {
      final messages = List<Message>.from(entry.value)
        ..sort((a, b) => _date(b).compareTo(_date(a)));
      final contact = contactsById[entry.key]!;
      final unread = messages
          .where((m) => m.expediteur == contact.id && !m.lu)
          .length;
      return _ConversationView(
        contact: contact,
        messages: messages,
        latest: messages.first,
        unreadCount: unread,
      );
    }).toList();

    conversations.sort((a, b) => _date(b.latest).compareTo(_date(a.latest)));
    return conversations;
  }

  DateTime _date(Message message) =>
      DateTime.tryParse(message.dateEnvoi)?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  void _openConversation(ContactMessagerie contact) {
    final messages = _messages
        .where(
          (m) => m.expediteur == contact.id || m.destinataire == contact.id,
        )
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationPage(
          contact: contact,
          initialMessages: messages,
          initialMessagesEstDemonstration: _messagesDemo,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _conversations;
    return Scaffold(
      backgroundColor: kBg,
      drawer: widget.menu,
      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Text(
          'Messagerie',
          style: GoogleFonts.domine(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        iconTheme: const IconThemeData(color: kDark),
        actions: [
          IconButton(
            onPressed: _openContactPicker,
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Nouvelle conversation',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : VueResultatService(
              estDemonstration: _estDemonstration,
              erreur: _erreurChargement,
              onReessayer: _loadData,
              onRefresh: rechargerEnSilence,
              couleurRafraichissement: kGreen,
              child: Column(
                children: [
                  Container(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                  Container(
                    color: kBg,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Row(
                      children: [
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh, size: 17),
                          label: const Text('Actualiser'),
                          style: TextButton.styleFrom(
                            foregroundColor: kGreen,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: conversations.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: const _EmptyConversations(),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: conversations.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                            itemBuilder: (_, index) => _ConversationTile(
                              conversation: conversations[index],
                              dateLabel: _formatPreviewDate(
                                _date(conversations[index].latest),
                              ),
                              onTap: () => _openConversation(
                                conversations[index].contact,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openContactPicker,
        backgroundColor: const Color.fromARGB(255, 197, 206, 201),
        foregroundColor: kDark,
        elevation: 0,
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }

  String _formatPreviewDate(DateTime date) {
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
}

class _ConversationView {
  final ContactMessagerie contact;
  final List<Message> messages;
  final Message latest;
  final int unreadCount;

  const _ConversationView({
    required this.contact,
    required this.messages,
    required this.latest,
    required this.unreadCount,
  });
}

class _ConversationTile extends StatelessWidget {
  final _ConversationView conversation;
  final String dateLabel;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final contact = conversation.contact;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: kGreen.withValues(alpha: 0.12),
                child: Text(
                  _initiales(contact),
                  style: const TextStyle(
                    color: kGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact.nomComplet,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: kDark,
                              fontSize: 14,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            color: kOlive,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.roleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.latest.contenu,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread ? kDark : kOlive,
                              fontSize: 13,
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          _UnreadBadge(count: conversation.unreadCount),
                        ],
                      ],
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

  String _initiales(ContactMessagerie contact) {
    final prenom = contact.prenom.trim();
    final nom = contact.nom.trim();
    final first = prenom.isNotEmpty ? prenom[0] : '';
    final second = nom.isNotEmpty ? nom[0] : '';
    final value = '$first$second';
    return value.isEmpty ? '?' : value.toUpperCase();
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kRed,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ContactPicker extends StatelessWidget {
  final List<ContactMessagerie> contacts;
  final ValueChanged<ContactMessagerie> onSelect;

  const _ContactPicker({required this.contacts, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nouvelle conversation',
              style: GoogleFonts.domine(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
            const SizedBox(height: 12),
            if (contacts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Aucun contact disponible.',
                    style: TextStyle(color: kOlive),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                  itemBuilder: (_, index) {
                    final contact = contacts[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: kGreen.withValues(alpha: 0.12),
                        child: Text(
                          _initiales(contact),
                          style: const TextStyle(
                            color: kGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        contact.nomComplet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(contact.roleLabel),
                      onTap: () => onSelect(contact),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _initiales(ContactMessagerie contact) {
    final prenom = contact.prenom.trim();
    final nom = contact.nom.trim();
    final value =
        '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}';
    return value.isEmpty ? '?' : value.toUpperCase();
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, color: kOlive, size: 36),
            SizedBox(height: 12),
            Text(
              'Aucune conversation pour le moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kDark,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Utilisez le bouton de création pour démarrer un échange.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kOlive, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

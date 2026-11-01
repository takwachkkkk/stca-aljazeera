import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../services/alerte_message_service.dart';
import '../../services/messagerie_service.dart';
import '../../session_expiration.dart';
import '../../theme/app_colors.dart';
import 'conversation_page.dart';

/// Ouvre la conversation avec l'expéditeur d'une alerte.
Future<void> ouvrirConversationAvec(String expediteurId) async {
  if (alerteMessages.conversationOuverte == expediteurId) return;
  try {
    final contacts = await MessagerieService.instance.fetchContacts();
    if (contacts.estDemonstration) return;
    final contact = contacts.donnees.firstWhere((c) => c.id == expediteurId);
    await sessionNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ConversationPage(contact: contact)),
    );
  } catch (_) {
    // Contact indisponible : le message reste visible dans la messagerie.
  }
}

/// Affiche le bandeau d'un nouveau message au-dessus de toutes les pages.
class AlerteMessageHote extends StatefulWidget {
  final Widget child;
  final AlerteMessageService? service;
  final ValueChanged<String> onOuvrir;

  const AlerteMessageHote({
    super.key,
    required this.child,
    this.service,
    this.onOuvrir = ouvrirConversationAvec,
  });

  @override
  State<AlerteMessageHote> createState() => _AlerteMessageHoteState();
}

class _AlerteMessageHoteState extends State<AlerteMessageHote> {
  static const _dureeAffichage = Duration(seconds: 6);

  late final AlerteMessageService _service = widget.service ?? alerteMessages;
  Message? _message;
  bool _visible = false;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _service.alerte.addListener(_surAlerte);
    _service.surTouche = widget.onOuvrir;
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _service.alerte.removeListener(_surAlerte);
    _service.surTouche = null;
    super.dispose();
  }

  void _surAlerte() {
    final message = _service.alerte.value;
    _minuteur?.cancel();
    if (message == null) {
      setState(() => _visible = false);
      return;
    }
    setState(() {
      _message = message;
      _visible = true;
    });
    _minuteur = Timer(_dureeAffichage, _masquer);
  }

  void _masquer() {
    if (mounted) setState(() => _visible = false);
  }

  void _ouvrir(Message message) {
    _minuteur?.cancel();
    setState(() => _message = null);
    widget.onOuvrir(message.expediteur);
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final media = MediaQuery.of(context);
    final duree = media.disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Stack(
      children: [
        widget.child,
        if (message != null)
          Positioned(
            left: 12,
            right: 12,
            top: media.padding.top + 8,
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedSlide(
                duration: duree,
                curve: Curves.easeOutCubic,
                offset: _visible ? Offset.zero : const Offset(0, -1.4),
                child: AnimatedOpacity(
                  duration: duree,
                  opacity: _visible ? 1 : 0,
                  child: Dismissible(
                    key: ValueKey(message.id),
                    direction: DismissDirection.up,
                    onDismissed: (_) {
                      _minuteur?.cancel();
                      setState(() => _message = null);
                    },
                    child: _BandeauMessage(
                      message: message,
                      onTap: () => _ouvrir(message),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BandeauMessage extends StatelessWidget {
  final Message message;
  final VoidCallback onTap;

  const _BandeauMessage({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      button: true,
      label: 'Nouveau message de ${message.expediteurNom}',
      child: Material(
        color: Colors.white,
        elevation: 6,
        shadowColor: kDark.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: kGreen.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: kGreen.withValues(alpha: 0.12),
                  child: Text(
                    _initiales(message.expediteurNom),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.expediteurNom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message.apercu,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kOlive, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initiales(String nom) {
    final mots = nom.trim().split(RegExp(r'\s+')).where((m) => m.isNotEmpty);
    final initiales = mots.take(2).map((m) => m[0]).join();
    return initiales.isEmpty ? '?' : initiales.toUpperCase();
  }
}

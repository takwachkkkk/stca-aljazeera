import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../1_ceo/echantillons/echantillons_ceo_page.dart';
import '../../../2_collecteur/mes_echantillons/mes_echantillons_page.dart';
import '../../../5_chef_degustateur/gestion_echantillons/gestion_echantillons_page.dart'
    as chef_echantillons;
import '../../api_client.dart';
import '../../models/contact_messagerie.dart';
import '../../models/echantillon.dart';
import '../../models/enums.dart';
import '../../models/message.dart';
import '../../services/alerte_message_service.dart';
import '../../services/auth_service.dart';
import '../../services/gestion_echantillons_service.dart';
import '../../services/messagerie_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/rafraichissement_periodique.dart';
import '../empty_state.dart';

class ConversationPage extends StatefulWidget {
  final ContactMessagerie contact;
  final List<Message>? initialMessages;
  final bool initialMessagesEstDemonstration;

  const ConversationPage({
    super.key,
    required this.contact,
    this.initialMessages,
    this.initialMessagesEstDemonstration = false,
  });

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage>
    with RafraichissementPeriodique {
  static const _demoActionMessage =
      'Action indisponible avec les données de démonstration. Réessayez lorsque le serveur répond.';

  final _service = MessagerieService.instance;
  final _echantillonService = GestionEchantillonsService(
    uniquementRecusPhysiquement: false,
  );
  final _picker = ImagePicker();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _estDemonstration = false;
  Uint8List? _photoBytes;
  String? _photoFilename;
  _EchantillonMessageRef? _echantillonJoint;
  RoleUtilisateur? _roleUtilisateur;
  String? _errorMessage;
  String? _conversationPrecedente;
  StreamSubscription<void>? _nouveauxMessages;

  @override
  void initState() {
    super.initState();
    _conversationPrecedente = alerteMessages.conversationOuverte;
    alerteMessages.conversationOuverte = widget.contact.id;
    _nouveauxMessages = alerteMessages.nouveauxMessages.listen(
      (_) => rechargerEnSilence(),
    );
    _loadCurrentUser();
    final initial = widget.initialMessages;
    if (initial != null) {
      _messages = _sorted(initial);
      _estDemonstration = widget.initialMessagesEstDemonstration;
      _loading = false;
      _markUnreadAsRead();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else {
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _nouveauxMessages?.cancel();
    alerteMessages.conversationOuverte = _conversationPrecedente;
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final resultat = await _service.fetchMessages();
      if (!mounted) return;
      setState(() {
        _messages = _sorted(
          resultat.donnees
              .where(
                (m) =>
                    m.expediteur == widget.contact.id ||
                    m.destinataire == widget.contact.id,
              )
              .toList(),
        );
        _estDemonstration = resultat.estDemonstration;
        _loading = false;
      });
      _markUnreadAsRead();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Impossible de charger cette conversation.';
      });
    }
  }

  @override
  Future<void> rechargerEnSilence() async {
    final etaitEnBas = _estProcheDuBas;
    try {
      final resultat = await _service.fetchMessages();
      if (!mounted || (resultat.estDemonstration && !_estDemonstration)) {
        return;
      }
      setState(() {
        _messages = _sorted(
          resultat.donnees
              .where(
                (m) =>
                    m.expediteur == widget.contact.id ||
                    m.destinataire == widget.contact.id,
              )
              .toList(),
        );
        _estDemonstration = resultat.estDemonstration;
        _errorMessage = null;
      });
      _markUnreadAsRead();
      if (etaitEnBas) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {}
  }

  bool get _estProcheDuBas {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels < 80;
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await authService.currentUser();
      if (!mounted) return;
      setState(() => _roleUtilisateur = user.role);
    } catch (_) {
      if (!mounted) return;
      setState(() => _roleUtilisateur = null);
    }
  }

  List<Message> _sorted(List<Message> source) =>
      List<Message>.from(source)..sort((a, b) => _date(a).compareTo(_date(b)));

  DateTime _date(Message message) =>
      DateTime.tryParse(message.dateEnvoi)?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _markUnreadAsRead() async {
    if (_estDemonstration) return;
    final unread = _messages
        .where((m) => m.expediteur == widget.contact.id && !m.lu)
        .toList();
    for (final message in unread) {
      try {
        await _service.markAsRead(message.id);
        if (!mounted) return;
        setState(() {
          message.lu = true;
          message.luLe = DateTime.now().toIso8601String();
        });
      } catch (_) {
        // Reading state will be refreshed from the server next time.
      }
    }
  }

  Future<void> _send() async {
    final contenu = _controller.text.trim();
    final bytes = _photoBytes;
    if (_sending) return;
    if (contenu.isEmpty && bytes == null) {
      _showError('Ajoutez un texte ou une photo avant d\'envoyer.');
      return;
    }
    if (_estDemonstration) {
      _showError(_demoActionMessage);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _errorMessage = null;
    });
    try {
      final sent = await _service.sendMessage(
        widget.contact.id,
        contenu,
        bytes: bytes,
        filename: _photoFilename,
        echantillonId: _echantillonJoint?.id,
      );
      if (!mounted) return;
      setState(() {
        _messages = _sorted([..._messages, sent]);
        _controller.clear();
        _photoBytes = null;
        _photoFilename = null;
        _echantillonJoint = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      if (!mounted) return;
      _showError('Message non envoyé : $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 2000,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoFilename = file.name;
    });
  }

  void _choosePhotoSource() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('photo-source-gallery'),
              leading: const Icon(Icons.photo_library_outlined, color: kGreen),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              key: const ValueKey('photo-source-camera'),
              leading: const Icon(Icons.photo_camera_outlined, color: kGreen),
              title: const Text('Appareil photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              key: const ValueKey('photo-source-cancel'),
              leading: const Icon(Icons.close, color: kDark),
              title: const Text('Annuler'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseEchantillon() async {
    final selected = await showModalBottomSheet<_EchantillonMessageRef>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EchantillonPicker(service: _echantillonService),
    );
    if (selected == null || !mounted) return;
    setState(() => _echantillonJoint = selected);
  }

  Future<void> _editMessage(Message message) async {
    if (_estDemonstration) {
      _showError(_demoActionMessage);
      return;
    }
    final controller = TextEditingController(text: message.contenu);
    final nouveauContenu = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Votre message',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 197, 206, 201),
              foregroundColor: kDark,
              elevation: 0,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nouveauContenu == null) return;
    if (nouveauContenu.isEmpty) {
      _showError('Le message modifié ne peut pas être vide.');
      return;
    }
    try {
      final updated = await _service.editMessage(message.id, nouveauContenu);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((item) => item.id == updated.id);
        if (index != -1) _messages[index] = updated;
      });
    } catch (error) {
      if (mounted) _showError('Modification impossible : $error');
    }
  }

  Future<void> _deleteMessage(Message message) async {
    if (_estDemonstration) {
      _showError(_demoActionMessage);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce message ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteMessage(message.id);
      if (!mounted) return;
      setState(() => _messages.removeWhere((item) => item.id == message.id));
    } catch (error) {
      if (mounted) _showError('Suppression impossible : $error');
    }
  }

  void _openImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ImageFullScreenPage(imageUrl: url)),
    );
  }

  void _ouvrirEchantillon(String id) {
    final role = _roleUtilisateur;
    if (role == null) {
      _showError('Impossible d\'ouvrir l\'échantillon : profil indisponible.');
      return;
    }

    Widget page;
    switch (role) {
      case RoleUtilisateur.direction:
        page = EchantillonsCeoPage(referenceInitiale: id);
        break;
      case RoleUtilisateur.collecteur:
        page = MesEchantillonsPage(referenceInitiale: id);
        break;
      case RoleUtilisateur.chefDegustation:
        page = chef_echantillons.GestionEchantillonsPage(referenceInitiale: id);
        break;
      case RoleUtilisateur.degustateur:
      case RoleUtilisateur.laboratoire:
      case RoleUtilisateur.serviceAchat:
        _showError(
          'Navigation vers cet échantillon indisponible pour ce rôle.',
        );
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kHeaderBg,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 65,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.contact.nomComplet,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.domine(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
            Text(
              widget.contact.roleLabel,
              style: const TextStyle(
                fontSize: 12,
                color: kOlive,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: kDark),
      ),
      body: Column(
        children: [
          Container(height: 1, color: Colors.black.withValues(alpha: 0.06)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kGreen))
                : _errorMessage != null
                ? _ConversationError(
                    message: _errorMessage!,
                    onRetry: _loadMessages,
                  )
                : _messages.isEmpty
                ? const _EmptyThread()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, index) {
                      final message = _messages[index];
                      final isSent = message.destinataire == widget.contact.id;
                      return _MessageBubble(
                        message: message,
                        isSent: isSent,
                        dateLabel: _formatDate(_date(message)),
                        onEdit: isSent ? () => _editMessage(message) : null,
                        onDelete: isSent ? () => _deleteMessage(message) : null,
                        onOpenImage: _openImage,
                        onOuvrirEchantillon: _ouvrirEchantillon,
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _controller,
            sending: _sending,
            photoBytes: _photoBytes,
            photoFilename: _photoFilename,
            echantillon: _echantillonJoint,
            onChoosePhoto: _choosePhotoSource,
            onRemovePhoto: () => setState(() {
              _photoBytes = null;
              _photoFilename = null;
            }),
            onChooseEchantillon: _chooseEchantillon,
            onRemoveEchantillon: () => setState(() => _echantillonJoint = null),
            onSend: _send,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    if (sameDay) return '$hour:$minute';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/$hour:$minute';
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isSent;
  final String dateLabel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<String> onOpenImage;
  final ValueChanged<String> onOuvrirEchantillon;

  const _MessageBubble({
    required this.message,
    required this.isSent,
    required this.dateLabel,
    required this.onOpenImage,
    required this.onOuvrirEchantillon,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = _absolutePhotoUrl(message.photoUrl);
    final hasPhoto = photoUrl != null;
    final hasReference =
        message.echantillonId != null && message.echantillonNumero != null;
    final hasText = message.contenu.trim().isNotEmpty;
    final timeColor = isSent ? Colors.white.withValues(alpha: 0.75) : kOlive;

    return GestureDetector(
      onLongPress: isSent ? () => _showActions(context) : null,
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
            decoration: BoxDecoration(
              color: isSent ? kGreen : kChipBgGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: isSent
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (hasReference) ...[
                  _MessageEchantillonChip(
                    isSent: isSent,
                    numero: message.echantillonNumero!,
                    referenceBouteille: message.echantillonReferenceBouteille,
                    fournisseur: message.echantillonFournisseurNom,
                    onTap: () =>
                        onOuvrirEchantillon(message.echantillonNumero!),
                  ),
                  if (hasText || hasPhoto) const SizedBox(height: 7),
                ],
                if (hasPhoto) ...[
                  _MessagePhoto(
                    imageUrl: photoUrl,
                    isSent: isSent,
                    onTap: () => onOpenImage(photoUrl),
                  ),
                  if (hasText) const SizedBox(height: 8),
                ],
                if (hasText)
                  Text(
                    message.contenu,
                    style: TextStyle(
                      color: isSent ? Colors.white : kDark,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.modifie) ...[
                      Text(
                        'modifié',
                        style: TextStyle(
                          color: timeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: TextStyle(color: timeColor, fontSize: 11),
                      ),
                    ],
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: timeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _absolutePhotoUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) return raw;
    return Uri.parse(apiClient.baseUrl).resolve(raw).toString();
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: kGreen),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(sheetContext);
                onEdit?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: kRed),
              title: const Text('Supprimer'),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final Uint8List? photoBytes;
  final String? photoFilename;
  final _EchantillonMessageRef? echantillon;
  final VoidCallback onChoosePhoto;
  final VoidCallback onRemovePhoto;
  final VoidCallback onChooseEchantillon;
  final VoidCallback onRemoveEchantillon;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.photoBytes,
    required this.photoFilename,
    required this.echantillon,
    required this.onChoosePhoto,
    required this.onRemovePhoto,
    required this.onChooseEchantillon,
    required this.onRemoveEchantillon,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photoBytes != null || echantillon != null) ...[
              _ComposerAttachments(
                photoBytes: photoBytes,
                photoFilename: photoFilename,
                echantillon: echantillon,
                onRemovePhoto: onRemovePhoto,
                onRemoveEchantillon: onRemoveEchantillon,
              ),
              const SizedBox(height: 9),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ComposerIconButton(
                  icon: Icons.add_a_photo_outlined,
                  tooltip: photoBytes == null
                      ? 'Ajouter une photo'
                      : 'Remplacer la photo',
                  onPressed: sending ? null : onChoosePhoto,
                ),
                const SizedBox(width: 6),
                _ComposerIconButton(
                  icon: Icons.inventory_2_outlined,
                  tooltip: 'Référencer un échantillon',
                  onPressed: sending ? null : onChooseEchantillon,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Votre message',
                      filled: true,
                      fillColor: const Color(0xFFF7FAF8),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                        borderSide: BorderSide(color: kGreen, width: 1.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: sending ? null : onSend,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color.fromARGB(255, 197, 206, 201),
                      foregroundColor: kDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: kDark,
                            ),
                          )
                        : const Icon(Icons.send_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessagePhoto extends StatelessWidget {
  final String imageUrl;
  final bool isSent;
  final VoidCallback onTap;

  const _MessagePhoto({
    required this.imageUrl,
    required this.isSent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: isSent
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.04),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            height: 170,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Icon(
                Icons.broken_image_outlined,
                color: isSent ? Colors.white70 : kOlive,
                size: 34,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageEchantillonChip extends StatelessWidget {
  final bool isSent;
  final String numero;
  final String? referenceBouteille;
  final String? fournisseur;
  final VoidCallback onTap;

  const _MessageEchantillonChip({
    required this.isSent,
    required this.numero,
    required this.referenceBouteille,
    required this.fournisseur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSent ? Colors.white.withValues(alpha: 0.15) : Colors.white;
    final fg = isSent ? Colors.white : kDark;
    final secondary = isSent ? Colors.white.withValues(alpha: 0.78) : kOlive;
    final reference = referenceBouteille?.trim() ?? '';
    final supplier = fournisseur?.trim() ?? '';
    final title = reference.isNotEmpty ? reference : numero;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSent
                  ? Colors.white.withValues(alpha: 0.2)
                  : kGreen.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, color: fg, size: 17),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (supplier.isNotEmpty)
                      Text(
                        supplier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (reference.isNotEmpty)
                      Text(
                        numero,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
}

class _ComposerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 44,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, size: 20),
        color: kGreen,
        disabledColor: Colors.grey.shade400,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF7FAF8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _ComposerAttachments extends StatelessWidget {
  final Uint8List? photoBytes;
  final String? photoFilename;
  final _EchantillonMessageRef? echantillon;
  final VoidCallback onRemovePhoto;
  final VoidCallback onRemoveEchantillon;

  const _ComposerAttachments({
    required this.photoBytes,
    required this.photoFilename,
    required this.echantillon,
    required this.onRemovePhoto,
    required this.onRemoveEchantillon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (photoBytes != null)
          _ComposerAttachmentCard(
            icon: Icons.photo_camera_back_outlined,
            title: photoFilename ?? 'photo.jpg',
            onRemove: onRemovePhoto,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                photoBytes!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          ),
        if (photoBytes != null && echantillon != null)
          const SizedBox(height: 7),
        if (echantillon != null)
          _ComposerAttachmentCard(
            icon: Icons.inventory_2_outlined,
            title: echantillon!.titre,
            subtitle: echantillon!.fournisseurLieu.isNotEmpty
                ? echantillon!.fournisseurLieu
                : echantillon!.numero,
            onRemove: onRemoveEchantillon,
          ),
      ],
    );
  }
}

class _ComposerAttachmentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback onRemove;

  const _ComposerAttachmentCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.leading,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = subtitle?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGreen.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          leading ??
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: kGreen, size: 21),
              ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (secondary.isNotEmpty)
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kOlive,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Retirer',
            icon: const Icon(Icons.close, size: 18),
            color: kOlive,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// The "Citer une bouteille" sheet, exposed so tests can open it directly.
@visibleForTesting
Widget choixBouteillePourTest({required GestionEchantillonsService service}) =>
    _EchantillonPicker(service: service);

class _EchantillonPicker extends StatefulWidget {
  final GestionEchantillonsService service;

  const _EchantillonPicker({required this.service});

  @override
  State<_EchantillonPicker> createState() => _EchantillonPickerState();
}

class _EchantillonPickerState extends State<_EchantillonPicker> {
  final _searchController = TextEditingController();
  List<_EchantillonMessageRef> _items = [];
  bool _loading = true;
  String _query = '';
  Object? _error;
  Timer? _debounce;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load([String query = '']) async {
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resultat = await widget.service.fetchEchantillons(
        recherche: query,
        limite: 15,
      );
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _items = resultat.donnees
            .map(_EchantillonMessageRef.fromEchantillon)
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _onQueryChanged(String value) {
    final query = value.trim();
    setState(() => _query = query);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _load(query));
  }

  void _clearQuery() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    const topPadding = 16.0;
    const bottomPadding = 18.0;
    const topMargin = 8.0;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final safeTop = media.padding.top;
    final availableHeight = math.max(
      0.0,
      media.size.height -
          safeTop -
          keyboard -
          topPadding -
          bottomPadding -
          topMargin,
    );
    final height = math.min(media.size.height * 0.72, availableHeight);
    final items = _items;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          topPadding,
          16,
          bottomPadding + keyboard,
        ),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Citer une bouteille',
                style: GoogleFonts.domine(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Référence, fournisseur, variété, citerne, lieu...',
                  prefixIcon: const Icon(Icons.search, color: kOlive),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearQuery,
                          icon: const Icon(Icons.close, size: 18),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF7FAF8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Les 15 plus récentes. Ajoutez un mot pour affiner.',
                style: TextStyle(color: kOlive, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: kGreen),
                      )
                    : _error != null
                    ? _PickerError(onRetry: _load)
                    : items.isEmpty
                    ? EmptyState(
                        message: 'Aucune bouteille ne correspond.',
                        systemeNeuf: _query.isEmpty,
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.inventory_2_outlined,
                              color: kGreen,
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.titre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kDark,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (item.fournisseurLieu.isNotEmpty)
                                  Text(
                                    item.fournisseurLieu,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: kDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.detailsBouteille.isNotEmpty)
                                  Text(item.detailsBouteille),
                                Text(
                                  item.detailsSuivi,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            isThreeLine:
                                item.fournisseurLieu.isNotEmpty ||
                                item.detailsBouteille.isNotEmpty,
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerError extends StatelessWidget {
  final VoidCallback onRetry;

  const _PickerError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Réessayer'),
        style: OutlinedButton.styleFrom(foregroundColor: kGreen),
      ),
    );
  }
}

class _EchantillonMessageRef {
  final String id;
  final String numero;
  final String referenceBouteille;
  final String fournisseur;
  final String gouvernorat;
  final String delegation;
  final String? numCiterne;
  final String? quantiteEstimee;
  final String? variete;
  final String dateAjout;
  final String statut;

  const _EchantillonMessageRef({
    required this.id,
    required this.numero,
    required this.referenceBouteille,
    required this.fournisseur,
    required this.gouvernorat,
    required this.delegation,
    required this.numCiterne,
    required this.quantiteEstimee,
    required this.variete,
    required this.dateAjout,
    required this.statut,
  });

  factory _EchantillonMessageRef.fromEchantillon(Echantillon echantillon) =>
      _EchantillonMessageRef(
        id: echantillon.id,
        numero: echantillon.numero,
        referenceBouteille: echantillon.referenceBouteille,
        fournisseur:
            echantillon.fournisseurNom ?? echantillon.fournisseurTexte ?? '',
        gouvernorat: echantillon.gouvernorat,
        delegation: echantillon.delegation ?? '',
        numCiterne: echantillon.numCiterne,
        quantiteEstimee: echantillon.quantiteEstimee,
        variete: echantillon.variete,
        dateAjout: echantillon.dateAjout,
        statut: echantillon.statutCollecteur.label,
      );

  String get titre {
    final reference = referenceBouteille.trim();
    return reference.isNotEmpty ? reference : numero;
  }

  String get fournisseurLieu {
    final name = fournisseur.trim();
    if (name.isEmpty) return '';
    final region = gouvernorat.trim();
    final localite = delegation.trim();
    if (region.isEmpty) return name;
    if (localite.isEmpty) return '$name — $region';
    return '$name — $region ($localite)';
  }

  String get detailsBouteille {
    final parts = [
      if (_present(numCiterne)) 'Citerne ${numCiterne!.trim()}',
      if (_present(quantiteEstimee)) quantiteEstimee!.trim(),
      if (_present(variete)) variete!.trim(),
    ];
    return parts.join(' · ');
  }

  String get detailsSuivi {
    final date = _dateCourte(dateAjout);
    final parts = [numero, if (date.isNotEmpty) date, statut];
    return parts.join(' · ');
  }

  static bool _present(String? value) => value?.trim().isNotEmpty == true;

  static String _dateCourte(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String get subtitle {
    final parts = [
      referenceBouteille,
      if (fournisseur.trim().isNotEmpty) fournisseur,
    ];
    return parts.join(' · ');
  }

  bool matches(String query) =>
      id.toLowerCase().contains(query) ||
      numero.toLowerCase().contains(query) ||
      referenceBouteille.toLowerCase().contains(query) ||
      fournisseur.toLowerCase().contains(query);
}

class _ImageFullScreenPage extends StatelessWidget {
  final String imageUrl;

  const _ImageFullScreenPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 42,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Aucun message avec ce contact pour le moment.',
          textAlign: TextAlign.center,
          style: TextStyle(color: kOlive, fontSize: 14),
        ),
      ),
    );
  }
}

class _ConversationError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ConversationError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: kRed, size: 34),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
              style: OutlinedButton.styleFrom(foregroundColor: kGreen),
            ),
          ],
        ),
      ),
    );
  }
}

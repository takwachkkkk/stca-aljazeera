import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;

import '../models/enums.dart';
import '../models/message.dart';
import 'messagerie_service.dart';

/// Surveille les messages reçus par l'utilisateur connecté, pour tous les rôles
/// qui ont la messagerie. Appli ouverte : son + bandeau. Appli en arrière-plan :
/// notification du téléphone avec le même son. Le serveur ne renvoie que les
/// messages adressés à l'utilisateur connecté.
class AlerteMessageService {
  AlerteMessageService({
    Future<List<Message>> Function()? chargerNonLus,
    Future<void> Function()? jouerSon,
    Future<void> Function(Message message)? notifierTelephone,
    bool Function()? appliVisible,
  }) : _chargerNonLus =
           chargerNonLus ?? MessagerieService.instance.fetchDerniersNonLus,
       _jouerSon = jouerSon ?? _jouerSonMessage,
       _notifierTelephone = notifierTelephone ?? _afficherNotification,
       _appliVisible = appliVisible ?? _appliAuPremierPlan;

  static const intervalle = Duration(seconds: 15);
  static const _rolesAvecMessagerie = {
    RoleUtilisateur.direction,
    RoleUtilisateur.collecteur,
    RoleUtilisateur.chefDegustation,
  };

  final Future<List<Message>> Function() _chargerNonLus;
  final Future<void> Function() _jouerSon;
  final Future<void> Function(Message message) _notifierTelephone;
  final bool Function() _appliVisible;

  /// Le message à montrer dans le bandeau.
  final ValueNotifier<Message?> alerte = ValueNotifier<Message?>(null);
  final _nouveauxMessages = StreamController<void>.broadcast();

  /// Le contact dont la conversation est affichée : pas d'alerte pour lui.
  String? conversationOuverte;

  /// Appelé quand on touche la notification du téléphone.
  ValueChanged<String>? surTouche;

  Timer? _minuteur;
  final _connus = <String>{};
  bool _referencePrise = false;
  bool _enCours = false;
  int _session = 0;

  /// Prévient les pages ouvertes qu'elles peuvent se recharger.
  Stream<void> get nouveauxMessages => _nouveauxMessages.stream;

  void demarrer(RoleUtilisateur role) {
    arreter();
    if (!_rolesAvecMessagerie.contains(role)) return;
    _minuteur = Timer.periodic(intervalle, (_) => verifier());
    unawaited(_preparerNotifications());
    unawaited(verifier());
  }

  /// Oublie tout : le compte suivant ne doit rien hériter de celui-ci.
  void arreter() {
    _session++;
    _minuteur?.cancel();
    _minuteur = null;
    _connus.clear();
    _referencePrise = false;
    _enCours = false;
    conversationOuverte = null;
    alerte.value = null;
  }

  @visibleForTesting
  Future<void> verifier() async {
    if (_enCours) return;
    final session = _session;
    _enCours = true;
    try {
      final messages = await _chargerNonLus();
      if (session != _session) return;
      final nouveaux = messages.where((m) => !_connus.contains(m.id)).toList();
      _connus.addAll(messages.map((m) => m.id));
      // Ce qui était déjà là à la connexion se voit sur le badge : pas de son.
      final premiereVerification = !_referencePrise;
      _referencePrise = true;
      if (!premiereVerification && nouveaux.isNotEmpty) {
        await _signaler(nouveaux.first);
      }
    } catch (_) {
      // Serveur injoignable : on réessaiera à la prochaine vérification.
    } finally {
      if (session == _session) _enCours = false;
    }
  }

  Future<void> _signaler(Message message) async {
    _nouveauxMessages.add(null);
    if (!_appliVisible()) {
      await _notifierTelephone(message);
      return;
    }
    if (message.expediteur == conversationOuverte) return;
    alerte.value = message;
    await _jouerSon();
  }

  Future<void> _preparerNotifications() async {
    if (!_telephone || _notificationsPretes) return;
    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (reponse) {
          final expediteur = reponse.payload;
          if (expediteur != null) surTouche?.call(expediteur);
        },
      );
      _notificationsPretes = true;
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Sans notification du téléphone, le bandeau et le son restent actifs.
    }
  }
}

final alerteMessages = AlerteMessageService();

final _notifications = FlutterLocalNotificationsPlugin();
bool _notificationsPretes = false;
AudioPlayer? _lecteur;

bool get _telephone =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool _appliAuPremierPlan() {
  if (kIsWeb) return true;
  final etat = WidgetsBinding.instance.lifecycleState;
  return etat == null || etat == AppLifecycleState.resumed;
}

Future<void> _jouerSonMessage() async {
  try {
    var lecteur = _lecteur;
    if (lecteur == null) {
      lecteur = AudioPlayer();
      if (_telephone) {
        // Volume des notifications, sans couper la musique en cours.
        await lecteur.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.notification,
              audioFocus: AndroidAudioFocus.none,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: const {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
      }
      _lecteur = lecteur;
    }
    await lecteur.stop();
    await lecteur.play(AssetSource('sons/message.wav'));
  } catch (_) {
    // Le navigateur peut refuser le son : le bandeau reste affiché.
  }
}

Future<void> _afficherNotification(Message message) async {
  if (!_notificationsPretes) return;
  try {
    await _notifications.show(
      // Une seule notification par personne : la dernière remplace la précédente.
      id: message.expediteur.hashCode & 0x7fffffff,
      title: message.expediteurNom,
      body: message.apercu,
      payload: message.expediteur,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages',
          'Messages',
          channelDescription: 'Nouveaux messages reçus dans la messagerie',
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound('message'),
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
    );
  } catch (_) {
    // Une notification refusée ne doit pas arrêter la surveillance.
  }
}

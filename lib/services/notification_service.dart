import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/colis.dart';
import '../models/notification_item.dart';
import 'database_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final DatabaseService _dbService = DatabaseService();
  final FlutterLocalNotificationsPlugin _localNotifPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isPluginInitialized = false;
  List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.estLu).length;

  Future<void> init() async {
    await _initLocalNotifications();
    await actualiserDepuisBd();
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux) {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const darwinSettings = DarwinInitializationSettings();
        const initSettings = InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        );

        await _localNotifPlugin.initialize(settings: initSettings);
        _isPluginInitialized = true;

        if (Platform.isAndroid) {
          final androidImplementation = _localNotifPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
          await androidImplementation?.requestNotificationsPermission();
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Init locale ignorée (environnement de test ou bureau): $e');
    }
  }

  Future<void> actualiserDepuisBd() async {
    try {
      _notifications = await _dbService.getNotifications();
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationService] Erreur lecture notifications SQLite: $e');
    }
  }

  /// Déclenche une notification de manière strictement idempotente
  /// Clé composite : `${colis.id}_${nouveauStatut.name}`
  Future<bool> notifierChangementStatut({
    required Colis colis,
    required StatutColis ancienStatut,
    required StatutColis nouveauStatut,
    String? note,
  }) async {
    // Si le statut n'a pas réellement changé, ignorer
    if (ancienStatut == nouveauStatut) return false;

    final notifId = '${colis.id}_${nouveauStatut.name}';
    String titre;
    String message;
    String type;
    String priorite;

    switch (nouveauStatut) {
      case StatutColis.enregistre:
        titre = 'Colis enregistré';
        message = 'Le colis n° ${colis.id} a été enregistré à l\'agence ${colis.agenceDepart}.';
        type = 'statut';
        priorite = 'normale';
        break;

      case StatutColis.chargeBus:
        titre = 'Colis embarqué';
        message = 'Colis n° ${colis.id} chargé dans le car ${colis.matriculeBus ?? 'en partance'}.';
        type = 'transit';
        priorite = 'normale';
        break;

      case StatutColis.enTransit:
        titre = 'Colis en transit';
        message = 'Colis n° ${colis.id} en route vers ${colis.villeArrivee}. ${note ?? ''}';
        type = 'transit';
        priorite = 'normale';
        break;

      case StatutColis.arriveDestination:
        titre = 'Colis arrivé à destination';
        message =
            'Colis n° ${colis.id} prêt au ${colis.guichetRetrait} (${colis.agenceArrivee}). Code secret requis.';
        type = 'retrait';
        priorite = 'haute';
        break;

      case StatutColis.retire:
        titre = 'Colis retiré & CNI Archivée';
        message =
            'Colis n° ${colis.id} remis au destinataire. CNI : ${colis.cniDestinataireNumero ?? 'Vérifiée'}.';
        type = 'securite';
        priorite = 'haute';
        break;
    }

    // Gestion alerte spécifique Cash on Delivery
    if (colis.estContreRemboursement && nouveauStatut == StatutColis.retire) {
      type = 'paiement';
      message += ' Montant à reverser au vendeur : ${colis.montantAReverserVendeur} FCFA.';
    }

    final item = NotificationItem(
      id: notifId,
      colisId: colis.id,
      titre: titre,
      message: message,
      type: type,
      dateCreation: DateTime.now(),
      priorite: priorite,
      statutDeclencheur: nouveauStatut.name,
    );

    // Insertion idempotente en base locale SQLite
    final insere = await _dbService.insertNotification(item);
    if (!insere) {
      // Déjà notifié précédemment
      return false;
    }

    // Mise à jour de l'état mémoire
    _notifications.insert(0, item);
    notifyListeners();

    // Déclenchement de la notification système Android si disponible
    await _afficherNotificationSysteme(item);

    return true;
  }

  Future<void> _afficherNotificationSysteme(NotificationItem item) async {
    if (!_isPluginInitialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'colisTrack_statut_channel',
        'Mises à jour des colis',
        channelDescription: 'Notifications d\'état de transit, arrivée et retrait des colis',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      const notifDetails = NotificationDetails(android: androidDetails);

      // Hashcode positif pour l'identifiant Android
      final int notifAndroidId = item.id.hashCode.abs() % 2147483647;

      await _localNotifPlugin.show(
        id: notifAndroidId,
        title: item.titre,
        body: item.message,
        notificationDetails: notifDetails,
      );
    } catch (e) {
      debugPrint('[NotificationService] Émission notification système non supportée : $e');
    }
  }

  Future<void> marquerCommeLue(String id) async {
    await _dbService.markNotificationAsRead(id);
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(estLu: true);
      notifyListeners();
    }
  }

  Future<void> toutMarquerCommeLu() async {
    await _dbService.markAllNotificationsAsRead();
    _notifications = _notifications.map((n) => n.copyWith(estLu: true)).toList();
    notifyListeners();
  }
}

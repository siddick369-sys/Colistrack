class NotificationItem {
  final String id;
  final String colisId;
  final String titre;
  final String message;
  final String type; // 'statut', 'securite', 'paiement', 'manifeste'
  final DateTime dateCreation;
  final bool estLu;
  final String priorite; // 'normale', 'haute', 'urgente'
  final String statutDeclencheur;

  const NotificationItem({
    required this.id,
    required this.colisId,
    required this.titre,
    required this.message,
    required this.type,
    required this.dateCreation,
    this.estLu = false,
    this.priorite = 'normale',
    required this.statutDeclencheur,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'colis_id': colisId,
      'titre': titre,
      'message': message,
      'type': type,
      'date_creation': dateCreation.toIso8601String(),
      'est_lu': estLu ? 1 : 0,
      'priorite': priorite,
      'statut_declencheur': statutDeclencheur,
    };
  }

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String? ?? '',
      colisId: map['colis_id'] as String? ?? '',
      titre: map['titre'] as String? ?? '',
      message: map['message'] as String? ?? '',
      type: map['type'] as String? ?? 'statut',
      dateCreation:
          DateTime.tryParse(map['date_creation'] as String? ?? '') ?? DateTime.now(),
      estLu: (map['est_lu'] as int? ?? 0) == 1,
      priorite: map['priorite'] as String? ?? 'normale',
      statutDeclencheur: map['statut_declencheur'] as String? ?? '',
    );
  }

  NotificationItem copyWith({
    bool? estLu,
    String? priorite,
  }) {
    return NotificationItem(
      id: id,
      colisId: colisId,
      titre: titre,
      message: message,
      type: type,
      dateCreation: dateCreation,
      estLu: estLu ?? this.estLu,
      priorite: priorite ?? this.priorite,
      statutDeclencheur: statutDeclencheur,
    );
  }
}

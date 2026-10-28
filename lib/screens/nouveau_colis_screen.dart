import 'package:flutter/material.dart';
import '../models/colis.dart';
import '../services/colis_service.dart';
import '../theme/app_colors.dart';
import '../widgets/push_momo_dialog.dart';
import '../widgets/ticket_recu_dialog.dart';

class NouveauColisScreen extends StatefulWidget {
  final VoidCallback onColisEnregistre;

  const NouveauColisScreen({super.key, required this.onColisEnregistre});

  @override
  State<NouveauColisScreen> createState() => _NouveauColisScreenState();
}

class _NouveauColisScreenState extends State<NouveauColisScreen> {
  final _formKey = GlobalKey<FormState>();
  final ColisService _service = ColisService();

  // Expéditeur
  final _expediteurNomCtrl =
      TextEditingController(text: 'M. Ndongo Jean (Vendeur Marché Mokolo)');
  final _expediteurTelCtrl = TextEditingController(text: '699010203');
  String _villeDepart = 'Douala';
  String _agenceDepart = 'Agence Bassa (Zone Industrielle)';

  // Destinataire
  final _destinataireNomCtrl = TextEditingController(text: 'Mme Mballa Chantal');
  final _destinataireTelCtrl = TextEditingController(text: '677445566');
  String _villeArrivee = 'Yaoundé';
  String _agenceArrivee = 'Agence Mvan (Gare Routière)';

  // Colis
  String _typeColis = 'Carton Marchandises Diverses';
  final _poidsCtrl = TextEditingController(text: '12');
  final _valeurDeclareeCtrl = TextEditingController(text: '100000');
  final _prixTransportCtrl = TextEditingController(text: '3500');
  StatutPaiement _statutPaiement = StatutPaiement.payeMomo;

  // 1. Preuve Photo
  bool _photoPrise = false;
  static const String _photoDescription =
      'Carton scellé ruban adhésif bleu, étiquette intacte.';

  // 4. Cash on Delivery (Contre Remboursement)
  bool _estCashOnDelivery = false;
  final _montantMarchandiseCtrl = TextEditingController(text: '45000');

  @override
  void initState() {
    super.initState();
    _recalculerPrix();
  }

  @override
  void dispose() {
    _expediteurNomCtrl.dispose();
    _expediteurTelCtrl.dispose();
    _destinataireNomCtrl.dispose();
    _destinataireTelCtrl.dispose();
    _poidsCtrl.dispose();
    _valeurDeclareeCtrl.dispose();
    _prixTransportCtrl.dispose();
    _montantMarchandiseCtrl.dispose();
    super.dispose();
  }

  void _recalculerPrix() {
    final poids = double.tryParse(_poidsCtrl.text) ?? 1.0;
    int prixBase = 1500;
    if (_villeDepart == 'Garoua' ||
        _villeArrivee == 'Garoua' ||
        _villeDepart == 'Maroua' ||
        _villeArrivee == 'Maroua') {
      prixBase = 3500;
    }
    final int total = prixBase + (poids * 150).round();
    _prixTransportCtrl.text = total.toString();
  }

  int get _commissionAgenceCalculee {
    if (!_estCashOnDelivery) return 0;
    final montant = int.tryParse(_montantMarchandiseCtrl.text) ?? 0;
    return (montant * 0.025).round(); // 2.5% de commission
  }

  void _simulerPreuvePhoto() {
    setState(() {
      _photoPrise = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.trackingTeal,
        content: Text('📸 Photo du colis scellé enregistrée & horodatée avec succès !'),
      ),
    );
  }

  void _soumettre() {
    if (!_formKey.currentState!.validate()) return;

    final montantTransport = int.tryParse(_prixTransportCtrl.text) ?? 2000;
    final montantMarchandise =
        _estCashOnDelivery ? (int.tryParse(_montantMarchandiseCtrl.text) ?? 0) : 0;

    // Si paiement par MoMo ou Orange Money, afficher le dialogue informant de l'absence de passerelle locale
    if (_statutPaiement == StatutPaiement.payeMomo ||
        _statutPaiement == StatutPaiement.payeOrangeMoney) {
      final operateur =
          _statutPaiement == StatutPaiement.payeMomo ? 'MTN MoMo' : 'Orange Money';
      PushMomoDialog.show(
        context: context,
        montantFcfa: montantTransport,
        telephoneClient: '+237 ${_expediteurTelCtrl.text.trim()}',
        nomClient: _expediteurNomCtrl.text.trim(),
        operateur: operateur,
        onEnregistrerEnAttente: () {
          // Aucun encaissement automatique non confirmé : enregistrement en attente de paiement
          _enregistrerEtAfficherTicket(
            montantTransport,
            montantMarchandise,
            statutPaiementEffectif: StatutPaiement.aPayerAuRetrait,
          );
        },
      );
    } else {
      _enregistrerEtAfficherTicket(montantTransport, montantMarchandise);
    }
  }

  Future<void> _enregistrerEtAfficherTicket(
      int montantTransport, int montantMarchandise,
      {StatutPaiement? statutPaiementEffectif}) async {
    final nouveauColis = await _service.enregistrerNouveauColis(
      expediteurNom: _expediteurNomCtrl.text.trim(),
      expediteurTel: '+237 ${_expediteurTelCtrl.text.trim()}',
      villeDepart: _villeDepart,
      agenceDepart: _agenceDepart,
      destinataireNom: _destinataireNomCtrl.text.trim(),
      destinataireTel: '+237 ${_destinataireTelCtrl.text.trim()}',
      villeArrivee: _villeArrivee,
      agenceArrivee: _agenceArrivee,
      typeColis: _typeColis,
      poidsKg: double.tryParse(_poidsCtrl.text) ?? 1.0,
      valeurDeclareeFcfa: int.tryParse(_valeurDeclareeCtrl.text) ?? 0,
      prixTransportFcfa: montantTransport,
      statutPaiement: statutPaiementEffectif ?? _statutPaiement,
      photoColisPrise: _photoPrise,
      photoColisDescription: _photoDescription,
      estContreRemboursement: _estCashOnDelivery,
      montantMarchandiseFcfa: montantMarchandise,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text('Colis ${nouveauColis.trackingNumber} enregistré avec succès !'),
      ),
    );

    TicketRecuDialog.show(context, nouveauColis).then((_) {
      if (mounted) {
        widget.onColisEnregistre();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final agencesDepart =
        _service.agencesParVille[_villeDepart] ?? [_villeDepart];
    final agencesArrivee =
        _service.agencesParVille[_villeArrivee] ?? [_villeArrivee];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enregistrement Guichet'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SECTION EXPÉDITEUR
              _sectionCard(
                title: '1. Informations Expéditeur (Départ)',
                icon: Icons.person_pin_outlined,
                color: AppColors.primaryBlue,
                isDark: isDark,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expediteurNomCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nom & Prénom / Vendeur',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v!.isEmpty ? 'Requis' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _expediteurTelCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone (MoMo / OM)',
                            prefixText: '+237 ',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (v) => v!.isEmpty ? 'Requis' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _villeDepart,
                          decoration: const InputDecoration(labelText: 'Ville de Départ'),
                          items: _service.villes
                              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _villeDepart = val;
                                _agenceDepart =
                                    _service.agencesParVille[val]?.first ?? val;
                                _recalculerPrix();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: agencesDepart.contains(_agenceDepart)
                              ? _agenceDepart
                              : agencesDepart.first,
                          decoration: const InputDecoration(labelText: 'Agence de Dépôt'),
                          items: agencesDepart
                              .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(a, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _agenceDepart = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. SECTION DESTINATAIRE
              _sectionCard(
                title: '2. Informations Destinataire (Arrivée)',
                icon: Icons.person_pin_circle_outlined,
                color: AppColors.successGreen,
                isDark: isDark,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _destinataireNomCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nom & Prénom Destinataire',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v!.isEmpty ? 'Requis' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _destinataireTelCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone WhatsApp / SMS',
                            prefixText: '+237 ',
                            prefixIcon: Icon(Icons.phone_android_outlined),
                          ),
                          validator: (v) => v!.isEmpty ? 'Requis' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _villeArrivee,
                          decoration: const InputDecoration(labelText: 'Ville de Destination'),
                          items: _service.villes
                              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _villeArrivee = val;
                                _agenceArrivee =
                                    _service.agencesParVille[val]?.first ?? val;
                                _recalculerPrix();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: agencesArrivee.contains(_agenceArrivee)
                              ? _agenceArrivee
                              : agencesArrivee.first,
                          decoration: const InputDecoration(labelText: 'Agence de Retrait'),
                          items: agencesArrivee
                              .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(a, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _agenceArrivee = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 3. PREUVE PHOTO DU COLIS (Feature 1)
              _sectionCard(
                title: '3. Preuve Photo à l\'Enregistrement (Anti-Litige)',
                icon: Icons.camera_alt_outlined,
                color: AppColors.trackingTeal,
                isDark: isDark,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _photoPrise
                          ? AppColors.trackingTeal.withValues(alpha: 0.08)
                          : (isDark ? AppColors.darkBackground : AppColors.lightBackground),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _photoPrise
                            ? AppColors.trackingTeal
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _photoPrise
                                ? AppColors.trackingTeal
                                : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _photoPrise ? Icons.check_circle : Icons.camera_alt_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _photoPrise
                                    ? 'Photo du colis horodatée & archivée'
                                    : 'Aucune photo capturée',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _photoPrise
                                    ? _photoDescription
                                    : 'Prenez une photo en 2 secondes du colis scellé pour éviter tout litige.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: Icon(_photoPrise ? Icons.refresh : Icons.camera_alt_outlined,
                              size: 15),
                          label: Text(_photoPrise ? 'Reprendre' : 'Capturer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.trackingTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: _simulerPreuvePhoto,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 4. SERVICE CASH ON DELIVERY / CONTRE REMBOURSEMENT (Feature 4)
              _sectionCard(
                title: '4. Service E-commerce (Cash on Delivery / Vendeurs)',
                icon: Icons.shopping_bag_outlined,
                color: AppColors.codPurple,
                isDark: isDark,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Activer l\'option "Colis Contre Remboursement"',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Le destinataire paie l\'article au guichet avant retrait. Le montant est reversé sur le MoMo du vendeur.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    value: _estCashOnDelivery,
                    activeThumbColor: AppColors.codPurple,
                    onChanged: (val) => setState(() => _estCashOnDelivery = val),
                  ),
                  if (_estCashOnDelivery) ...[
                    const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _montantMarchandiseCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Prix de la Marchandise',
                              suffixText: 'FCFA',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.codPurple.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.codPurple.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Commission Agence (2.5%)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+ ${_service.currencyFormat.format(_commissionAgenceCalculee)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.codPurple,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // 5. SECTION TARIF & PAIEMENT USSD (Feature 3)
              _sectionCard(
                title: '5. Caractéristiques & Mode de Règlement',
                icon: Icons.payments_outlined,
                color: AppColors.warningOrange,
                isDark: isDark,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _typeColis,
                    decoration: const InputDecoration(labelText: 'Nature du contenu'),
                    items: _service.typesColis
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _typeColis = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _poidsCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Poids (kg)',
                            suffixText: 'kg',
                          ),
                          onChanged: (_) => _recalculerPrix(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _prixTransportCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Frais de port',
                            suffixText: 'FCFA',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'Règlement des frais de port :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.phone_android,
                            size: 16, color: AppColors.momoYellow),
                        label: const Text('MTN MoMo (Push USSD)'),
                        selected: _statutPaiement == StatutPaiement.payeMomo,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        onSelected: (_) =>
                            setState(() => _statutPaiement = StatutPaiement.payeMomo),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.phone_iphone,
                            size: 16, color: AppColors.orangeMoneyOrange),
                        label: const Text('Orange Money (Push)'),
                        selected: _statutPaiement == StatutPaiement.payeOrangeMoney,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        onSelected: (_) => setState(
                            () => _statutPaiement = StatutPaiement.payeOrangeMoney),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.payments_outlined,
                            size: 16, color: AppColors.successGreen),
                        label: const Text('Espèces'),
                        selected: _statutPaiement == StatutPaiement.payeEspeces,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        onSelected: (_) =>
                            setState(() => _statutPaiement = StatutPaiement.payeEspeces),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.hourglass_bottom_outlined,
                            size: 16, color: Colors.grey),
                        label: const Text('Payable au retrait'),
                        selected: _statutPaiement == StatutPaiement.aPayerAuRetrait,
                        selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                        onSelected: (_) => setState(
                            () => _statutPaiement = StatutPaiement.aPayerAuRetrait),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bouton valider
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    (_statutPaiement == StatutPaiement.payeMomo ||
                            _statutPaiement == StatutPaiement.payeOrangeMoney)
                        ? 'ENVOYER LE PUSH USSD & VALIDER'
                        : 'VALIDER & GÉNÉRER LE REÇU',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _soumettre,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

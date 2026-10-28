# Trans-Colis 237 (Fret & Messagerie Interurbaine)

Application mobile Flutter clé-en-main pour la **numérisation, le reçu thermique et le tracking des colis d'agences de voyage au Cameroun** (Douala ⇄ Yaoundé ⇄ Ouest ⇄ Grand Nord).

---

## 🌟 Fonctionnalités Clés

### 1. Guichet & Enregistrement Express
* Saisie rapide des expéditeurs et destinataires avec indicatif camerounais (+237).
* Villes et agences réelles intégrées :
  * **Douala** : Agences Bassa, Akwa, Bonabéri
  * **Yaoundé** : Agences Mvan, Biyem-Assi, Tongolo
  * **Bafoussam** : Marché B, Djeleng
  * **Grand Nord** : Garoua, Maroua, Ngaoundéré
* Calculateur automatique des tarifs au poids (en FCFA).
* Gestion du règlement : **MTN Mobile Money**, **Orange Money**, **Espèces** ou **Payable au retrait**.

### 2. Impression Thermique & Avis WhatsApp / SMS
* **Génération de QR Code unique** par colis (ex: `CE-DLA-YDE-8921`).
* **Code Secret de Retrait (OTP à 4 chiffres)** pour éliminer les vols et usurpations de colis.
* **Aperçu du Reçu Thermique** conforme aux standards POS-58 / POS-80.
* **Notification WhatsApp directe** au destinataire en 1 clic avec le texte formaté et le numéro de suivi.

### 3. Scanner & Gestion Opérateur / Chauffeur
* Interface de scan rapide par caméra ou numéro de bon.
* Transition d'états d'acheminement :
  1. *Enregistré au guichet*
  2. *Chargé dans le bus (matricule & chauffeur)*
  3. *En transit routier (ex: Axe lourd Douala-Yaoundé / Édéa)*
  4. *Arrivé à destination (disponible au guichet)*
  5. *Validation du retrait sécurisé avec vérification du code secret à 4 chiffres*

### 4. Portail de Suivi Grand Public (Tracking Client)
* Barre de recherche par numéro de colis.
* Timeline visuelle avec horodatage précis et lieux de passage.
* Coordonnées du guichet de retrait et état des frais de port.

### 5. Modèle Économique & Simulateur SaaS
* Simulateur interactif de gains pour l'agence.
* Réduction de 95% des pertes et litiges.
* 3 modèles de vente : Abonnement SaaS fixe, tarification au colis (25 à 50 FCFA/colis) ou pack clé-en-main avec imprimante Bluetooth.

---

## 🚀 Comment ouvrir le projet dans Android Studio

1. Lancez **Android Studio**.
2. Cliquez sur **Open** (ou *File > Open*).
3. Naviguez vers le dossier du projet :
   ```
   C:\Users\USER\.gemini\antigravity\scratch\colis_express
   ```
4. Cliquez sur **OK**.
5. Dans la barre d'outils en haut, sélectionnez l'émulateur Android (`Pixel_4`) ou votre smartphone connecté en USB.
6. Cliquez sur le bouton vert **Play (Run)** ou faites `Shift + F10`.

---

## 💻 Lancer depuis le terminal

```powershell
cd C:\Users\USER\.gemini\antigravity\scratch\colis_express
flutter run
```

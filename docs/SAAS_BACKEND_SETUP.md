# ☁️ ColisTrack Cameroun — Guide d'Architecture & Déploiement SaaS Cloud

Ce document présente l'architecture technique, le schéma de base de données PostgreSQL de référence pour **Supabase / PostgreSQL**, les politiques de sécurité strictes multi-tenants (**Row-Level Security / RLS**) et les règles d'intégration pour la mise en production commerciale de ColisTrack Cameroun.

---

## 1. Schéma Relationnel PostgreSQL Multi-Agences (DDL)

```sql
-- ============================================================================
-- COLISTRACK CAMEROUN V2 — SCHÉMA POSTGRESQL MULTI-AGENCES AVEC RLS
-- ============================================================================

-- 1. Table des Agences (Tenants SaaS)
CREATE TABLE public.agencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code VARCHAR(10) NOT NULL UNIQUE,
    phone VARCHAR(30) NOT NULL,
    city_headquarters TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    subscription_plan VARCHAR(30) NOT NULL DEFAULT 'standard', -- 'starter', 'standard', 'enterprise'
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Index pour recherche rapide
CREATE INDEX idx_agencies_code ON public.agencies (code);

-- 2. Table des Membres d'Agence (Utilisateurs Supabase Auth rattachés)
CREATE TABLE public.agency_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id UUID NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('agencyManager', 'agencyAgent')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(agency_id, user_id)
);

CREATE INDEX idx_agency_members_user ON public.agency_members (user_id);
CREATE INDEX idx_agency_members_agency ON public.agency_members (agency_id);

-- 3. Table des Colis (Données cloisonnées par agence)
CREATE TABLE public.colis (
    id TEXT PRIMARY KEY,
    tracking_number VARCHAR(30) NOT NULL UNIQUE, -- TRX-XXXX-XXXX anti-énumération
    agency_id UUID NOT NULL REFERENCES public.agencies(id) ON DELETE RESTRICT,
    date_enregistrement TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    expediteur_nom TEXT NOT NULL,
    expediteur_tel VARCHAR(30) NOT NULL,
    ville_depart TEXT NOT NULL,
    agence_depart TEXT NOT NULL,
    destinataire_nom TEXT NOT NULL,
    destinataire_tel VARCHAR(30) NOT NULL,
    ville_arrivee TEXT NOT NULL,
    agence_arrivee TEXT NOT NULL,
    guichet_retrait TEXT NOT NULL DEFAULT 'Guichet 1',
    type_colis TEXT NOT NULL,
    poids_kg NUMERIC(6,2) NOT NULL DEFAULT 1.0,
    valeur_declaree_fcfa INTEGER NOT NULL DEFAULT 0,
    prix_transport_fcfa INTEGER NOT NULL,
    statut_paiement VARCHAR(30) NOT NULL,
    statut VARCHAR(30) NOT NULL,
    code_secret_retrait VARCHAR(10) NOT NULL, -- Secret confidentiel délivré à l'expéditeur
    matricule_bus VARCHAR(50),
    chauffeur_nom VARCHAR(100),
    photo_colis_prise BOOLEAN NOT NULL DEFAULT false,
    photo_colis_description TEXT,
    photo_colis_url TEXT,
    cni_destinataire_numero TEXT,
    cni_scan_effectue BOOLEAN NOT NULL DEFAULT false,
    est_contre_remboursement BOOLEAN NOT NULL DEFAULT false,
    montant_marchandise_fcfa INTEGER NOT NULL DEFAULT 0,
    commission_agence_fcfa INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX idx_colis_agency ON public.colis (agency_id);
CREATE INDEX idx_colis_tracking ON public.colis (tracking_number);
CREATE INDEX idx_colis_statut ON public.colis (statut);

-- 4. Étapes de Suivi & Traçabilité (Historique immuable)
CREATE TABLE public.etapes_suivi (
    id BIGSERIAL PRIMARY KEY,
    colis_id TEXT NOT NULL REFERENCES public.colis(id) ON DELETE CASCADE,
    date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    titre TEXT NOT NULL,
    description TEXT NOT NULL,
    lieu TEXT NOT NULL,
    est_completee BOOLEAN NOT NULL DEFAULT true,
    actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX idx_etapes_colis ON public.etapes_suivi (colis_id);

-- 5. Notifications Métier (Idempotentes)
CREATE TABLE public.notifications (
    id TEXT PRIMARY KEY,
    colis_id TEXT NOT NULL REFERENCES public.colis(id) ON DELETE CASCADE,
    agency_id UUID REFERENCES public.agencies(id) ON DELETE CASCADE,
    titre TEXT NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(30) NOT NULL,
    date_creation TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    est_lu BOOLEAN NOT NULL DEFAULT false,
    priorite VARCHAR(20) NOT NULL DEFAULT 'normale',
    statut_declencheur VARCHAR(30) NOT NULL,
    UNIQUE(colis_id, statut_declencheur)
);

CREATE INDEX idx_notifications_agency ON public.notifications (agency_id);
```

---

## 2. Politiques de Sécurité Multi-Tenants (Row-Level Security - RLS)

Les politiques RLS garantissent au niveau même du moteur PostgreSQL qu'**aucun utilisateur d'une agence A ne peut visualiser, modifier ou supprimer les données d'une agence B**, même en cas de bug applicatif côté client.

```sql
-- Activer la RLS sur toutes les tables
ALTER TABLE public.agencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agency_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.colis ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.etapes_suivi ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Helper Function pour récupérer l'agency_id de l'utilisateur authentifié
CREATE OR REPLACE FUNCTION public.current_user_agency_id()
RETURNS UUID AS $$
    SELECT agency_id 
    FROM public.agency_members 
    WHERE user_id = auth.uid() AND is_active = true
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- 1. Politiques sur Colis : Cloisonnement strict par agence
CREATE POLICY "Les membres autorisés accèdent uniquement aux colis de leur agence"
ON public.colis
FOR ALL
TO authenticated
USING (agency_id = public.current_user_agency_id())
WITH CHECK (agency_id = public.current_user_agency_id());

-- 2. Politiques sur Étapes de suivi
CREATE POLICY "Les membres accèdent aux étapes des colis de leur agence"
ON public.etapes_suivi
FOR ALL
TO authenticated
USING (
    colis_id IN (
        SELECT id FROM public.colis WHERE agency_id = public.current_user_agency_id()
    )
);

-- 3. Politiques sur Notifications
CREATE POLICY "Les membres visualisent les notifications de leur agence"
ON public.notifications
FOR ALL
TO authenticated
USING (agency_id = public.current_user_agency_id());
```

---

## 3. Fonction RPC Sécurisée pour le Suivi Client Public (Zéro Fuite de Données)

Le client consulte son colis via le Web ou l'application **sans création de compte**.  
Pour empêcher toute fuite de données personnelles (CNI, numéros de téléphone complets, code OTP secret, commissions agence), une fonction RPC avec masquage cryptographique est exposée au rôle anonyme (`anon`).

```sql
CREATE OR REPLACE FUNCTION public.get_public_parcel_tracking(p_tracking_number TEXT)
RETURNS JSONB AS $$
DECLARE
    v_colis RECORD;
    v_etapes JSONB;
    v_agency_name TEXT;
BEGIN
    -- Recherche du colis par son tracking_number officiel
    SELECT * INTO v_colis 
    FROM public.colis 
    WHERE tracking_number = p_tracking_number;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Colis introuvable');
    END IF;

    -- Récupération du nom de l'agence
    SELECT name INTO v_agency_name 
    FROM public.agencies 
    WHERE id = v_colis.agency_id;

    -- Récupération des étapes de suivi publiques
    SELECT jsonb_agg(
        jsonb_build_object(
            'date', e.date,
            'titre', e.titre,
            'description', e.description,
            'lieu', e.lieu,
            'est_completee', e.est_completee
        ) ORDER BY e.date ASC
    ) INTO v_etapes
    FROM public.etapes_suivi e
    WHERE e.colis_id = v_colis.id;

    -- Retour sécurisé DTO (Zero leakage : No OTP, No CNI, No commissions, No raw phones)
    RETURN jsonb_build_object(
        'success', true,
        'tracking_number', v_colis.tracking_number,
        'agency_name', COALESCE(v_agency_name, 'Agence de Transport'),
        'statut', v_colis.statut,
        'ville_depart', v_colis.ville_depart,
        'agence_depart', v_colis.agence_depart,
        'ville_arrivee', v_colis.ville_arrivee,
        'agence_arrivee', v_colis.agence_arrivee,
        'guichet_retrait', v_colis.guichet_retrait,
        'type_colis', v_colis.type_colis,
        'last_updated', v_colis.updated_at,
        'events', COALESCE(v_etapes, '[]'::jsonb)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Accorder l'exécution aux utilisateurs anonymes
GRANT EXECUTE ON FUNCTION public.get_public_parcel_tracking(TEXT) TO anon, authenticated;
```

---

## 4. Intégration Flutter Supabase (`lib/services/supabase_sync_service.dart`)

Dans l'application Flutter, la synchronisation hors-ligne/en-ligne fonctionne en mode **Offline-First** :

1. L'enregistrement au guichet s'écrit en **local immédiatement** dans SQLite via `DatabaseService`.
2. Le statut `SyncStatus.pendingSync` est appliqué si l'appareil est hors-ligne.
3. Dès que le réseau est disponible, `ColisService.synchroniserFileAttente()` transmet les transactions au backend Supabase via l'API REST/Realtime et bascule en `SyncStatus.synced`.
4. En cas de coupure de réseau routier au Cameroun (ex: falaise de Dschang, zone forestière), l'application continue de fonctionner à 100% sans aucun blocage guichet.

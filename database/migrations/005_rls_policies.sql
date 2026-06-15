-- ============================================================
-- MIGRATION 005: Row Level Security (RLS) Policies
-- ============================================================

-- ------------------------------------------------------------
-- Helper: public.get_user_role()
-- Lê o role da usuária logada sem recursão infinita.
-- Fica em public (não auth) — Supabase não permite CREATE em auth.
-- SECURITY DEFINER: roda como dono da tabela, bypassa RLS em
-- profiles para evitar loop infinito nas policies.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM profiles WHERE id = auth.uid();
$$;

COMMENT ON FUNCTION public.get_user_role IS
    'Retorna o role da usuária autenticada. SECURITY DEFINER para evitar recursão infinita em policies de profiles.';


-- ============================================================
-- TABLE: profiles
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select"
    ON profiles FOR SELECT
    USING (
        id = auth.uid()
        OR public.get_user_role() = 'admin'
    );

CREATE POLICY "profiles_insert_own"
    ON profiles FOR INSERT
    WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update_own"
    ON profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (
        role = (SELECT role FROM profiles WHERE id = auth.uid())
    );

CREATE POLICY "profiles_delete_admin"
    ON profiles FOR DELETE
    USING (public.get_user_role() = 'admin');


-- ============================================================
-- TABLE: collection_points
-- ============================================================
ALTER TABLE collection_points ENABLE ROW LEVEL SECURITY;

CREATE POLICY "collection_points_select"
    ON collection_points FOR SELECT
    USING (
        status = 'active'
        OR public.get_user_role() = 'admin'
    );

CREATE POLICY "collection_points_insert_admin"
    ON collection_points FOR INSERT
    WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "collection_points_update_admin"
    ON collection_points FOR UPDATE
    USING (public.get_user_role() = 'admin');

CREATE POLICY "collection_points_delete_admin"
    ON collection_points FOR DELETE
    USING (public.get_user_role() = 'admin');


-- ============================================================
-- TABLE: inventory
-- ============================================================
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inventory_select_authenticated"
    ON inventory FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "inventory_insert_admin"
    ON inventory FOR INSERT
    WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "inventory_update_admin"
    ON inventory FOR UPDATE
    USING (public.get_user_role() = 'admin');

CREATE POLICY "inventory_delete_admin"
    ON inventory FOR DELETE
    USING (public.get_user_role() = 'admin');


-- ============================================================
-- TABLE: transactions
-- ============================================================
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "transactions_select"
    ON transactions FOR SELECT
    USING (
        user_id = auth.uid()
        OR public.get_user_role() = 'admin'
    );

CREATE POLICY "transactions_insert_own"
    ON transactions FOR INSERT
    WITH CHECK (user_id = auth.uid());


-- ============================================================
-- TABLE: feedbacks
-- ============================================================
ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feedbacks_select"
    ON feedbacks FOR SELECT
    USING (
        submitted_by = auth.uid()
        OR public.get_user_role() = 'admin'
    );

CREATE POLICY "feedbacks_insert_own"
    ON feedbacks FOR INSERT
    WITH CHECK (submitted_by = auth.uid());

CREATE POLICY "feedbacks_update_admin"
    ON feedbacks FOR UPDATE
    USING (public.get_user_role() = 'admin');

CREATE POLICY "feedbacks_delete_admin"
    ON feedbacks FOR DELETE
    USING (public.get_user_role() = 'admin');


-- ============================================================
-- TABLE: notifications
-- ============================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own"
    ON notifications FOR SELECT
    USING (recipient_id = auth.uid());

CREATE POLICY "notifications_insert_admin"
    ON notifications FOR INSERT
    WITH CHECK (public.get_user_role() = 'admin');

CREATE POLICY "notifications_update_own"
    ON notifications FOR UPDATE
    USING (recipient_id = auth.uid())
    WITH CHECK (recipient_id = auth.uid());

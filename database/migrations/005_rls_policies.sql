-- ============================================================
-- MIGRATION 005: Row Level Security (RLS) Policies
-- O Supabase usa RLS exclusivamente. Toda tabela DEVE ter RLS
-- habilitado com políticas explícitas — sem acesso implícito.
--
-- Princípio zero-trust:
--   - Estudante acessa apenas seus próprios dados
--   - Admin acessa todos os dados
--   - Triggers SECURITY DEFINER bypassam RLS quando necessário
-- ============================================================


-- ------------------------------------------------------------
-- Helper: auth.user_role()
-- Lê o role da usuária logada sem recursão infinita.
-- SECURITY DEFINER: roda como dono da tabela, bypassa RLS em
-- profiles — necessário porque policies em profiles não podem
-- chamar SELECT em profiles diretamente (loop infinito).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth.user_role()
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM profiles WHERE id = auth.uid();
$$;

COMMENT ON FUNCTION auth.user_role IS
    'Retorna o role da usuária autenticada. SECURITY DEFINER para evitar recursão infinita em policies de profiles.';


-- ============================================================
-- TABLE: profiles
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Estudante vê apenas sua própria linha; admin vê todas
CREATE POLICY "profiles_select"
    ON profiles FOR SELECT
    USING (
        id = auth.uid()
        OR auth.user_role() = 'admin'
    );

-- Usuária insere apenas seu próprio perfil (id deve = auth.uid())
-- Na prática, isso é feito pelo trigger handle_new_user, não diretamente
CREATE POLICY "profiles_insert_own"
    ON profiles FOR INSERT
    WITH CHECK (id = auth.uid());

-- Usuária atualiza apenas seu próprio perfil
-- WITH CHECK impede auto-promoção para admin
CREATE POLICY "profiles_update_own"
    ON profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (
        role = (SELECT role FROM profiles WHERE id = auth.uid())
    );

-- Apenas admins podem deletar perfis (ex: requisição de exclusão de dados)
CREATE POLICY "profiles_delete_admin"
    ON profiles FOR DELETE
    USING (auth.user_role() = 'admin');


-- ============================================================
-- TABLE: collection_points
-- ============================================================
ALTER TABLE collection_points ENABLE ROW LEVEL SECURITY;

-- Estudantes veem apenas pontos ativos; admins veem todos os status
CREATE POLICY "collection_points_select"
    ON collection_points FOR SELECT
    USING (
        status = 'active'
        OR auth.user_role() = 'admin'
    );

-- Apenas admins cadastram pontos de coleta
CREATE POLICY "collection_points_insert_admin"
    ON collection_points FOR INSERT
    WITH CHECK (auth.user_role() = 'admin');

-- Apenas admins editam pontos (nome, status, localização, etc.)
CREATE POLICY "collection_points_update_admin"
    ON collection_points FOR UPDATE
    USING (auth.user_role() = 'admin');

-- Apenas admins deletam pontos
CREATE POLICY "collection_points_delete_admin"
    ON collection_points FOR DELETE
    USING (auth.user_role() = 'admin');


-- ============================================================
-- TABLE: inventory
-- ============================================================
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;

-- Toda usuária autenticada pode ler o estoque
-- (estudante precisa saber se um ponto tem absorventes antes de ir)
CREATE POLICY "inventory_select_authenticated"
    ON inventory FOR SELECT
    USING (auth.role() = 'authenticated');

-- Escrita direta apenas por admins (para cadastrar estoque inicial)
-- Movimentações normais ocorrem via trigger em transactions
CREATE POLICY "inventory_insert_admin"
    ON inventory FOR INSERT
    WITH CHECK (auth.user_role() = 'admin');

CREATE POLICY "inventory_update_admin"
    ON inventory FOR UPDATE
    USING (auth.user_role() = 'admin');

CREATE POLICY "inventory_delete_admin"
    ON inventory FOR DELETE
    USING (auth.user_role() = 'admin');


-- ============================================================
-- TABLE: transactions
-- ============================================================
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Estudante vê apenas suas próprias transações; admin vê todas
CREATE POLICY "transactions_select"
    ON transactions FOR SELECT
    USING (
        user_id = auth.uid()
        OR auth.user_role() = 'admin'
    );

-- Estudante pode inserir apenas transações em seu próprio nome
CREATE POLICY "transactions_insert_own"
    ON transactions FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Sem UPDATE ou DELETE — transactions são imutáveis (log de auditoria)
-- A ausência de policy bloqueia qualquer tentativa de escrita


-- ============================================================
-- TABLE: feedbacks
-- ============================================================
ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;

-- Estudante vê apenas seus próprios feedbacks; admin vê todos
CREATE POLICY "feedbacks_select"
    ON feedbacks FOR SELECT
    USING (
        submitted_by = auth.uid()
        OR auth.user_role() = 'admin'
    );

-- Estudante envia feedback apenas em seu próprio nome
CREATE POLICY "feedbacks_insert_own"
    ON feedbacks FOR INSERT
    WITH CHECK (submitted_by = auth.uid());

-- Apenas admins atualizam status do feedback (resolver, assumir, etc.)
CREATE POLICY "feedbacks_update_admin"
    ON feedbacks FOR UPDATE
    USING (auth.user_role() = 'admin');

-- Feedbacks não são deletados (trilha de auditoria); apenas admins podem
CREATE POLICY "feedbacks_delete_admin"
    ON feedbacks FOR DELETE
    USING (auth.user_role() = 'admin');


-- ============================================================
-- TABLE: notifications
-- ============================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Admin vê apenas suas próprias notificações
CREATE POLICY "notifications_select_own"
    ON notifications FOR SELECT
    USING (recipient_id = auth.uid());

-- Notificações são criadas pelo trigger notify_admins_on_feedback
-- (SECURITY DEFINER). Esta policy é fallback para inserções manuais.
CREATE POLICY "notifications_insert_admin"
    ON notifications FOR INSERT
    WITH CHECK (auth.user_role() = 'admin');

-- Admin pode marcar notificações como lidas (atualizar read_at)
CREATE POLICY "notifications_update_own"
    ON notifications FOR UPDATE
    USING (recipient_id = auth.uid())
    WITH CHECK (recipient_id = auth.uid());

-- Sem DELETE — histórico de notificações é preservado

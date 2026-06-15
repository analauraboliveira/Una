-- ============================================================
-- MIGRATION 003: Tables
-- Ordem de criação respeita dependências de FK.
-- Todas as tabelas têm RLS habilitado na migration 005.
-- ============================================================


-- ------------------------------------------------------------
-- TABLE: profiles
-- Extensão 1:1 de auth.users (Supabase Auth).
-- Criada automaticamente pelo trigger handle_new_user (migration 006)
-- quando a usuária se cadastra via Supabase Auth.
--
-- Campos do formulário de cadastro (Fluxo 4):
--   Dados pessoais: nome completo, username, pronomes, e-mail (em auth.users)
--   Dados de saúde: idade, duração do ciclo, duração da menstruação
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
    -- Espelho de auth.users.id — não gerado aqui, atribuído pelo Supabase Auth
    id                          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Dados pessoais
    full_name                   TEXT NOT NULL,
    username                    TEXT NOT NULL UNIQUE,
    pronouns                    TEXT,                          -- Livre: ela/dela, elu/delu, etc.

    role                        user_role NOT NULL DEFAULT 'student',

    -- Dados de saúde — protegidos por RLS (apenas a própria usuária e admins leem)
    age                         SMALLINT CHECK (age BETWEEN 1 AND 120),
    cycle_duration_days         SMALLINT CHECK (cycle_duration_days BETWEEN 1 AND 90),
    menstruation_duration_days  SMALLINT CHECK (menstruation_duration_days BETWEEN 1 AND 30),

    -- URL da foto de perfil (Supabase Storage)
    avatar_url                  TEXT,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE profiles IS
    'Extensão 1:1 de auth.users. Armazena dados de perfil e dados sensíveis de saúde íntima das estudantes.';
COMMENT ON COLUMN profiles.username IS
    'Nome de usuário único na plataforma. Coletado no formulário de cadastro.';
COMMENT ON COLUMN profiles.pronouns IS
    'Pronomes da usuária (campo livre). Ex: ela/dela, elu/delu, ele/dele.';
COMMENT ON COLUMN profiles.age IS
    'Idade informada no cadastro (não calculada a partir de data de nascimento).';
COMMENT ON COLUMN profiles.cycle_duration_days IS
    'Duração média do ciclo menstrual em dias. Dado sensível — protegido por RLS.';
COMMENT ON COLUMN profiles.menstruation_duration_days IS
    'Duração média da menstruação em dias. Dado sensível — protegido por RLS.';


-- ------------------------------------------------------------
-- TABLE: collection_points
-- Pontos físicos de coleta no campus da UFPE onde as estudantes
-- podem retirar e depositar produtos menstruais.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS collection_points (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    name            TEXT NOT NULL,
    building        TEXT NOT NULL,          -- Ex: "CIn", "CAC", "Biblioteca Central"
    campus          TEXT NOT NULL DEFAULT 'Recife',   -- Preparado para outros campi
    floor           TEXT,                   -- Ex: "Térreo", "2º andar"
    room            TEXT,                   -- Ex: "Banheiro feminino ala leste"

    -- PostGIS GEOGRAPHY para consultas geoespaciais com distâncias em metros.
    -- SRID 4326 = WGS84 (coordenadas GPS padrão).
    -- Atenção: PostGIS usa POINT(longitude latitude) — longitude primeiro.
    location        GEOGRAPHY(POINT, 4326) NOT NULL,

    status          collection_point_status NOT NULL DEFAULT 'active',

    -- Admin que cadastrou o ponto — NULL se a conta do admin for deletada
    created_by      UUID REFERENCES profiles(id) ON DELETE SET NULL,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE collection_points IS
    'Pontos físicos de coleta de produtos menstruais no campus da UFPE.';
COMMENT ON COLUMN collection_points.location IS
    'PostGIS GEOGRAPHY POINT (WGS84/SRID 4326). Use ST_DWithin para consultas de raio — o terceiro argumento é em metros.';
COMMENT ON COLUMN collection_points.campus IS
    'Campus da UFPE. Default "Recife" — campo presente para suportar expansão para outros campi no futuro.';


-- ------------------------------------------------------------
-- TABLE: inventory
-- Estoque atual por ponto de coleta por tipo de produto.
-- Uma linha por (point_id, item_type).
--
-- IMPORTANTE: Nunca escrever nesta tabela diretamente.
-- Sempre inserir em transactions — o trigger adjust_inventory_on_transaction
-- (migration 006) atualiza o estoque de forma concorrência-safe.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    point_id        UUID NOT NULL REFERENCES collection_points(id) ON DELETE CASCADE,
    item_type       menstrual_item_type NOT NULL,

    -- Quantidade atual. CHECK >= 0 é o backstop final — o trigger bloqueia antes disso.
    quantity        INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),

    -- Quando quantity <= min_quantity, o sistema deve emitir alerta de estoque baixo.
    min_quantity    INTEGER NOT NULL DEFAULT 5 CHECK (min_quantity >= 0),

    last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Um registro por tipo de produto por ponto
    CONSTRAINT inventory_point_item_unique UNIQUE (point_id, item_type)
);

COMMENT ON TABLE inventory IS
    'Estoque atual por ponto por tipo de produto. Modificado exclusivamente via trigger ao inserir em transactions.';
COMMENT ON COLUMN inventory.min_quantity IS
    'Limiar de alerta. Quando quantity <= min_quantity, NestJS deve disparar notificação de estoque baixo.';


-- ------------------------------------------------------------
-- TABLE: transactions
-- Log imutável de todas as retiradas e doações.
-- INSERT aqui → trigger ajusta inventory automaticamente.
--
-- Regra de negócio central (Fluxo 1):
--   Retirada = exatamente 1 item por vez (CHECK constraint).
--   Uma retirada por usuária por dia (verificado por has_user_withdrawn_today()).
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    type            transaction_type NOT NULL,

    -- Quem fez a transação — RESTRICT impede deletar perfil com histórico
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,

    -- Onde ocorreu — RESTRICT impede deletar ponto com histórico
    point_id        UUID NOT NULL REFERENCES collection_points(id) ON DELETE RESTRICT,

    -- O que foi movimentado
    item_type       menstrual_item_type NOT NULL,

    -- Regra de negócio: retirada = exatamente 1 item.
    -- Doação pode ser qualquer quantidade positiva (ex: caixa com 10).
    quantity        INTEGER NOT NULL DEFAULT 1
                    CONSTRAINT withdrawal_quantity_must_be_one
                    CHECK (
                        quantity > 0
                        AND (type <> 'withdrawal' OR quantity = 1)
                    ),

    -- Observação opcional (ex: "Doação da turma SI 2024.1")
    notes           TEXT,

    -- Usado por has_user_withdrawn_today() para verificar limite diário
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE transactions IS
    'Log imutável de retiradas e doações. INSERT aciona trigger que atualiza inventory. Sem UPDATE ou DELETE (auditoria).';
COMMENT ON COLUMN transactions.quantity IS
    'Para retirada: sempre 1 (enforced por CHECK). Para doação: qualquer inteiro positivo.';


-- ------------------------------------------------------------
-- TABLE: feedbacks
-- Relatos de problemas enviados pelas estudantes sobre pontos
-- de coleta (Fluxo 3).
--
-- Dois tipos de feedback do fluxo:
--   COMUM    → category definida (empty_stock, damaged, inaccessible)
--   ESPECÍFICO → is_specific=TRUE + description preenchida
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS feedbacks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    point_id        UUID NOT NULL REFERENCES collection_points(id) ON DELETE CASCADE,

    -- Quem enviou — RESTRICT garante rastreabilidade do relato
    submitted_by    UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,

    -- Categoria do problema (fluxo COMUM) ou 'other' (fluxo ESPECÍFICO)
    category        feedback_category NOT NULL,

    -- TRUE quando é um problema ESPECÍFICO (texto livre obrigatório)
    is_specific     BOOLEAN NOT NULL DEFAULT FALSE,

    -- Descrição livre (obrigatória quando is_specific = TRUE)
    description     TEXT,

    status          feedback_status NOT NULL DEFAULT 'pending',

    -- Preenchido quando um admin resolve o feedback
    resolved_by     UUID REFERENCES profiles(id) ON DELETE SET NULL,
    resolved_at     TIMESTAMPTZ,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Garante consistência: status 'resolved' exige resolved_by E resolved_at
    CONSTRAINT resolved_fields_consistent CHECK (
        (status = 'resolved') = (resolved_by IS NOT NULL AND resolved_at IS NOT NULL)
    ),

    -- Feedback específico exige descrição
    CONSTRAINT specific_requires_description CHECK (
        NOT is_specific OR description IS NOT NULL
    )
);

COMMENT ON TABLE feedbacks IS
    'Relatos de problemas enviados pelas estudantes. INSERT aciona trigger que notifica todos os admins.';
COMMENT ON COLUMN feedbacks.is_specific IS
    'TRUE = problema específico (texto livre em description). FALSE = categoria pré-definida (COMUM no fluxo).';


-- ------------------------------------------------------------
-- TABLE: notifications
-- Notificações in-app para admins geradas automaticamente
-- pelo trigger notify_admins_on_feedback.
-- Supabase Realtime deve ser habilitado nesta tabela para
-- o painel web receber alertas sem polling.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Admin destinatário
    recipient_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Feedback que gerou esta notificação (nullable para outros tipos futuros)
    feedback_id     UUID REFERENCES feedbacks(id) ON DELETE CASCADE,

    title           TEXT NOT NULL,
    body            TEXT NOT NULL,

    -- NULL até o admin visualizar/marcar como lida
    read_at         TIMESTAMPTZ,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE notifications IS
    'Notificações in-app para admins. Geradas por trigger ao receber feedbacks. Habilitar Supabase Realtime nesta tabela.';
COMMENT ON COLUMN notifications.read_at IS
    'NULL = não lida. Preenchida pelo painel admin quando o usuário visualiza a notificação.';

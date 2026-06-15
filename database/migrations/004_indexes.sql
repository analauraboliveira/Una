-- ============================================================
-- MIGRATION 004: Indexes
-- Índices de performance. O índice espacial GIST é o mais
-- crítico — sem ele, toda query de mapa é full table scan.
-- ============================================================


-- ------------------------------------------------------------
-- collection_points — índices espaciais (PostGIS)
-- ------------------------------------------------------------

-- Índice GIST geral: suporta ST_DWithin, ST_Distance, ST_Within.
-- Usado por get_nearest_collection_points() e qualquer query geoespacial.
CREATE INDEX IF NOT EXISTS idx_cp_location
    ON collection_points USING GIST (location);

-- Índice GIST parcial para pontos ATIVOS.
-- Query dominante do app: "pontos ativos próximos de mim".
-- Índice menor (exclui inactive/maintenance) → mais rápido.
-- O planner escolhe este quando WHERE status = 'active' está presente.
CREATE INDEX IF NOT EXISTS idx_cp_location_active
    ON collection_points USING GIST (location)
    WHERE status = 'active';

-- Filtro por status sem componente espacial (ex: listar pontos em manutenção)
CREATE INDEX IF NOT EXISTS idx_cp_status
    ON collection_points (status);


-- ------------------------------------------------------------
-- inventory — índices de monitoramento de estoque
-- ------------------------------------------------------------

-- O UNIQUE constraint já cria índice em (point_id, item_type).
-- Índice parcial para monitoramento de estoque baixo:
-- "quais pontos têm estoque abaixo do mínimo?"
CREATE INDEX IF NOT EXISTS idx_inv_low_stock
    ON inventory (point_id)
    WHERE quantity <= min_quantity;


-- ------------------------------------------------------------
-- transactions — índices de histórico e verificação de limite
-- ------------------------------------------------------------

-- Histórico de transações por usuária (perfil mobile) +
-- verificação do limite diário de retirada por has_user_withdrawn_today().
-- DESC em created_at para queries de "última transação" serem O(1).
CREATE INDEX IF NOT EXISTS idx_tx_user_date
    ON transactions (user_id, created_at DESC);

-- Histórico de transações por ponto (painel admin)
CREATE INDEX IF NOT EXISTS idx_tx_point
    ON transactions (point_id, created_at DESC);

-- Filtro por tipo para relatórios de retiradas vs doações
CREATE INDEX IF NOT EXISTS idx_tx_type
    ON transactions (type, created_at DESC);


-- ------------------------------------------------------------
-- feedbacks — fila de pendentes para o painel admin
-- ------------------------------------------------------------

-- Fila de feedbacks pendentes: admin vê "pending" primeiro, mais recentes primeiro
CREATE INDEX IF NOT EXISTS idx_fb_status
    ON feedbacks (status, created_at DESC);

-- Feedbacks por ponto de coleta
CREATE INDEX IF NOT EXISTS idx_fb_point
    ON feedbacks (point_id, created_at DESC);


-- ------------------------------------------------------------
-- notifications — poll de não lidas
-- ------------------------------------------------------------

-- Query principal do painel: "minhas notificações não lidas"
-- Índice parcial (WHERE read_at IS NULL) — menor e mais rápido
CREATE INDEX IF NOT EXISTS idx_notif_unread
    ON notifications (recipient_id, created_at DESC)
    WHERE read_at IS NULL;

-- Histórico completo de notificações de um admin
CREATE INDEX IF NOT EXISTS idx_notif_recipient
    ON notifications (recipient_id, created_at DESC);


-- ------------------------------------------------------------
-- profiles — filtro por role
-- ------------------------------------------------------------

-- notify_admins_on_feedback() faz SELECT id FROM profiles WHERE role='admin'
-- Este índice evita full scan de profiles a cada feedback.
CREATE INDEX IF NOT EXISTS idx_profiles_role
    ON profiles (role);

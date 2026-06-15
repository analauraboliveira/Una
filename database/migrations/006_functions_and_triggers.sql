-- ============================================================
-- MIGRATION 006: Functions and Triggers
-- Lógica de negócio implementada no banco de dados.
-- Todas as funções são SECURITY DEFINER onde precisam bypassar
-- RLS para operar em nome do sistema.
-- ============================================================


-- ------------------------------------------------------------
-- FUNCTION: handle_new_user
-- Gatilho: AFTER INSERT ON auth.users
-- Cria automaticamente o row em profiles quando a usuária
-- se cadastra via Supabase Auth (Fluxo 4 — Cadastro).
-- Lê full_name, username e pronouns de raw_user_meta_data,
-- que devem ser enviados no sign-up pelo frontend.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO profiles (id, full_name, username, pronouns, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'username', NEW.id::TEXT),
        NEW.raw_user_meta_data->>'pronouns',
        COALESCE(
            (NEW.raw_user_meta_data->>'role')::user_role,
            'student'
        )
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

COMMENT ON FUNCTION handle_new_user IS
    'Cria row em profiles automaticamente no cadastro via Supabase Auth. Lê full_name, username, pronouns de raw_user_meta_data.';


-- ------------------------------------------------------------
-- FUNCTION: update_updated_at_column
-- Gatilho genérico para manter updated_at sempre atual.
-- Aplicado em profiles, collection_points e feedbacks.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER collection_points_updated_at
    BEFORE UPDATE ON collection_points
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER feedbacks_updated_at
    BEFORE UPDATE ON feedbacks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON FUNCTION update_updated_at_column IS
    'Trigger genérico que atualiza updated_at para NOW() antes de qualquer UPDATE.';


-- ------------------------------------------------------------
-- FUNCTION: adjust_inventory_on_transaction
-- Gatilho: AFTER INSERT ON transactions
-- Lógica de negócio central dos Fluxos 1 e 2.
--
-- Segurança de concorrência:
--   SELECT ... FOR UPDATE bloqueia o row de inventory para
--   a duração da transação PostgreSQL. Duas retiradas
--   simultâneas para o mesmo (point_id, item_type) são
--   serializadas — a segunda aguarda a primeira commitar.
--   CHECK (quantity >= 0) é o backstop final.
--
-- SECURITY DEFINER: estudantes não têm UPDATE em inventory
-- via RLS, mas o trigger precisa modificá-lo.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION adjust_inventory_on_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_current_qty INTEGER;
BEGIN
    -- Bloqueia o row de inventory para evitar race condition.
    -- Outras transações que tentarem modificar o mesmo (point_id, item_type)
    -- aguardarão até este COMMIT ou ROLLBACK.
    SELECT quantity INTO v_current_qty
    FROM inventory
    WHERE point_id = NEW.point_id
      AND item_type = NEW.item_type
    FOR UPDATE;

    -- O row de inventory DEVE existir antes de qualquer transação
    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Estoque não encontrado para point_id=% e item_type=%',
            NEW.point_id, NEW.item_type
            USING ERRCODE = 'no_data_found';
    END IF;

    IF NEW.type = 'withdrawal' THEN
        -- Verifica se há estoque suficiente antes de decrementar
        IF v_current_qty < NEW.quantity THEN
            RAISE EXCEPTION
                'Estoque insuficiente no ponto % para %. Disponível: %',
                NEW.point_id, NEW.item_type, v_current_qty
                USING ERRCODE = 'check_violation';
        END IF;

        UPDATE inventory
        SET quantity       = quantity - NEW.quantity,
            last_updated_at = NOW()
        WHERE point_id = NEW.point_id
          AND item_type = NEW.item_type;

    ELSIF NEW.type = 'donation' THEN
        UPDATE inventory
        SET quantity       = quantity + NEW.quantity,
            last_updated_at = NOW()
        WHERE point_id = NEW.point_id
          AND item_type = NEW.item_type;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_transaction_insert
    AFTER INSERT ON transactions
    FOR EACH ROW EXECUTE FUNCTION adjust_inventory_on_transaction();

COMMENT ON FUNCTION adjust_inventory_on_transaction IS
    'Atualiza inventory.quantity na inserção de transactions. SELECT FOR UPDATE garante segurança contra race conditions em retiradas concorrentes.';


-- ------------------------------------------------------------
-- FUNCTION: notify_admins_on_feedback
-- Gatilho: AFTER INSERT ON feedbacks
-- Cria uma notification para cada admin quando um feedback
-- é enviado (Fluxo 3 — Relatar Problemas).
--
-- SECURITY DEFINER: estudantes não têm INSERT em notifications
-- via RLS, mas o trigger precisa criar as notificações.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION notify_admins_on_feedback()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin     RECORD;
    v_point_name TEXT;
    v_category_label TEXT;
BEGIN
    -- Nome do ponto para a mensagem de notificação
    SELECT name INTO v_point_name
    FROM collection_points
    WHERE id = NEW.point_id;

    -- Label amigável para a categoria
    v_category_label := CASE NEW.category
        WHEN 'empty_stock'   THEN 'Estoque esgotado'
        WHEN 'damaged'       THEN 'Ponto danificado'
        WHEN 'inaccessible'  THEN 'Ponto inacessível'
        ELSE                      'Problema específico'
    END;

    -- Cria uma notificação para cada admin
    FOR v_admin IN
        SELECT id FROM profiles WHERE role = 'admin'
    LOOP
        INSERT INTO notifications (recipient_id, feedback_id, title, body)
        VALUES (
            v_admin.id,
            NEW.id,
            'Novo feedback recebido',
            FORMAT(
                '%s relatado no ponto "%s".',
                v_category_label,
                COALESCE(v_point_name, 'desconhecido')
            )
        );
    END LOOP;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_feedback_insert
    AFTER INSERT ON feedbacks
    FOR EACH ROW EXECUTE FUNCTION notify_admins_on_feedback();

COMMENT ON FUNCTION notify_admins_on_feedback IS
    'Cria notificações in-app para todos os admins quando um novo feedback é enviado.';


-- ------------------------------------------------------------
-- FUNCTION: get_nearest_collection_points
-- Retorna pontos de coleta ATIVOS ordenados por distância de
-- uma coordenada GPS fornecida pelo app móvel.
--
-- Padrão PostGIS de duas etapas:
--   1. ST_DWithin (usa índice GIST) para filtrar por raio
--   2. ST_Distance para ordenar com precisão
--
-- Inclui total_stock para o pin do mapa mostrar disponibilidade.
--
-- Parâmetros:
--   p_lat      : Latitude do usuário (WGS84)
--   p_lng      : Longitude do usuário (WGS84)
--   p_radius_m : Raio de busca em metros (default: 2000 = 2km)
--   p_limit    : Número máximo de resultados (default: 10)
--
-- Chamada pelo app móvel via Supabase RPC:
--   supabase.rpc('get_nearest_collection_points', { p_lat, p_lng })
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_nearest_collection_points(
    p_lat       FLOAT8,
    p_lng       FLOAT8,
    p_radius_m  FLOAT8  DEFAULT 2000,
    p_limit     INTEGER DEFAULT 10
)
RETURNS TABLE (
    id              UUID,
    name            TEXT,
    building        TEXT,
    campus          TEXT,
    floor           TEXT,
    room            TEXT,
    status          collection_point_status,
    distance_meters FLOAT8,
    latitude        FLOAT8,
    longitude       FLOAT8,
    total_stock     INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    WITH user_location AS (
        -- PostGIS: MakePoint recebe (longitude, latitude) — ordem inversa ao padrão humano
        SELECT ST_SetSRID(
            ST_MakePoint(p_lng, p_lat),
            4326
        )::GEOGRAPHY AS geog
    )
    SELECT
        cp.id,
        cp.name,
        cp.building,
        cp.campus,
        cp.floor,
        cp.room,
        cp.status,
        ROUND(ST_Distance(cp.location, ul.geog)::NUMERIC, 1)::FLOAT8 AS distance_meters,
        ST_Y(cp.location::GEOMETRY)                                   AS latitude,
        ST_X(cp.location::GEOMETRY)                                   AS longitude,
        COALESCE(SUM(inv.quantity), 0)::INTEGER                       AS total_stock
    FROM collection_points cp
    CROSS JOIN user_location ul
    LEFT JOIN inventory inv ON inv.point_id = cp.id
    WHERE
        cp.status = 'active'
        AND ST_DWithin(cp.location, ul.geog, p_radius_m)
    GROUP BY
        cp.id, cp.name, cp.building, cp.campus, cp.floor, cp.room,
        cp.status, cp.location, ul.geog
    ORDER BY
        ST_Distance(cp.location, ul.geog)
    LIMIT p_limit;
$$;

COMMENT ON FUNCTION get_nearest_collection_points IS
    'Retorna pontos ativos ordenados por distância. ST_DWithin usa índice GIST para filtro de raio; ST_Distance para ordenação precisa. Inclui total_stock para o pin do mapa.';


-- ------------------------------------------------------------
-- FUNCTION: has_user_withdrawn_today
-- Retorna TRUE se a usuária já fez uma retirada no dia atual.
-- Implementa a decisão do Fluxo 1: "A usuária já retirou
-- algum absorvente agora?"
--
-- Chamada pelo NestJS ANTES de inserir uma withdrawal transaction.
-- O intervalo usa CURRENT_DATE (meia-noite do dia corrente em UTC).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION has_user_withdrawn_today(
    p_user_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM transactions
        WHERE user_id = p_user_id
          AND type = 'withdrawal'
          AND created_at >= CURRENT_DATE
          AND created_at <  CURRENT_DATE + INTERVAL '1 day'
    );
$$;

COMMENT ON FUNCTION has_user_withdrawn_today IS
    'Retorna TRUE se a usuária já fez uma retirada hoje (desde meia-noite UTC). Chamada pelo NestJS antes de processar uma nova retirada.';


-- ------------------------------------------------------------
-- FUNCTION: is_stock_low
-- Retorna TRUE se o estoque está no limiar de alerta.
-- Chamada pelo NestJS APÓS processar uma retirada para
-- decidir se deve disparar alerta aos admins.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_stock_low(
    p_point_id  UUID,
    p_item_type menstrual_item_type
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT quantity <= min_quantity
    FROM inventory
    WHERE point_id = p_point_id
      AND item_type = p_item_type;
$$;

COMMENT ON FUNCTION is_stock_low IS
    'Retorna TRUE se quantity <= min_quantity para o ponto/produto. Chamada pelo NestJS após retiradas para acionar alerta de estoque baixo.';

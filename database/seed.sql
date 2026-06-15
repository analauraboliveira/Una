-- ============================================================
-- SEED DATA — Campus UFPE Recife
-- Para uso em ambientes de desenvolvimento e staging.
-- Coordenadas GPS aproximadas baseadas no campus UFPE Recife.
--
-- ATENÇÃO: Não executar em produção.
--
-- Pré-requisito: rows em auth.users com estes UUIDs devem
-- existir antes de executar. No Supabase local, crie via:
--   supabase auth admin createuser --email admin@una.ufpe.br ...
-- Ou inserir diretamente em auth.users no SQL Editor do dashboard.
-- ============================================================

DO $$
DECLARE
    -- UUIDs fixos para seed idempotente (FK-stable)
    v_admin1_id   UUID := '00000000-0000-0000-0000-000000000001';
    v_admin2_id   UUID := '00000000-0000-0000-0000-000000000002';
    v_student1_id UUID := '00000000-0000-0000-0000-000000000010';
    v_student2_id UUID := '00000000-0000-0000-0000-000000000011';

    v_point_cin_id       UUID;
    v_point_cac_id       UUID;
    v_point_bib_id       UUID;
    v_point_ccen_id      UUID;
    v_point_ctg_id       UUID;
BEGIN

    -- ----------------------------------------------------------
    -- PROFILES
    -- Assume que auth.users já tem rows com estes IDs.
    -- ----------------------------------------------------------
    INSERT INTO profiles (id, full_name, username, pronouns, role)
    VALUES
        (v_admin1_id,   'Ana Lima',         'analima_admin',   'ela/dela',  'admin'),
        (v_admin2_id,   'Carla Santos',     'carlasantos_adm', 'ela/dela',  'admin'),
        (v_student1_id, 'Maria Oliveira',   'mariaoli',        'ela/dela',  'student'),
        (v_student2_id, 'Fernanda Costa',   'fecosta',         'ela/ela',   'student')
    ON CONFLICT (id) DO NOTHING;

    -- ----------------------------------------------------------
    -- COLLECTION POINTS — Campus UFPE Recife
    -- ST_MakePoint(longitude, latitude) — longitude primeiro (PostGIS)
    -- ----------------------------------------------------------

    -- CIn — Centro de Informática
    INSERT INTO collection_points (name, building, campus, floor, room, location, status, created_by)
    VALUES (
        'Ponto CIn',
        'Centro de Informática (CIn)',
        'Recife',
        'Térreo',
        'Banheiro feminino — bloco A',
        ST_SetSRID(ST_MakePoint(-34.9524, -8.0536), 4326),
        'active',
        v_admin1_id
    ) RETURNING id INTO v_point_cin_id;

    -- CAC — Centro de Artes e Comunicação
    INSERT INTO collection_points (name, building, campus, floor, room, location, status, created_by)
    VALUES (
        'Ponto CAC',
        'Centro de Artes e Comunicação (CAC)',
        'Recife',
        '1º andar',
        'Banheiro feminino — bloco B',
        ST_SetSRID(ST_MakePoint(-34.9545, -8.0509), 4326),
        'active',
        v_admin1_id
    ) RETURNING id INTO v_point_cac_id;

    -- Biblioteca Central
    INSERT INTO collection_points (name, building, campus, floor, room, location, status, created_by)
    VALUES (
        'Ponto Biblioteca Central',
        'Biblioteca Central',
        'Recife',
        'Térreo',
        'Banheiro feminino — entrada principal',
        ST_SetSRID(ST_MakePoint(-34.9502, -8.0522), 4326),
        'active',
        v_admin2_id
    ) RETURNING id INTO v_point_bib_id;

    -- CCEN — Centro de Ciências Exatas e da Natureza
    INSERT INTO collection_points (name, building, campus, floor, room, location, status, created_by)
    VALUES (
        'Ponto CCEN',
        'Centro de Ciências Exatas e da Natureza (CCEN)',
        'Recife',
        '2º andar',
        'Banheiro feminino — ala leste',
        ST_SetSRID(ST_MakePoint(-34.9491, -8.0548), 4326),
        'active',
        v_admin2_id
    ) RETURNING id INTO v_point_ccen_id;

    -- CTG — Centro de Tecnologia e Geociências (em manutenção para testar o status)
    INSERT INTO collection_points (name, building, campus, floor, room, location, status, created_by)
    VALUES (
        'Ponto CTG',
        'Centro de Tecnologia e Geociências (CTG)',
        'Recife',
        'Térreo',
        'Banheiro feminino — bloco A',
        ST_SetSRID(ST_MakePoint(-34.9470, -8.0556), 4326),
        'maintenance',
        v_admin1_id
    ) RETURNING id INTO v_point_ctg_id;

    -- ----------------------------------------------------------
    -- INVENTORY — Estoque inicial por ponto
    -- Alguns pontos intencionalmente com estoque baixo ou zerado
    -- para facilitar testes de alerta e de bloqueio de retirada.
    -- ----------------------------------------------------------
    INSERT INTO inventory (point_id, item_type, quantity, min_quantity)
    VALUES
        -- CIn: estoque normal
        (v_point_cin_id,  'pad',         20, 5),
        (v_point_cin_id,  'tampon',      10, 3),
        (v_point_cin_id,  'panty_liner', 15, 3),

        -- CAC: tampão zerado (testa alerta de estoque vazio)
        (v_point_cac_id,  'pad',         12, 5),
        (v_point_cac_id,  'tampon',       0, 3),
        (v_point_cac_id,  'panty_liner',  8, 3),

        -- Biblioteca: estoque normal
        (v_point_bib_id,  'pad',         25, 5),
        (v_point_bib_id,  'tampon',       5, 3),
        (v_point_bib_id,  'panty_liner', 10, 3),

        -- CCEN: absorvente abaixo do mínimo (testa is_stock_low)
        (v_point_ccen_id, 'pad',          3, 5),
        (v_point_ccen_id, 'tampon',       7, 3),
        (v_point_ccen_id, 'panty_liner',  4, 3),

        -- CTG: zerado (em manutenção — não visível para estudantes)
        (v_point_ctg_id,  'pad',          0, 5),
        (v_point_ctg_id,  'tampon',       0, 3),
        (v_point_ctg_id,  'panty_liner',  0, 3)
    ON CONFLICT (point_id, item_type) DO UPDATE
        SET quantity     = EXCLUDED.quantity,
            min_quantity = EXCLUDED.min_quantity;

    -- ----------------------------------------------------------
    -- SAMPLE TRANSACTIONS — Doações e retiradas de exemplo
    -- Nota: triggers ajustarão inventory automaticamente.
    -- ----------------------------------------------------------
    INSERT INTO transactions (type, user_id, point_id, item_type, quantity, notes)
    VALUES
        ('donation',   v_student1_id, v_point_cin_id,  'pad',         5, 'Doação da turma de CC 2024.1'),
        ('withdrawal', v_student2_id, v_point_cac_id,  'pad',         1, NULL),
        ('withdrawal', v_student1_id, v_point_bib_id,  'panty_liner', 1, NULL),
        ('donation',   v_student2_id, v_point_ccen_id, 'tampon',      3, NULL);

    -- ----------------------------------------------------------
    -- SAMPLE FEEDBACKS — Problemas relatados
    -- Triggers criarão notificações para os admins automaticamente.
    -- ----------------------------------------------------------
    INSERT INTO feedbacks (point_id, submitted_by, category, is_specific, description, status)
    VALUES
        (v_point_cac_id,  v_student2_id, 'empty_stock',  FALSE, NULL,
         'pending'),
        (v_point_ccen_id, v_student1_id, 'inaccessible', FALSE, NULL,
         'in_progress'),
        (v_point_cin_id,  v_student1_id, 'other',        TRUE,
         'A torneira do banheiro está com vazamento, dificultando o acesso.',
         'pending');

END $$;

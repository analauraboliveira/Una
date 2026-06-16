-- ============================================================
-- MIGRATION 002: Enum Types
-- Enums enforce valid values at the DB level without extra joins.
-- Used for closed, stable value sets.
-- ============================================================

-- Roles de usuária na plataforma
CREATE TYPE user_role AS ENUM (
    'student',  -- Estudante da UFPE (usuária padrão)
    'admin'     -- Administrador do sistema
);

-- Estado operacional de um ponto de coleta
CREATE TYPE collection_point_status AS ENUM (
    'active',       -- Aceitando retiradas e doações — visível no mapa
    'inactive',     -- Desativado, não visível para estudantes
    'maintenance'   -- Temporariamente indisponível, visível mas bloqueado
);

-- Tipo de produto menstrual rastreado no estoque / transações
-- Expansível via: ALTER TYPE menstrual_item_type ADD VALUE 'new_value';
CREATE TYPE menstrual_item_type AS ENUM (
    'pad',          -- Absorvente externo comum
    'tampon',       -- Absorvente interno
    'panty_liner'   -- Protetor diário
);

-- Direção de uma movimentação de estoque
CREATE TYPE transaction_type AS ENUM (
    'withdrawal',   -- Estudante retira 1 produto (limite: 1 por dia)
    'donation'      -- Estudante ou doador adiciona produtos
);

-- Categoria do feedback enviado pela estudante
-- Mapeia para o fluxo COMUM (opções pré-definidas) e ESPECÍFICO (other + descrição livre)
CREATE TYPE feedback_category AS ENUM (
    'empty_stock',   -- Estoque esgotado
    'damaged',       -- Ponto danificado ou produto com problema
    'inaccessible',  -- Ponto inacessível (banheiro fechado, etc.)
    'other'          -- Específico — acompanhado de description livre
);

-- Estado do ciclo de vida de um feedback
CREATE TYPE feedback_status AS ENUM (
    'pending',      -- Recém enviado, aguardando análise
    'in_progress',  -- Admin em análise ou resolução
    'resolved'      -- Problema resolvido
);

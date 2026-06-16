-- ============================================================
-- AUTH MOCK — apenas para desenvolvimento local com Docker.
-- Em produção (Supabase), o schema auth é gerenciado pelo
-- Supabase Auth e este arquivo NÃO deve ser executado.
--
-- Simula o mínimo necessário do schema auth.* do Supabase:
--   - auth.users: tabela de usuários
--   - auth.uid(): retorna o UUID do usuário logado (NULL em testes locais)
--   - auth.role(): retorna o role da sessão
--   - auth.jwt(): retorna o JWT claims
--
-- Para testar com RLS localmente, conecte como superuser (postgres)
-- — o superuser bypassa RLS automaticamente.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS auth;

-- Tabela mínima de users do Supabase Auth
-- O trigger handle_new_user (migration 006) dispara ao inserir aqui.
CREATE TABLE IF NOT EXISTS auth.users (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email               TEXT UNIQUE,
    encrypted_password  TEXT,
    raw_user_meta_data  JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- auth.uid(): no Supabase, retorna o UUID do JWT da sessão atual.
-- Localmente retorna NULL (sem sessão). Para testes, use:
--   SET LOCAL "request.jwt.claims" TO '{"sub": "<uuid>"}';
--   e ajuste esta função para: SELECT (current_setting('request.jwt.claims', TRUE)::JSONB->>'sub')::UUID
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claim.sub', TRUE), ''),
        NULL
    )::UUID;
$$;

-- auth.role(): no Supabase, retorna 'authenticated' ou 'anon'.
-- Localmente retorna 'authenticated' para simplificar testes.
CREATE OR REPLACE FUNCTION auth.role()
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claim.role', TRUE), ''),
        'authenticated'
    )::TEXT;
$$;

-- auth.jwt(): retorna os claims do JWT como JSONB.
CREATE OR REPLACE FUNCTION auth.jwt()
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        NULLIF(current_setting('request.jwt.claims', TRUE), ''),
        '{}'
    )::JSONB;
$$;

@AGENTS.md

# Projeto Una — Guia do Codebase

Plataforma de saúde menstrual para estudantes da UFPE (CIn).
Permite localizar pontos de coleta de produtos menstruais no campus, realizar retiradas e doações, e relatar problemas.

## Repositórios e Responsabilidades

| Camada | Tecnologia | Localização |
|---|---|---|
| Frontend Web (Admin) | Next.js 16 + TailwindCSS | `frontend-web/` — **este repo** |
| Frontend Mobile | React Native (Expo) | repo separado |
| Backend API | Node.js + NestJS | repo separado |
| Banco de Dados | PostgreSQL + PostGIS (Supabase) | `database/` |

## Banco de Dados — PostgreSQL + PostGIS no Supabase

### Visão Geral

- **6 tabelas** no schema `public`
- **Autenticação:** Supabase Auth (substitui Firebase Auth)
- **Geolocalização:** PostGIS `GEOGRAPHY(POINT, 4326)` — distâncias em metros nativamente
- **Segurança:** RLS habilitado em todas as tabelas (zero-trust)
- **Docs completos:** `docs/database-schema.md`

### Estrutura de Arquivos

```
database/
├── migrations/
│   ├── 001_extensions.sql          — PostGIS, pgcrypto, uuid-ossp
│   ├── 002_types.sql               — 6 enums
│   ├── 003_tables.sql              — 6 tabelas com constraints
│   ├── 004_indexes.sql             — GIST (spatial) + B-tree
│   ├── 005_rls_policies.sql        — Row Level Security
│   └── 006_functions_and_triggers.sql — Triggers + funções RPC
└── seed.sql                        — 5 pontos UFPE Recife (dev/staging)
docs/
└── database-schema.md              — Documentação completa
frontend-web/src/types/
└── database.ts                     — Tipos TypeScript do schema
```

### Tabelas

#### `profiles`
Extensão 1:1 de `auth.users`. Criada automaticamente via trigger no sign-up.

| Campo | Tipo | Nota |
|---|---|---|
| `id` | UUID PK → auth.users | Mesmo ID do Supabase Auth |
| `full_name` | TEXT NOT NULL | |
| `username` | TEXT UNIQUE NOT NULL | |
| `pronouns` | TEXT | Livre: ela/dela, elu/delu... |
| `role` | `user_role` | `student` (default) \| `admin` |
| `age` | SMALLINT | Dado sensível — protegido por RLS |
| `cycle_duration_days` | SMALLINT (1–90) | Dado sensível — protegido por RLS |
| `menstruation_duration_days` | SMALLINT (1–30) | Dado sensível — protegido por RLS |
| `avatar_url` | TEXT | URL no Supabase Storage |

#### `collection_points`
Pontos físicos de coleta no campus.

| Campo | Tipo | Nota |
|---|---|---|
| `id` | UUID PK | |
| `name` | TEXT NOT NULL | Ex: "Ponto CIn" |
| `building` | TEXT NOT NULL | Ex: "Centro de Informática (CIn)" |
| `campus` | TEXT DEFAULT 'Recife' | Expansível para outros campi |
| `floor` | TEXT | |
| `room` | TEXT | |
| `location` | `GEOGRAPHY(POINT, 4326)` | **longitude primeiro** — PostGIS convention |
| `status` | `collection_point_status` | `active` \| `inactive` \| `maintenance` |
| `created_by` | UUID → profiles | |

> **Atenção:** PostGIS usa `ST_MakePoint(longitude, latitude)` — ordem inversa ao padrão falado.

#### `inventory`
Estoque por ponto por tipo de produto.

| Campo | Tipo | Nota |
|---|---|---|
| `point_id` | UUID FK → collection_points | |
| `item_type` | `menstrual_item_type` | `pad` \| `tampon` \| `panty_liner` |
| `quantity` | INTEGER CHECK (≥0) | |
| `min_quantity` | INTEGER DEFAULT 5 | Limiar de alerta de estoque baixo |
| UNIQUE | (point_id, item_type) | Um row por tipo por ponto |

> **Regra crítica:** Nunca escrever em `inventory` diretamente. Sempre INSERT em `transactions` — o trigger ajusta o estoque.

#### `transactions`
Log imutável de retiradas e doações.

| Campo | Tipo | Nota |
|---|---|---|
| `type` | `transaction_type` | `withdrawal` \| `donation` |
| `user_id` | UUID FK → profiles RESTRICT | |
| `point_id` | UUID FK → collection_points RESTRICT | |
| `item_type` | `menstrual_item_type` | |
| `quantity` | INTEGER CHECK | **Retirada: sempre 1** (enforced por CHECK) |
| `created_at` | TIMESTAMPTZ | Usado por `has_user_withdrawn_today()` |

> Sem UPDATE/DELETE policy — rows são imutáveis (auditoria).

#### `feedbacks`
Relatos de problemas (Fluxo 3: COMUM vs ESPECÍFICO).

| Campo | Tipo | Nota |
|---|---|---|
| `category` | `feedback_category` | `empty_stock` \| `damaged` \| `inaccessible` \| `other` |
| `is_specific` | BOOLEAN | TRUE = texto livre (ESPECÍFICO), FALSE = categoria pré-definida (COMUM) |
| `description` | TEXT | Obrigatório quando `is_specific = TRUE` |
| `status` | `feedback_status` | `pending` → `in_progress` → `resolved` |
| `resolved_by` | UUID → profiles | Admin que resolveu |

#### `notifications`
Notificações in-app para admins (geradas por trigger).
Habilitar **Supabase Realtime** nesta tabela para alertas em tempo real no painel.

### Enums

| Tipo | Valores |
|---|---|
| `user_role` | `student`, `admin` |
| `collection_point_status` | `active`, `inactive`, `maintenance` |
| `menstrual_item_type` | `pad`, `tampon`, `panty_liner` |
| `transaction_type` | `withdrawal`, `donation` |
| `feedback_category` | `empty_stock`, `damaged`, `inaccessible`, `other` |
| `feedback_status` | `pending`, `in_progress`, `resolved` |

### Funções RPC (chamadas pela aplicação)

```typescript
// Pontos mais próximos do usuário (app móvel)
supabase.rpc('get_nearest_collection_points', { p_lat, p_lng, p_radius_m: 2000 })

// Verifica limite diário de retirada (NestJS — antes de inserir)
supabase.rpc('has_user_withdrawn_today', { p_user_id })

// Verifica se estoque está baixo (NestJS — após retirada)
supabase.rpc('is_stock_low', { p_point_id, p_item_type })
```

### Triggers automáticos

| Trigger | Quando | Efeito |
|---|---|---|
| `on_auth_user_created` | Sign-up no Supabase Auth | Cria row em `profiles` automaticamente |
| `on_transaction_insert` | INSERT em `transactions` | Ajusta `inventory.quantity` com SELECT FOR UPDATE |
| `on_feedback_insert` | INSERT em `feedbacks` | Cria `notifications` para todos os admins |
| `*_updated_at` | UPDATE em profiles/collection_points/feedbacks | Atualiza `updated_at` |

### Como Aplicar as Migrations no Supabase

Executar em ordem no SQL Editor do dashboard:

```
001_extensions.sql → 002_types.sql → 003_tables.sql
→ 004_indexes.sql → 005_rls_policies.sql → 006_functions_and_triggers.sql
```

Depois para dados de teste: `seed.sql`

### Tipos TypeScript

```typescript
import { createClient } from '@supabase/supabase-js'
import type { Database } from '@/types/database'

const supabase = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)
```

## Variáveis de Ambiente Necessárias

Ver seção abaixo — arquivo `.env.local` na raiz de `frontend-web/`.

## Regras de Negócio Críticas

1. **Limite de retirada:** 1 item por usuária por dia — enforced por `has_user_withdrawn_today()` + CHECK constraint
2. **Estoque:** nunca escrever em `inventory` diretamente — sempre via `transactions`
3. **Concorrência:** o trigger usa `SELECT FOR UPDATE` para serializar retiradas simultâneas
4. **RLS:** estudante vê apenas pontos `active` e seus próprios dados; admin vê tudo

# Una — Documentação do Banco de Dados

## Visão Geral

O banco de dados do Una roda em **PostgreSQL 15+** com a extensão **PostGIS**, hospedado no **Supabase**. A autenticação é gerenciada pelo **Supabase Auth** (`auth.users`). Todas as tabelas da aplicação ficam no schema `public`.

---

## Por que cada escolha tecnológica foi feita

| Concern | Escolha | Motivo |
|---|---|---|
| Banco principal | PostgreSQL + Supabase | ACID garante integridade em retiradas concorrentes |
| Geolocalização | PostGIS `GEOGRAPHY(POINT, 4326)` | Distâncias em metros nativamente, sem conversão de graus |
| Autenticação | Supabase Auth (substitui Firebase) | Sistema único — elimina dependência externa redundante |
| Controle de acesso | RLS em todas as tabelas | Zero-trust: nenhum acesso implícito |
| Concorrência | `SELECT FOR UPDATE` no trigger | Lock a nível de row — proof contra race conditions em retiradas |
| Imutabilidade de logs | Sem UPDATE/DELETE policy em transactions | Log de auditoria protegido no banco, não apenas na aplicação |

---

## Diagrama de Entidades

```
auth.users (Supabase Auth — gerenciado)
    │ 1:1 (trigger handle_new_user)
    ▼
profiles ──(created_by)──► collection_points
    │                            │ 1:N
    │ (user_id)          ┌───────┤
    ▼                    ▼       ▼
transactions         feedbacks  inventory
                        │
                        │ (feedback_id)
                        ▼
                   notifications ◄──(recipient_id)── profiles[role=admin]
```

---

## Tabelas

### `profiles`
Extensão 1:1 de `auth.users`. Criada automaticamente pelo trigger `handle_new_user` no sign-up.

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | UUID PK → auth.users | Mesmo ID do Supabase Auth |
| `full_name` | TEXT NOT NULL | Nome completo (formulário de cadastro) |
| `username` | TEXT UNIQUE NOT NULL | Nome de usuário único |
| `pronouns` | TEXT | Pronomes livres (ela/dela, elu/delu...) |
| `role` | `user_role` | `student` (default) ou `admin` |
| `age` | SMALLINT | Idade informada no cadastro |
| `cycle_duration_days` | SMALLINT | Duração média do ciclo menstrual (dias) |
| `menstruation_duration_days` | SMALLINT | Duração média da menstruação (dias) |
| `avatar_url` | TEXT | URL da foto no Supabase Storage |

**Dado sensível:** `age`, `cycle_duration_days`, `menstruation_duration_days` são protegidos por RLS — só a própria usuária e admins leem.

---

### `collection_points`
Pontos físicos no campus UFPE onde estudantes retiram e depositam produtos.

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | UUID PK | |
| `name` | TEXT NOT NULL | Ex: "Ponto CIn" |
| `building` | TEXT NOT NULL | Ex: "Centro de Informática (CIn)" |
| `campus` | TEXT DEFAULT 'Recife' | Preparado para expansão |
| `floor` | TEXT | Ex: "Térreo", "2º andar" |
| `room` | TEXT | Ex: "Banheiro feminino bloco A" |
| `location` | `GEOGRAPHY(POINT, 4326)` | Coordenadas GPS — **longitude primeiro** |
| `status` | `collection_point_status` | `active` / `inactive` / `maintenance` |
| `created_by` | UUID → profiles | Admin que cadastrou |

**Atenção à convenção de coordenadas:** PostGIS usa `POINT(longitude latitude)` — ordem inversa ao padrão falado. Sempre `ST_MakePoint(lng, lat)`.

---

### `inventory`
Estoque por ponto por tipo de produto.

| Campo | Tipo | Descrição |
|---|---|---|
| `point_id` + `item_type` | UNIQUE | Um row por tipo por ponto |
| `quantity` | INTEGER ≥ 0 | Quantidade atual |
| `min_quantity` | INTEGER DEFAULT 5 | Limiar de alerta de estoque baixo |

**Regra de ouro:** Nunca escrever diretamente. Sempre inserir em `transactions` — o trigger `adjust_inventory_on_transaction` atualiza atomicamente.

---

### `transactions`
Log imutável de todas as retiradas e doações.

| Campo | Tipo | Descrição |
|---|---|---|
| `type` | `transaction_type` | `withdrawal` ou `donation` |
| `user_id` | UUID → profiles RESTRICT | Quem fez |
| `point_id` | UUID → collection_points RESTRICT | Onde ocorreu |
| `item_type` | `menstrual_item_type` | O que foi movimentado |
| `quantity` | INTEGER CHECK | **Retirada: sempre 1** (CHECK constraint) |
| `created_at` | TIMESTAMPTZ | Usado para verificar limite diário |

**Imutabilidade:** Não há policy de UPDATE ou DELETE — rows de `transactions` nunca podem ser alterados.

---

### `feedbacks`
Relatos de problemas enviados pelas estudantes (Fluxo 3).

| Campo | Tipo | Descrição |
|---|---|---|
| `category` | `feedback_category` | Categoria pré-definida (fluxo COMUM) |
| `is_specific` | BOOLEAN | TRUE = problema ESPECÍFICO (texto livre) |
| `description` | TEXT | Obrigatório quando `is_specific = TRUE` |
| `status` | `feedback_status` | `pending` → `in_progress` → `resolved` |
| `resolved_by` | UUID → profiles | Admin que resolveu |
| `resolved_at` | TIMESTAMPTZ | Data/hora da resolução |

**Constraint de integridade:** `resolved_fields_consistent` impede `status='resolved'` sem `resolved_by` e `resolved_at` preenchidos simultaneamente.

---

### `notifications`
Notificações in-app para admins, geradas automaticamente.

| Campo | Tipo | Descrição |
|---|---|---|
| `recipient_id` | UUID → profiles | Admin destinatário |
| `feedback_id` | UUID → feedbacks | Feedback que gerou a notificação |
| `read_at` | TIMESTAMPTZ | NULL = não lida |

Habilitar **Supabase Realtime** nesta tabela para o painel Next.js receber alertas sem polling.

---

## Enums

| Tipo | Valores |
|---|---|
| `user_role` | `student`, `admin` |
| `collection_point_status` | `active`, `inactive`, `maintenance` |
| `menstrual_item_type` | `pad`, `tampon`, `panty_liner` |
| `transaction_type` | `withdrawal`, `donation` |
| `feedback_category` | `empty_stock`, `damaged`, `inaccessible`, `other` |
| `feedback_status` | `pending`, `in_progress`, `resolved` |

---

## Triggers e Funções

### Triggers automáticos

| Trigger | Tabela | Quando | Função |
|---|---|---|---|
| `on_auth_user_created` | `auth.users` | AFTER INSERT | `handle_new_user()` — cria `profiles` |
| `profiles_updated_at` | `profiles` | BEFORE UPDATE | `update_updated_at_column()` |
| `collection_points_updated_at` | `collection_points` | BEFORE UPDATE | `update_updated_at_column()` |
| `feedbacks_updated_at` | `feedbacks` | BEFORE UPDATE | `update_updated_at_column()` |
| `on_transaction_insert` | `transactions` | AFTER INSERT | `adjust_inventory_on_transaction()` |
| `on_feedback_insert` | `feedbacks` | AFTER INSERT | `notify_admins_on_feedback()` |

### Funções RPC (chamadas pela aplicação)

#### `get_nearest_collection_points(p_lat, p_lng, p_radius_m?, p_limit?)`
Retorna pontos ativos ordenados por distância. Chamada pelo app React Native:

```typescript
const { data } = await supabase.rpc('get_nearest_collection_points', {
  p_lat: coords.latitude,
  p_lng: coords.longitude,
  p_radius_m: 2000,
  p_limit: 10,
});
```

#### `has_user_withdrawn_today(p_user_id)`
Retorna `TRUE` se a usuária já fez uma retirada hoje. Chamada pelo NestJS antes de processar uma nova retirada:

```typescript
const { data: alreadyWithdrew } = await supabase
  .rpc('has_user_withdrawn_today', { p_user_id: userId });

if (alreadyWithdrew) throw new ConflictException('Limite diário atingido');
```

#### `is_stock_low(p_point_id, p_item_type)`
Retorna `TRUE` se `quantity <= min_quantity`. Chamada pelo NestJS após uma retirada para decidir se dispara alerta:

```typescript
const { data: lowStock } = await supabase
  .rpc('is_stock_low', { p_point_id: pointId, p_item_type: itemType });

if (lowStock) await notifyAdminsLowStock(pointId, itemType);
```

---

## Matriz RLS

| Tabela | Estudante SELECT | Estudante INSERT | Estudante UPDATE | Admin |
|---|---|---|---|---|
| profiles | Própria linha | Própria linha | Própria (sem troca de role) | Todas |
| collection_points | Somente `active` | Não | Não | Total |
| inventory | Todas | Não | Não | Total |
| transactions | Próprias | Próprias (`user_id = auth.uid()`) | Não (imutável) | Todas |
| feedbacks | Próprias | Próprias | Não | Total |
| notifications | Próprias | Não | Próprias (`read_at`) | Total |

---

## Modelo de Concorrência (Retiradas)

O sistema usa 4 camadas de proteção para garantir que duas estudantes não consomem o mesmo item simultaneamente:

```
1. App React Native  → Desabilita botão "Retirar" se estoque = 0 (UX)
2. NestJS backend    → Valida estoque antes de inserir (otimização)
3. DB trigger        → SELECT FOR UPDATE no row de inventory (LOCK real)
4. DB CHECK          → quantity >= 0 (backstop final)
```

Apenas a camada 3 é verdadeiramente concorrência-safe. As camadas 1 e 2 reduzem round-trips no caminho feliz.

---

## Ordem de Aplicação das Migrations

```bash
# No SQL Editor do Supabase ou via Supabase CLI:
001_extensions.sql          # PostGIS, pgcrypto, uuid-ossp
002_types.sql               # CREATE TYPE enums
003_tables.sql              # CREATE TABLE com constraints
004_indexes.sql             # Índices B-tree e GIST
005_rls_policies.sql        # Row Level Security
006_functions_and_triggers.sql  # Lógica de negócio
```

Cada arquivo é idempotente (`CREATE ... IF NOT EXISTS`, `CREATE OR REPLACE`).

---

## Convenção de Coordenadas

PostGIS sempre usa `POINT(longitude latitude)` (X=longitude, Y=latitude) — ordem inversa ao padrão falado.

```sql
-- CORRETO:
ST_MakePoint(-34.9524, -8.0536)  -- MakePoint(longitude, latitude)

-- ERRADO (produz coordenadas incorretas silenciosamente):
ST_MakePoint(-8.0536, -34.9524)  -- latitude primeiro
```

A função `get_nearest_collection_points` recebe `p_lat` e `p_lng` em ordem humana e faz a inversão internamente.

---

## Habilitando Supabase Realtime

Para o painel web (Next.js) receber notificações em tempo real:

1. Supabase Dashboard → Database → Replication
2. Habilitar a tabela `notifications`
3. No frontend:

```typescript
supabase
  .channel('admin-notifications')
  .on(
    'postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'notifications',
      filter: `recipient_id=eq.${adminId}` },
    (payload) => showNotification(payload.new)
  )
  .subscribe();
```

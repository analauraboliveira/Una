# Pendências — Una Web (frontend-web)

O mapa de pontos já carrega corretamente via RPC PostGIS.
Os itens abaixo são o que falta para o painel web estar funcional como ferramenta de administração.

---

## P1 — Popup do mapa não exibe estoque

**Arquivo:** `frontend-web/src/app/components/MapaUfpe.tsx`

O popup que aparece ao clicar em um marcador mostra apenas `sigla` e `nome`. O `page.tsx` já passa o campo `qtd` (estoque total) mas o componente não o exibe.

**Como resolver:**

No tipo `CentroUFPE` e no `<Popup>`:

```tsx
type CentroUFPE = {
  id: string;   // era number — UUIDs são string
  nome: string;
  sigla: string;
  lat: number;
  lon: number;
  qtd: number;  // adicionar
};

// No Popup:
<Popup>
  <div className="text-center">
    <strong className="text-blue-600 text-lg">{centro.sigla}</strong>
    <br />
    <span className="text-gray-700">{centro.nome}</span>
    <br />
    <span className="text-sm font-semibold text-pink-600">Estoque: {centro.qtd}</span>
  </div>
</Popup>
```

---

## P2 — Painel admin não existe (só o mapa público)

O backend (`anaraque-l/una-backend`) tem endpoints admin completos:

```
GET  /admin/feedbacks                  — todos os relatos
PATCH /admin/feedbacks/:id             — atualizar status do relato
GET  /admin/collection-points          — todos os pontos (incluindo inativos)
PATCH /admin/collection-points/:id     — editar dados/status do ponto
```

O frontend web deve ser o painel de administração. Atualmente é apenas um mapa público sem nenhuma funcionalidade de gestão.

**O que precisa ser criado:**

- Página de login para admins (`/login`)
- Listagem de relatos (`/feedbacks`) com botões de atualizar status
- Listagem e edição de pontos de coleta (`/pontos`)
- Autenticação via `POST /auth/login` do backend (retorna JWT)
- Todas as chamadas admin precisam do header `Authorization: Bearer <token>`

---

## P3 — Autenticação não implementada no web

Relacionado ao P2. Sem login, qualquer pessoa pode acessar o painel.

**Como implementar:**

A forma mais simples é usar o cliente Supabase diretamente para autenticação no web (já que o RLS protege os dados), ou chamar o backend:

```ts
// Opção recomendada: chamar o backend
const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password }),
})
const { access_token } = await res.json()
// salvar em cookie httpOnly ou sessionStorage
```

Variável de ambiente nova necessária no `.env.local`:
```
NEXT_PUBLIC_API_URL=http://localhost:3000
```

---

## P4 — Supabase Realtime nas notificações não está ativado

**Onde ativar:** Dashboard Supabase → Database → Replication → habilitar `notifications`

O banco tem trigger `notify_admins_on_feedback` que insere em `notifications` a cada novo relato.
Para que o painel admin receba alertas em tempo real (sem precisar recarregar a página), o Realtime precisa estar ativo nessa tabela.

**Código para escutar no frontend:**

```ts
supabase
  .channel('admin-notifications')
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' }, (payload) => {
    // exibir toast/badge com o novo relato
    console.log('Novo relato:', payload.new)
  })
  .subscribe()
```

---

## P5 — Arquivo supabase.ts duplicado

**Arquivos:**
- `frontend-web/src/app/lib/supabase.ts` — usado por `page.tsx`
- `frontend-web/src/lib/supabase.ts` — parece não ser usado por ninguém

**Como resolver:**

Verificar se `src/lib/supabase.ts` tem algum import apontando para ele. Se não tiver, remover. Manter apenas `src/app/lib/supabase.ts`.

---

## P6 — Variáveis de ambiente (.env.local ausente)

O `frontend-web/` precisa de um `.env.local` (nunca commitar):

```
NEXT_PUBLIC_SUPABASE_URL=https://<seu-projeto>.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=sb_publishable_...
NEXT_PUBLIC_API_URL=http://localhost:3000
```

O arquivo `.env.example` existe no repo raiz mas não dentro de `frontend-web/`. Criar um `frontend-web/.env.example` ajuda quem for subir o projeto pela primeira vez.

---

## Deploy (Vercel — mais simples)

1. Conectar o repo `analauraboliveira/Una` na Vercel
2. Definir **Root Directory** como `frontend-web`
3. Adicionar as variáveis de ambiente no painel da Vercel
4. Deploy automático a cada push na `main`

---

## Resumo

| # | Pendência | Impacto |
|---|---|---|
| P1 | Popup sem estoque | Informação útil faltando no mapa |
| P2 | Painel admin não existe | Funcionalidade principal do web |
| P3 | Sem autenticação | Qualquer um acessa o painel |
| P4 | Realtime não ativado | Admins não recebem alertas de relatos |
| P5 | supabase.ts duplicado | Limpeza de código |
| P6 | .env.local ausente | Setup local não funciona sem criar manualmente |

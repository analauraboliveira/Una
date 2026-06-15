// ============================================================
// Tipos TypeScript do Banco de Dados — Projeto Una
//
// Espelha exatamente o schema PostgreSQL definido em
// database/migrations/002_types.sql e 003_tables.sql.
//
// Uso com Supabase client tipado:
//   import { createClient } from '@supabase/supabase-js'
//   import type { Database } from '@/types/database'
//   const supabase = createClient<Database>(url, key)
//
// Para manter em sincronia com o schema ao longo do tempo,
// considere usar: supabase gen types typescript --local
// ============================================================


// ============================================================
// Enums
// ============================================================

export type UserRole = 'student' | 'admin'

export type CollectionPointStatus = 'active' | 'inactive' | 'maintenance'

export type MenstrualItemType = 'pad' | 'tampon' | 'panty_liner'

export type TransactionType = 'withdrawal' | 'donation'

/** Categorias do fluxo COMUM. Fluxo ESPECÍFICO usa 'other' + description livre */
export type FeedbackCategory = 'empty_stock' | 'damaged' | 'inaccessible' | 'other'

export type FeedbackStatus = 'pending' | 'in_progress' | 'resolved'


// ============================================================
// Row Types — um row completo retornado por SELECT *
// ============================================================

export interface ProfileRow {
  id: string                          // UUID — mesmo que auth.users.id
  full_name: string
  username: string
  pronouns: string | null
  role: UserRole
  age: number | null
  cycle_duration_days: number | null
  menstruation_duration_days: number | null
  avatar_url: string | null
  created_at: string                  // ISO 8601 com timezone
  updated_at: string
}

export interface CollectionPointRow {
  id: string
  name: string
  building: string
  campus: string
  floor: string | null
  room: string | null
  /** PostGIS GEOGRAPHY serializado como GeoJSON pelo Supabase */
  location: GeoJSONPoint
  status: CollectionPointStatus
  created_by: string | null
  created_at: string
  updated_at: string
}

export interface InventoryRow {
  id: string
  point_id: string
  item_type: MenstrualItemType
  quantity: number
  min_quantity: number
  last_updated_at: string
}

export interface TransactionRow {
  id: string
  type: TransactionType
  user_id: string
  point_id: string
  item_type: MenstrualItemType
  /** Sempre 1 para retiradas (enforced por CHECK no banco) */
  quantity: number
  notes: string | null
  created_at: string
}

export interface FeedbackRow {
  id: string
  point_id: string
  submitted_by: string
  category: FeedbackCategory
  /** TRUE = problema ESPECÍFICO (texto livre). FALSE = COMUM (categoria pré-definida) */
  is_specific: boolean
  description: string | null
  status: FeedbackStatus
  resolved_by: string | null
  resolved_at: string | null
  created_at: string
  updated_at: string
}

export interface NotificationRow {
  id: string
  recipient_id: string
  feedback_id: string | null
  title: string
  body: string
  read_at: string | null
  created_at: string
}


// ============================================================
// Insert Types — campos necessários/opcionais no INSERT
// ============================================================

export interface InsertProfile {
  id: string                          // Deve ser igual a auth.uid()
  full_name: string
  username: string
  pronouns?: string | null
  role?: UserRole
  age?: number | null
  cycle_duration_days?: number | null
  menstruation_duration_days?: number | null
  avatar_url?: string | null
}

export interface InsertCollectionPoint {
  name: string
  building: string
  campus?: string
  floor?: string | null
  room?: string | null
  /** GeoJSON Point ou WKT. Ex: { type: 'Point', coordinates: [lng, lat] } */
  location: GeoJSONPoint | string
  status?: CollectionPointStatus
  created_by?: string | null
}

export interface InsertInventory {
  point_id: string
  item_type: MenstrualItemType
  quantity?: number
  min_quantity?: number
}

export interface InsertTransaction {
  type: TransactionType
  user_id: string                     // Deve ser igual a auth.uid()
  point_id: string
  item_type: MenstrualItemType
  /** Default 1. Retiradas DEVEM ser 1 (enforced pelo banco) */
  quantity?: number
  notes?: string | null
}

export interface InsertFeedback {
  point_id: string
  submitted_by: string                // Deve ser igual a auth.uid()
  category: FeedbackCategory
  /** TRUE para problema ESPECÍFICO com descrição livre */
  is_specific?: boolean
  description?: string | null
}


// ============================================================
// Update Types — apenas campos mutáveis
// ============================================================

export interface UpdateProfile {
  full_name?: string
  username?: string
  pronouns?: string | null
  age?: number | null
  cycle_duration_days?: number | null
  menstruation_duration_days?: number | null
  avatar_url?: string | null
  // role excluído: usuárias não podem se auto-promover
}

export interface UpdateCollectionPoint {
  name?: string
  building?: string
  campus?: string
  floor?: string | null
  room?: string | null
  location?: GeoJSONPoint | string
  status?: CollectionPointStatus
}

export interface UpdateFeedback {
  status?: FeedbackStatus
  resolved_by?: string | null
  resolved_at?: string | null
}

export interface UpdateNotification {
  read_at?: string | null             // Marcar como lida
}


// ============================================================
// Utility Types
// ============================================================

/** GeoJSON Point como retornado pelo PostGIS via Supabase */
export interface GeoJSONPoint {
  type: 'Point'
  coordinates: [longitude: number, latitude: number]
}

/** Retorno da função get_nearest_collection_points() */
export interface NearestCollectionPoint {
  id: string
  name: string
  building: string
  campus: string
  floor: string | null
  room: string | null
  status: CollectionPointStatus
  distance_meters: number
  latitude: number
  longitude: number
  total_stock: number
}

/** Inventory com indicador de estoque baixo (via is_stock_low()) */
export interface InventoryWithAlert extends InventoryRow {
  is_low_stock: boolean
}

/** Feedback com dados relacionados para o painel admin */
export interface FeedbackWithDetails extends FeedbackRow {
  collection_point: Pick<CollectionPointRow, 'id' | 'name' | 'building'>
  submitter: Pick<ProfileRow, 'id' | 'full_name' | 'username'>
  resolver: Pick<ProfileRow, 'id' | 'full_name'> | null
}

/** Notificação com feedback associado para o painel admin */
export interface NotificationWithFeedback extends NotificationRow {
  feedback: Pick<FeedbackRow, 'id' | 'category' | 'point_id'> | null
}


// ============================================================
// Database — tipo principal para createClient<Database>()
// ============================================================

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: ProfileRow
        Insert: InsertProfile
        Update: Partial<UpdateProfile>
      }
      collection_points: {
        Row: CollectionPointRow
        Insert: InsertCollectionPoint
        Update: Partial<UpdateCollectionPoint>
      }
      inventory: {
        Row: InventoryRow
        Insert: InsertInventory
        Update: Partial<Pick<InventoryRow, 'quantity' | 'min_quantity'>>
      }
      transactions: {
        Row: TransactionRow
        Insert: InsertTransaction
        Update: never  // Transações são imutáveis
      }
      feedbacks: {
        Row: FeedbackRow
        Insert: InsertFeedback
        Update: Partial<UpdateFeedback>
      }
      notifications: {
        Row: NotificationRow
        Insert: Omit<NotificationRow, 'id' | 'created_at'>
        Update: Partial<UpdateNotification>
      }
    }
    Functions: {
      get_nearest_collection_points: {
        Args: {
          p_lat: number
          p_lng: number
          p_radius_m?: number
          p_limit?: number
        }
        Returns: NearestCollectionPoint[]
      }
      has_user_withdrawn_today: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      is_stock_low: {
        Args: {
          p_point_id: string
          p_item_type: MenstrualItemType
        }
        Returns: boolean
      }
    }
    Enums: {
      user_role: UserRole
      collection_point_status: CollectionPointStatus
      menstrual_item_type: MenstrualItemType
      transaction_type: TransactionType
      feedback_category: FeedbackCategory
      feedback_status: FeedbackStatus
    }
  }
}

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          full_name: string;
          avatar_path: string | null;
          expo_push_token: string | null;
          notifications_enabled: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          full_name?: string;
          avatar_path?: string | null;
          expo_push_token?: string | null;
          notifications_enabled?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          full_name?: string;
          avatar_path?: string | null;
          expo_push_token?: string | null;
          notifications_enabled?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      cars: {
        Row: {
          id: string;
          user_id: string;
          car_name: string;
          make: string;
          model_name: string;
          variant: string;
          battery_size_kwh: number;
          initial_odometer_km: number;
          initial_soc_percent: number;
          collection_date: string | null;
          license_plate: string;
          purchase_price_sgd: number;
          is_primary: boolean;
          image_path: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          car_name?: string;
          make?: string;
          model_name?: string;
          variant?: string;
          battery_size_kwh?: number;
          initial_odometer_km?: number;
          initial_soc_percent?: number;
          collection_date?: string | null;
          license_plate?: string;
          purchase_price_sgd?: number;
          is_primary?: boolean;
          image_path?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          car_name?: string;
          make?: string;
          model_name?: string;
          variant?: string;
          battery_size_kwh?: number;
          initial_odometer_km?: number;
          initial_soc_percent?: number;
          collection_date?: string | null;
          license_plate?: string;
          purchase_price_sgd?: number;
          is_primary?: boolean;
          image_path?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      charging_sessions: {
        Row: {
          id: string;
          user_id: string;
          car_id: string | null;
          charging_location: string;
          charger_id: string;
          charging_network: string;
          charger_type: string;
          charger_power_kw: number;
          start_date: string;
          end_date: string;
          start_soc_percent: number;
          end_soc_percent: number;
          odometer_km: number;
          energy_kwh: number;
          amount_sgd: number;
          session_duration_seconds: number;
          idle_duration_seconds: number;
          car_model: string;
          extraction_confidence: number;
          raw_ai_response: string;
          source_image_ids: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          user_id: string;
          car_id?: string | null;
          charging_location?: string;
          charger_id?: string;
          charging_network?: string;
          charger_type?: string;
          charger_power_kw?: number;
          start_date: string;
          end_date: string;
          start_soc_percent?: number;
          end_soc_percent?: number;
          odometer_km?: number;
          energy_kwh?: number;
          amount_sgd?: number;
          session_duration_seconds?: number;
          idle_duration_seconds?: number;
          car_model?: string;
          extraction_confidence?: number;
          raw_ai_response?: string;
          source_image_ids?: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          user_id?: string;
          car_id?: string | null;
          charging_location?: string;
          charger_id?: string;
          charging_network?: string;
          charger_type?: string;
          charger_power_kw?: number;
          start_date?: string;
          end_date?: string;
          start_soc_percent?: number;
          end_soc_percent?: number;
          odometer_km?: number;
          energy_kwh?: number;
          amount_sgd?: number;
          session_duration_seconds?: number;
          idle_duration_seconds?: number;
          car_model?: string;
          extraction_confidence?: number;
          raw_ai_response?: string;
          source_image_ids?: string;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      delete_own_account: {
        Args: Record<string, never>;
        Returns: undefined;
      };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};

export type Profile = Database['public']['Tables']['profiles']['Row'];
export type Car = Database['public']['Tables']['cars']['Row'];
export type CarInsert = Database['public']['Tables']['cars']['Insert'];
export type CarUpdate = Database['public']['Tables']['cars']['Update'];
export type ChargingSession =
  Database['public']['Tables']['charging_sessions']['Row'];
export type ChargingSessionInsert =
  Database['public']['Tables']['charging_sessions']['Insert'];
export type ChargingSessionUpdate =
  Database['public']['Tables']['charging_sessions']['Update'];

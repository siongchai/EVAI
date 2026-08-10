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
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          full_name?: string;
          avatar_path?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          full_name?: string;
          avatar_path?: string | null;
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

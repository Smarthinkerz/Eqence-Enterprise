// Organization + Multi-Location Types

export type UserRole = 'owner' | 'admin' | 'manager' | 'responder' | 'approver' | 'viewer';

export type Plan = 'starter' | 'professional' | 'enterprise';

export type SSOProvider = 'okta' | 'azure' | 'google';

export type Platform = 'google' | 'shopify' | 'facebook' | 'trustpilot' | 'app_store';

export type Severity = 'critical' | 'high' | 'medium' | 'low';

export type AuditVerb = 'ingested' | 'drafted' | 'edited' | 'approved' | 'published' | 'failed';

export interface Organization {
  id: string;
  name: string;
  slug: string;
  plan: Plan;
  sso_enabled: boolean;
  sso_provider?: SSOProvider;
  sso_config?: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface Membership {
  id: string;
  org_id: string;
  user_id: string;
  role: UserRole;
  created_at: string;
}

export interface Location {
  id: string;
  org_id: string;
  name: string;
  slug: string;
  locale: 'en' | 'ar';
  timezone: string;
  shopify_store_url?: string;
  shopify_access_token?: string;
  created_at: string;
  updated_at: string;
}

export interface ReviewSource {
  id: string;
  location_id: string;
  platform: Platform;
  credentials: Record<string, any>; // server-only
  is_active: boolean;
  last_sync_at?: string;
  created_at: string;
}

export interface SLAPolicy {
  id: string;
  location_id: string;
  severity: Severity;
  response_hours_target: number;
  escalation_to?: UserRole;
  created_at: string;
}

export interface Guardrails {
  id: string;
  location_id: string;
  brand_voice?: string;
  banned_terms?: string[];
  required_disclosures?: string[];
  platform_rules?: Record<Platform, any>;
  created_at: string;
  updated_at: string;
}

export interface AuditLogEntry {
  id: string;
  org_id: string;
  location_id?: string;
  actor_id?: string;
  verb: AuditVerb;
  target: string;
  target_id?: string;
  payload?: Record<string, any>;
  created_at: string;
}

// Permissions matrix
export const PERMISSIONS: Record<UserRole, Record<string, boolean>> = {
  owner: {
    view_reviews: true,
    draft_response: true,
    approve_response: true,
    assign_review: true,
    manage_guardrails: true,
    manage_members: true,
    view_audit_log: true,
    manage_billing: true,
  },
  admin: {
    view_reviews: true,
    draft_response: true,
    approve_response: true,
    assign_review: true,
    manage_guardrails: true,
    manage_members: false,
    view_audit_log: true,
    manage_billing: false,
  },
  manager: {
    view_reviews: true,
    draft_response: true,
    approve_response: true,
    assign_review: true,
    manage_guardrails: true,
    manage_members: false,
    view_audit_log: false,
    manage_billing: false,
  },
  responder: {
    view_reviews: true,
    draft_response: true,
    approve_response: false,
    assign_review: false,
    manage_guardrails: false,
    manage_members: false,
    view_audit_log: false,
    manage_billing: false,
  },
  approver: {
    view_reviews: true,
    draft_response: false,
    approve_response: true,
    assign_review: false,
    manage_guardrails: false,
    manage_members: false,
    view_audit_log: false,
    manage_billing: false,
  },
  viewer: {
    view_reviews: true,
    draft_response: false,
    approve_response: false,
    assign_review: false,
    manage_guardrails: false,
    manage_members: false,
    view_audit_log: false,
    manage_billing: false,
  },
};

export function hasPermission(role: UserRole, action: string): boolean {
  return PERMISSIONS[role]?.[action] ?? false;
}

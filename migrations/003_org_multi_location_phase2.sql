-- Phase 2: Organization + Multi-Location Model
-- Foundational data layer for enterprise features
-- This migration creates the core org/location/membership/roles structure

-- Organizations table (the customer)
CREATE TABLE IF NOT EXISTS organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  plan TEXT DEFAULT 'starter' CHECK (plan IN ('starter', 'professional', 'enterprise')),
  sso_enabled BOOLEAN DEFAULT FALSE,
  sso_provider TEXT CHECK (sso_provider IN ('okta', 'azure', 'google', NULL)),
  sso_config JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- Memberships (users + roles per org)
CREATE TABLE IF NOT EXISTS memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'manager', 'responder', 'approver', 'viewer')),
  created_at TIMESTAMP DEFAULT now(),
  UNIQUE(org_id, user_id)
);

-- Locations (stores/brands per org)
CREATE TABLE IF NOT EXISTS locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  locale TEXT DEFAULT 'en' CHECK (locale IN ('en', 'ar')),
  timezone TEXT DEFAULT 'UTC',
  shopify_store_url TEXT,
  shopify_access_token TEXT,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  UNIQUE(org_id, slug)
);

-- Review sources per location
CREATE TABLE IF NOT EXISTS review_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('google', 'shopify', 'facebook', 'trustpilot', 'app_store')),
  credentials JSONB NOT NULL, -- server-only, never expose to client
  is_active BOOLEAN DEFAULT TRUE,
  last_sync_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT now(),
  UNIQUE(location_id, platform)
);

-- SLA policies per location
CREATE TABLE IF NOT EXISTS sla_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  severity TEXT NOT NULL CHECK (severity IN ('critical', 'high', 'medium', 'low')),
  response_hours_target INTEGER NOT NULL,
  escalation_to TEXT, -- role to escalate to
  created_at TIMESTAMP DEFAULT now(),
  UNIQUE(location_id, severity)
);

-- Guardrails (brand voice + compliance per location)
CREATE TABLE IF NOT EXISTS guardrails (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  location_id UUID NOT NULL REFERENCES locations(id) ON DELETE CASCADE UNIQUE,
  brand_voice TEXT, -- tone, style guidelines
  banned_terms TEXT[], -- array of prohibited words/phrases
  required_disclosures TEXT[], -- legal/compliance requirements
  platform_rules JSONB, -- per-platform length/format rules
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- Audit log (append-only)
CREATE TABLE IF NOT EXISTS audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  location_id UUID REFERENCES locations(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  verb TEXT NOT NULL, -- 'ingested', 'drafted', 'edited', 'approved', 'published', 'failed'
  target TEXT NOT NULL, -- 'review', 'response', 'guardrail', etc.
  target_id UUID,
  payload JSONB, -- context/metadata
  created_at TIMESTAMP DEFAULT now()
);

-- Migrate existing reviews to location-scoped
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS location_id UUID REFERENCES locations(id) ON DELETE CASCADE;
ALTER TABLE responses ADD COLUMN IF NOT EXISTS location_id UUID REFERENCES locations(id) ON DELETE CASCADE;

-- RLS Policies for org/location isolation

-- Organizations: only members can view their org
CREATE POLICY "org_members_can_view" ON organizations
  FOR SELECT USING (
    id IN (
      SELECT org_id FROM memberships WHERE user_id = auth.uid()
    )
  );

-- Memberships: only org members can view membership list
CREATE POLICY "members_can_view_org_members" ON memberships
  FOR SELECT USING (
    org_id IN (
      SELECT org_id FROM memberships WHERE user_id = auth.uid()
    )
  );

-- Locations: only org members can view locations
CREATE POLICY "members_can_view_locations" ON locations
  FOR SELECT USING (
    org_id IN (
      SELECT org_id FROM memberships WHERE user_id = auth.uid()
    )
  );

-- Reviews: only org members can view reviews in their locations
CREATE POLICY "members_can_view_reviews" ON reviews
  FOR SELECT USING (
    location_id IN (
      SELECT l.id FROM locations l
      JOIN memberships m ON l.org_id = m.org_id
      WHERE m.user_id = auth.uid()
    )
  );

-- Responses: only org members can view responses
CREATE POLICY "members_can_view_responses" ON responses
  FOR SELECT USING (
    location_id IN (
      SELECT l.id FROM locations l
      JOIN memberships m ON l.org_id = m.org_id
      WHERE m.user_id = auth.uid()
    )
  );

-- Audit log: only org admins can view audit log
CREATE POLICY "admins_can_view_audit_log" ON audit_log
  FOR SELECT USING (
    org_id IN (
      SELECT org_id FROM memberships 
      WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );

-- Enable RLS
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE sla_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE guardrails ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- Indexes for performance
CREATE INDEX idx_memberships_org_id ON memberships(org_id);
CREATE INDEX idx_memberships_user_id ON memberships(user_id);
CREATE INDEX idx_locations_org_id ON locations(org_id);
CREATE INDEX idx_review_sources_location_id ON review_sources(location_id);
CREATE INDEX idx_sla_policies_location_id ON sla_policies(location_id);
CREATE INDEX idx_guardrails_location_id ON guardrails(location_id);
CREATE INDEX idx_audit_log_org_id ON audit_log(org_id);
CREATE INDEX idx_audit_log_created_at ON audit_log(created_at DESC);
CREATE INDEX idx_reviews_location_id ON reviews(location_id);
CREATE INDEX idx_responses_location_id ON responses(location_id);

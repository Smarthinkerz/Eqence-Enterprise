-- Phase 3: Response Approval Workflow
-- Draft → In Review → Approved → Published lifecycle with audit trail

-- Response status enum
CREATE TYPE response_status AS ENUM (
  'draft',
  'in_review',
  'changes_requested',
  'approved',
  'published',
  'needs_attention'
);

-- Extend responses table with approval workflow
ALTER TABLE responses ADD COLUMN IF NOT EXISTS status response_status DEFAULT 'draft';
ALTER TABLE responses ADD COLUMN IF NOT EXISTS drafted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE responses ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE responses ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP;
ALTER TABLE responses ADD COLUMN IF NOT EXISTS published_at TIMESTAMP;
ALTER TABLE responses ADD COLUMN IF NOT EXISTS external_id TEXT; -- platform-specific ID (Google, Facebook, etc.)
ALTER TABLE responses ADD COLUMN IF NOT EXISTS publish_error TEXT; -- error message if publish failed
ALTER TABLE responses ADD COLUMN IF NOT EXISTS language TEXT DEFAULT 'en';

-- Approvals table (audit trail of decisions)
CREATE TABLE IF NOT EXISTS approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  response_id UUID NOT NULL REFERENCES responses(id) ON DELETE CASCADE,
  approver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  status response_status NOT NULL,
  rationale TEXT, -- why approved/rejected
  acted_at TIMESTAMP DEFAULT now(),
  UNIQUE(response_id, approver_id, acted_at)
);

-- Assignments table (routing reviews to team members)
CREATE TABLE IF NOT EXISTS assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  assignee_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  queue TEXT, -- 'critical', 'high', 'medium', 'low', 'escalation'
  assigned_at TIMESTAMP DEFAULT now(),
  assigned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  UNIQUE(review_id, assignee_id)
);

-- My Work / Approvals inbox view
CREATE TABLE IF NOT EXISTS my_work_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  review_id UUID REFERENCES reviews(id) ON DELETE CASCADE,
  response_id UUID REFERENCES responses(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL CHECK (item_type IN ('awaiting_approval', 'assigned_to_me', 'sla_at_risk', 'recently_published')),
  priority TEXT DEFAULT 'medium',
  created_at TIMESTAMP DEFAULT now(),
  UNIQUE(user_id, review_id, item_type)
);

-- RLS Policies for approval workflow

-- Responses: responders can view/edit their own drafts
CREATE POLICY "responders_can_view_responses" ON responses
  FOR SELECT USING (
    location_id IN (
      SELECT l.id FROM locations l
      JOIN memberships m ON l.org_id = m.org_id
      WHERE m.user_id = auth.uid()
    )
  );

CREATE POLICY "responders_can_draft" ON responses
  FOR INSERT WITH CHECK (
    location_id IN (
      SELECT l.id FROM locations l
      JOIN memberships m ON l.org_id = m.org_id
      WHERE m.user_id = auth.uid() AND m.role IN ('owner', 'admin', 'manager', 'responder')
    )
  );

-- Approvals: only approvers can view/create approvals
CREATE POLICY "approvers_can_view_approvals" ON approvals
  FOR SELECT USING (
    response_id IN (
      SELECT r.id FROM responses r
      JOIN locations l ON r.location_id = l.id
      JOIN memberships m ON l.org_id = m.org_id
      WHERE m.user_id = auth.uid()
    )
  );

CREATE POLICY "approvers_can_approve" ON approvals
  FOR INSERT WITH CHECK (
    response_id IN (
      SELECT r.id FROM responses r
      JOIN locations l ON r.location_id = l.id
      JOIN memberships m ON l.org_id = m.org_id
      WHERE m.user_id = auth.uid() AND m.role IN ('owner', 'admin', 'manager', 'approver')
    )
  );

-- Assignments: managers can view/create assignments
CREATE POLICY "managers_can_view_assignments" ON assignments
  FOR SELECT USING (
    review_id IN (
      SELECT r.id FROM reviews r
      JOIN locations l ON r.location_id = l.id
      JOIN memberships m ON l.org_id = m.org_id
      WHERE m.user_id = auth.uid()
    )
  );

CREATE POLICY "managers_can_assign" ON assignments
  FOR INSERT WITH CHECK (
    review_id IN (
      SELECT r.id FROM reviews r
      JOIN locations l ON r.location_id = l.id
      JOIN memberships m ON l.org_id = m.org_id
      WHERE m.user_id = auth.uid() AND m.role IN ('owner', 'admin', 'manager')
    )
  );

-- My Work: users can only view their own work items
CREATE POLICY "users_can_view_their_work" ON my_work_items
  FOR SELECT USING (user_id = auth.uid());

-- Enable RLS
ALTER TABLE responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE my_work_items ENABLE ROW LEVEL SECURITY;

-- Indexes for performance
CREATE INDEX idx_responses_status ON responses(status);
CREATE INDEX idx_responses_drafted_by ON responses(drafted_by);
CREATE INDEX idx_responses_approved_by ON responses(approved_by);
CREATE INDEX idx_approvals_response_id ON approvals(response_id);
CREATE INDEX idx_approvals_approver_id ON approvals(approver_id);
CREATE INDEX idx_assignments_review_id ON assignments(review_id);
CREATE INDEX idx_assignments_assignee_id ON assignments(assignee_id);
CREATE INDEX idx_my_work_user_id ON my_work_items(user_id);
CREATE INDEX idx_my_work_item_type ON my_work_items(item_type);

-- Trigger to create audit log entry when response is approved
CREATE OR REPLACE FUNCTION log_response_approval()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (org_id, location_id, actor_id, verb, target, target_id, payload)
  SELECT 
    l.org_id,
    r.location_id,
    NEW.approver_id,
    'approved',
    'response',
    NEW.response_id,
    jsonb_build_object('status', NEW.status, 'rationale', NEW.rationale)
  FROM responses r
  JOIN locations l ON r.location_id = l.id
  WHERE r.id = NEW.response_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER response_approval_audit
AFTER INSERT ON approvals
FOR EACH ROW
EXECUTE FUNCTION log_response_approval();

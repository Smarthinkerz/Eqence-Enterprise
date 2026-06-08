import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import type { Organization, Location, Membership, UserRole } from '../types/org';
import { hasPermission } from '../types/org';

interface OrganizationContextType {
  // Current selection
  currentOrg: Organization | null;
  currentLocation: Location | null;
  currentRole: UserRole | null;
  
  // Data
  organizations: Organization[];
  locations: Location[];
  memberships: Membership[];
  
  // Actions
  setCurrentOrg: (org: Organization | null) => void;
  setCurrentLocation: (location: Location | null) => void;
  
  // Permissions
  can: (action: string) => boolean;
  
  // Loading
  isLoading: boolean;
  error: string | null;
}

const OrganizationContext = createContext<OrganizationContextType | undefined>(undefined);

export function OrganizationProvider({ children }: { children: ReactNode }) {
  const [currentOrg, setCurrentOrg] = useState<Organization | null>(null);
  const [currentLocation, setCurrentLocation] = useState<Location | null>(null);
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [locations, setLocations] = useState<Location[]>([]);
  const [memberships, setMemberships] = useState<Membership[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Initialize with default org/location (for now, single-org mode)
  useEffect(() => {
    const initializeOrg = async () => {
      try {
        setIsLoading(true);
        // For now, create a default org if none exists
        // This will be replaced with proper org loading from Supabase
        const defaultOrg: Organization = {
          id: 'default-org',
          name: 'My Organization',
          slug: 'my-org',
          plan: 'professional',
          sso_enabled: false,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        setOrganizations([defaultOrg]);
        setCurrentOrg(defaultOrg);

        const defaultLocation: Location = {
          id: 'default-location',
          org_id: 'default-org',
          name: 'Main Store',
          slug: 'main-store',
          locale: 'en',
          timezone: 'UTC',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        setLocations([defaultLocation]);
        setCurrentLocation(defaultLocation);

        setMemberships([{
          id: 'default-membership',
          org_id: 'default-org',
          user_id: 'current-user',
          role: 'owner',
          created_at: new Date().toISOString(),
        }]);

        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unknown error');
      } finally {
        setIsLoading(false);
      }
    };

    initializeOrg();
  }, []);

  // Get current user's role in current org
  const currentRole = currentOrg
    ? memberships.find(m => m.org_id === currentOrg.id)?.role ?? null
    : null;

  // Permission check
  const can = (action: string): boolean => {
    if (!currentRole) return false;
    return hasPermission(currentRole, action);
  };

  return (
    <OrganizationContext.Provider value={{
      currentOrg,
      currentLocation,
      currentRole,
      organizations,
      locations,
      memberships,
      setCurrentOrg,
      setCurrentLocation,
      can,
      isLoading,
      error
    }}>
      {children}
    </OrganizationContext.Provider>
  );
}

export function useOrganization() {
  const context = useContext(OrganizationContext);
  if (!context) {
    throw new Error('useOrganization must be used within OrganizationProvider');
  }
  return context;
}

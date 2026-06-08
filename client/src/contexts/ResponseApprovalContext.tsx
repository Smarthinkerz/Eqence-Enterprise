import React, { createContext, useContext, useState, ReactNode } from 'react';

export type ResponseStatus = 'draft' | 'in_review' | 'changes_requested' | 'approved' | 'published' | 'needs_attention';

export interface Response {
  id: string;
  review_id: string;
  location_id: string;
  body: string;
  status: ResponseStatus;
  drafted_by?: string;
  approved_by?: string;
  approved_at?: string;
  published_at?: string;
  external_id?: string;
  language: string;
  created_at: string;
  updated_at: string;
}

export interface Approval {
  id: string;
  response_id: string;
  approver_id: string;
  status: ResponseStatus;
  rationale?: string;
  acted_at: string;
}

interface ResponseApprovalContextType {
  responses: Response[];
  currentResponse: Response | null;
  
  draftResponse: (reviewId: string, body: string) => Promise<Response>;
  submitForReview: (responseId: string) => Promise<void>;
  approveResponse: (responseId: string, rationale?: string) => Promise<void>;
  requestChanges: (responseId: string, rationale: string) => Promise<void>;
  publishResponse: (responseId: string) => Promise<void>;
  
  isLoading: boolean;
  error: string | null;
}

const ResponseApprovalContext = createContext<ResponseApprovalContextType | undefined>(undefined);

export function ResponseApprovalProvider({ children }: { children: ReactNode }) {
  const [responses, setResponses] = useState<Response[]>([]);
  const [currentResponse, setCurrentResponse] = useState<Response | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const draftResponse = async (reviewId: string, body: string): Promise<Response> => {
    try {
      setIsLoading(true);
      const response: Response = {
        id: 'temp-id',
        review_id: reviewId,
        location_id: 'current-location',
        body,
        status: 'draft',
        language: 'en',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      setResponses([...responses, response]);
      return response;
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Failed to draft response';
      setError(errorMsg);
      throw err;
    } finally {
      setIsLoading(false);
    }
  };

  const submitForReview = async (responseId: string): Promise<void> => {
    try {
      setIsLoading(true);
      setResponses(responses.map(r => 
        r.id === responseId ? { ...r, status: 'in_review' as ResponseStatus } : r
      ));
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Failed to submit for review';
      setError(errorMsg);
      throw err;
    } finally {
      setIsLoading(false);
    }
  };

  const approveResponse = async (responseId: string, rationale?: string): Promise<void> => {
    try {
      setIsLoading(true);
      setResponses(responses.map(r => 
        r.id === responseId ? { ...r, status: 'approved' as ResponseStatus, approved_at: new Date().toISOString() } : r
      ));
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Failed to approve response';
      setError(errorMsg);
      throw err;
    } finally {
      setIsLoading(false);
    }
  };

  const requestChanges = async (responseId: string, rationale: string): Promise<void> => {
    try {
      setIsLoading(true);
      setResponses(responses.map(r => 
        r.id === responseId ? { ...r, status: 'changes_requested' as ResponseStatus } : r
      ));
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Failed to request changes';
      setError(errorMsg);
      throw err;
    } finally {
      setIsLoading(false);
    }
  };

  const publishResponse = async (responseId: string): Promise<void> => {
    try {
      setIsLoading(true);
      setResponses(responses.map(r => 
        r.id === responseId ? { ...r, status: 'published' as ResponseStatus, published_at: new Date().toISOString() } : r
      ));
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Failed to publish response';
      setError(errorMsg);
      throw err;
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <ResponseApprovalContext.Provider value={{
      responses,
      currentResponse,
      draftResponse,
      submitForReview,
      approveResponse,
      requestChanges,
      publishResponse,
      isLoading,
      error
    }}>
      {children}
    </ResponseApprovalContext.Provider>
  );
}

export function useResponseApproval() {
  const context = useContext(ResponseApprovalContext);
  if (!context) {
    throw new Error('useResponseApproval must be used within ResponseApprovalProvider');
  }
  return context;
}

import { useCallback, useState } from 'react';
import { apiErrorMessage } from '@/services/api';

interface AsyncState<T> {
  data: T | null;
  isLoading: boolean;
  error: string | null;
}

/** Minimal hook to run an async API call with loading/error state. */
export function useAsync<T>() {
  const [state, setState] = useState<AsyncState<T>>({
    data: null, isLoading: false, error: null,
  });

  const run = useCallback(async (fn: () => Promise<T>): Promise<T | null> => {
    setState({ data: null, isLoading: true, error: null });
    try {
      const data = await fn();
      setState({ data, isLoading: false, error: null });
      return data;
    } catch (err) {
      setState({ data: null, isLoading: false, error: apiErrorMessage(err) });
      return null;
    }
  }, []);

  return { ...state, run };
}

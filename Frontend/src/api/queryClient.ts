import { QueryClient } from '@tanstack/react-query';

/**
 * Shared QueryClient instance.
 *
 * Exported so that authentication lifecycle actions (such as logout and session expiry)
 * can invoke `queryClient.clear()` to purge user-specific cached server state.
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error) => {
        const status = (error as { response?: { status?: number } })?.response
          ?.status;

        if (status === 401 || status === 403) {
          return false;
        }

        return failureCount < 1;
      },
      staleTime: 30_000,
      refetchOnWindowFocus: false,
    },
  },
});

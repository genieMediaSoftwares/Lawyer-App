import { useEffect, useState } from 'react';

/**
 * Trails a rapidly-changing value, settling only once it has been still.
 *
 * Used for search: the input updates on every keystroke so typing stays
 * instant, while the query key — and so the request — only changes when the
 * user pauses. Without it, "property" is eight requests, seven of which are
 * obsolete before they return.
 *
 * The timer is cleared on every change, so only the last one ever fires.
 */
export const useDebouncedValue = <T,>(value: T, delayMs = 350): T => {
  const [settled, setSettled] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setSettled(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);

  return settled;
};

import { useEffect } from 'react';

export function useTitle(title: string): void {
  useEffect(() => {
    document.title = `${title} — Viva Admin`;
    return () => { document.title = 'Viva Administration'; };
  }, [title]);
}

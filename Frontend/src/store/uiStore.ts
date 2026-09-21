import { create } from 'zustand';

/**
 * Purely client-side UI state.
 *
 * Nothing that came from a server belongs here — that is React Query's job
 * (§34). This store holds the handful of things that are genuinely global to
 * the interface and would otherwise be prop-drilled through the navigator:
 * whether the drawer is open, and whether the create-case sheet is open.
 *
 * Both live here rather than in the navigator's local state because the
 * triggers and the sheets are on opposite sides of the tree — the Home
 * header's hamburger is several levels below the component that renders the
 * drawer.
 */

interface UiState {
  isDrawerOpen: boolean;
  openDrawer: () => void;
  closeDrawer: () => void;

  isCreateSheetOpen: boolean;
  openCreateSheet: () => void;
  closeCreateSheet: () => void;
}

export const useUiStore = create<UiState>(set => ({
  isDrawerOpen: false,
  // Closing the other overlay on open: two modal surfaces stacked over each
  // other have no sensible dismiss order, and the scrims would compound.
  openDrawer: () => set({ isDrawerOpen: true, isCreateSheetOpen: false }),
  closeDrawer: () => set({ isDrawerOpen: false }),

  isCreateSheetOpen: false,
  openCreateSheet: () => set({ isCreateSheetOpen: true, isDrawerOpen: false }),
  closeCreateSheet: () => set({ isCreateSheetOpen: false }),
}));

import { create } from "zustand";
import Cookies from "js-cookie";
import { api } from "../api/axios";

export interface AdminUser {
  id: string;
  fullName: string;
  email: string;
  role: string;
  profileImage?: string;
}

interface AuthState {
  user: AdminUser | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  checkAuth: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: typeof window !== "undefined" ? Cookies.get("admin_token") || localStorage.getItem("admin_token") : null,
  isAuthenticated: false,
  isLoading: true,

  login: async (email, password) => {
    set({ isLoading: true });
    try {
      const res = await api.post("/auth/login", { email, password });
      const { token, user } = res.data.data;

      if (user.role !== "admin") {
        throw new Error("Access denied. Admin authorization required.");
      }

      Cookies.set("admin_token", token, { expires: 7 });
      localStorage.setItem("admin_token", token);

      set({
        user: {
          id: user.id || user._id,
          fullName: user.fullName,
          email: user.email,
          role: user.role,
          profileImage: user.profileImage,
        },
        token,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch (err: any) {
      set({ isLoading: false });
      throw new Error(err.response?.data?.message || err.message || "Failed to log in");
    }
  },

  logout: () => {
    Cookies.remove("admin_token");
    localStorage.removeItem("admin_token");
    set({ user: null, token: null, isAuthenticated: false, isLoading: false });
    if (typeof window !== "undefined") {
      window.location.href = "/login";
    }
  },

  checkAuth: async () => {
    const token = Cookies.get("admin_token") || localStorage.getItem("admin_token");
    if (!token) {
      set({ user: null, token: null, isAuthenticated: false, isLoading: false });
      return;
    }

    try {
      const res = await api.get("/auth/profile");
      const user = res.data.data;
      if (user.role !== "admin") {
        throw new Error("Not an admin");
      }
      set({
        user: {
          id: user._id,
          fullName: user.fullName,
          email: user.email,
          role: user.role,
          profileImage: user.profileImage,
        },
        token,
        isAuthenticated: true,
        isLoading: false,
      });
    } catch {
      Cookies.remove("admin_token");
      localStorage.removeItem("admin_token");
      set({ user: null, token: null, isAuthenticated: false, isLoading: false });
    }
  },
}));

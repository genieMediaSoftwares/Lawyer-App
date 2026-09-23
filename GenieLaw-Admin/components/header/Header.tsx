"use client";

import React, { useState } from "react";
import { useAuthStore } from "@/lib/auth/authStore";
import { Bell, Search, LogOut, User as UserIcon, Shield, Menu } from "lucide-react";
import Link from "next/link";

export function Header({ onToggleSidebar }: { onToggleSidebar?: () => void }) {
  const { user, logout } = useAuthStore();
  const [showProfileMenu, setShowProfileMenu] = useState(false);

  return (
    <header className="h-16 bg-white border-b border-gray-200 px-6 flex items-center justify-between sticky top-0 z-20 shadow-sm">
      <div className="flex items-center gap-4">
        <button
          onClick={onToggleSidebar}
          className="md:hidden p-2 rounded-lg text-gray-600 hover:bg-gray-100"
          aria-label="Toggle sidebar"
        >
          <Menu className="w-5 h-5" />
        </button>

        {/* Global Search input */}
        <div className="relative hidden sm:block w-72">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search lawyers, clients, cases..."
            className="w-full pl-9 pr-4 py-1.5 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-800 focus:outline-none focus:ring-2 focus:ring-gold/50 focus:border-gold transition-all"
          />
        </div>
      </div>

      <div className="flex items-center gap-4">
        {/* Real-time Notifications Bell */}
        <Link
          href="/notifications"
          className="relative p-2 rounded-lg text-gray-600 hover:bg-gray-100 hover:text-gray-900 transition-colors"
          title="Notifications"
        >
          <Bell className="w-5 h-5" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-gold rounded-full ring-2 ring-white"></span>
        </Link>

        {/* Admin Profile & Dropdown */}
        <div className="relative">
          <button
            onClick={() => setShowProfileMenu(!showProfileMenu)}
            className="flex items-center gap-3 p-1.5 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <div className="w-8 h-8 rounded-full bg-gold/20 border border-gold flex items-center justify-center font-bold text-gray-800 text-sm">
              {user?.fullName ? user.fullName[0].toUpperCase() : "A"}
            </div>
            <div className="text-left hidden md:block">
              <p className="text-xs font-semibold text-gray-900 leading-none">{user?.fullName || "Administrator"}</p>
              <p className="text-[10px] text-gray-500 font-medium mt-0.5">{user?.email || "admin@lawconnect.com"}</p>
            </div>
          </button>

          {showProfileMenu && (
            <div className="absolute right-0 mt-2 w-48 bg-white border border-gray-200 rounded-xl shadow-lg py-1 z-50 text-sm">
              <div className="px-4 py-2 border-b border-gray-100">
                <p className="font-semibold text-gray-900 truncate">{user?.fullName}</p>
                <span className="inline-flex items-center gap-1 text-[10px] font-medium bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded mt-1">
                  <Shield className="w-3 h-3" /> System Admin
                </span>
              </div>
              <Link
                href="/settings"
                onClick={() => setShowProfileMenu(false)}
                className="flex items-center gap-2 px-4 py-2 text-gray-700 hover:bg-gray-50 transition-colors"
              >
                <UserIcon className="w-4 h-4 text-gray-500" /> Account Settings
              </Link>
              <button
                onClick={logout}
                className="w-full flex items-center gap-2 px-4 py-2 text-red-600 hover:bg-red-50 transition-colors text-left font-medium"
              >
                <LogOut className="w-4 h-4" /> Sign Out
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  );
}

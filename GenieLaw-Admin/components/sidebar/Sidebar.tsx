"use client";

import React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  UserCheck,
  Users,
  Briefcase,
  Calendar,
  Clock,
  FileText,
  CreditCard,
  Crown,
  Star,
  AlertTriangle,
  Flame,
  FolderTree,
  Tag,
  Bell,
  Scale,
  ShieldAlert,
  Settings,
  Scale as LogoIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";

const menuItems = [
  { label: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { label: "Lawyers", href: "/lawyers", icon: Users },
  { label: "Lawyer Verification", href: "/lawyer-verification", icon: UserCheck },
  { label: "Clients", href: "/clients", icon: Users },
  { label: "Cases", href: "/cases", icon: Briefcase },
  { label: "Consultations", href: "/consultations", icon: Clock },
  { label: "Appointments", href: "/appointments", icon: Calendar },
  { label: "Documents", href: "/documents", icon: FileText },
  { label: "Payments", href: "/payments", icon: CreditCard },
  { label: "Subscriptions", href: "/subscriptions", icon: Crown },
  { label: "Reviews", href: "/reviews", icon: Star },
  { label: "Disputes", href: "/disputes", icon: AlertTriangle },
  { label: "Urgent Cases", href: "/urgent-cases", icon: Flame },
  { label: "Categories", href: "/categories", icon: FolderTree },
  { label: "Promotions", href: "/promotions", icon: Tag },
  { label: "Notifications", href: "/notifications", icon: Bell },
  { label: "Legal Documents", href: "/legal", icon: Scale },
  { label: "Audit Logs", href: "/audit-logs", icon: ShieldAlert },
  { label: "Settings", href: "/settings", icon: Settings },
];

export function Sidebar({ className }: { className?: string }) {
  const pathname = usePathname();

  return (
    <aside className={cn("w-64 bg-[#111827] text-gray-300 flex flex-col h-screen sticky top-0 border-r border-gray-800 z-30", className)}>
      {/* Brand Logo */}
      <div className="h-16 flex items-center px-6 border-b border-gray-800 gap-3">
        <div className="w-9 h-9 rounded-lg bg-gold flex items-center justify-center text-black font-extrabold shadow-md">
          <LogoIcon className="w-5 h-5" />
        </div>
        <div>
          <h1 className="font-extrabold text-white text-lg tracking-tight flex items-center gap-1.5">
            GENIE <span className="text-gold">LAW</span>
          </h1>
          <p className="text-[10px] text-gray-400 font-medium tracking-wider uppercase">Admin Control Center</p>
        </div>
      </div>

      {/* Navigation List */}
      <div className="flex-1 overflow-y-auto px-3 py-4 space-y-1">
        {menuItems.map((item) => {
          const isActive = pathname === item.href || (item.href !== "/dashboard" && pathname.startsWith(item.href));
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all duration-150",
                isActive
                  ? "bg-gold/15 text-gold font-semibold shadow-sm border-l-4 border-gold"
                  : "text-gray-400 hover:text-white hover:bg-gray-800/60"
              )}
            >
              <Icon className={cn("w-4 h-4 shrink-0", isActive ? "text-gold" : "text-gray-400")} />
              <span className="truncate">{item.label}</span>
            </Link>
          );
        })}
      </div>

      {/* Footer info */}
      <div className="p-4 border-t border-gray-800 text-xs text-gray-500 text-center">
        <p>Genie Law Admin v1.0</p>
        <p className="text-[10px] text-gray-600 mt-0.5">Secure Management System</p>
      </div>
    </aside>
  );
}

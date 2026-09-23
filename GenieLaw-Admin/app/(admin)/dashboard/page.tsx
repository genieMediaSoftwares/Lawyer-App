"use client";

import React from "react";
import { useQuery } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Users, UserCheck, Briefcase, Calendar, FileText, AlertTriangle, ArrowUpRight, TrendingUp } from "lucide-react";
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, Tooltip, CartesianGrid, BarChart, Bar } from "recharts";
import { formatDate } from "@/lib/utils";
import Link from "next/link";

export default function DashboardPage() {
  const { data: statsData, isLoading: isStatsLoading } = useQuery({
    queryKey: ["admin", "stats"],
    queryFn: adminApi.getDashboardStats,
  });

  const { data: analyticsData } = useQuery({
    queryKey: ["admin", "analytics"],
    queryFn: adminApi.getAnalyticsData,
  });

  const stats = statsData || {};
  const monthlyStats = analyticsData?.monthlyStats || [];

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">System Dashboard</h1>
          <p className="text-sm text-gray-500">Real-time platform operations and metrics overview</p>
        </div>
        <div className="flex items-center gap-3">
          <Link
            href="/notifications"
            className="px-4 py-2 bg-gold hover:bg-gold-hover text-black font-semibold rounded-lg shadow-sm text-sm transition-all"
          >
            Broadcast Notification
          </Link>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <StatCard
          title="Total Lawyers"
          value={stats.totalLawyers ?? (isStatsLoading ? "..." : 0)}
          subtitle={`${stats.approvedLawyers ?? 0} Verified`}
          icon={Users}
          badge={`${stats.pendingVerifications ?? 0} Pending`}
          badgeColor="bg-amber-100 text-amber-800"
          href="/lawyers"
        />

        <StatCard
          title="Total Clients"
          value={stats.totalClients ?? (isStatsLoading ? "..." : 0)}
          subtitle={`${stats.activeClients ?? 0} Active`}
          icon={Users}
          href="/clients"
        />

        <StatCard
          title="Total Cases"
          value={stats.totalCases ?? (isStatsLoading ? "..." : 0)}
          subtitle={`${stats.activeCases ?? 0} In Progress`}
          icon={Briefcase}
          badge={`${stats.closedCases ?? 0} Closed`}
          badgeColor="bg-emerald-100 text-emerald-800"
          href="/cases"
        />

        <StatCard
          title="Support & Disputes"
          value={stats.totalSupportTickets ?? (isStatsLoading ? "..." : 0)}
          subtitle={`${stats.openSupportTickets ?? 0} Open Tickets`}
          icon={AlertTriangle}
          badgeColor="bg-red-100 text-red-800"
          href="/disputes"
        />
      </div>

      {/* Analytics Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Growth Trends */}
        <div className="lg:col-span-2 bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-base font-bold text-gray-900">Platform Growth</h2>
              <p className="text-xs text-gray-500">Lawyer and client registrations over time</p>
            </div>
            <div className="flex items-center gap-2 text-xs font-semibold">
              <span className="flex items-center gap-1 text-gold"><span className="w-3 h-3 bg-gold rounded-full"></span> Clients</span>
              <span className="flex items-center gap-1 text-gray-800"><span className="w-3 h-3 bg-gray-800 rounded-full"></span> Lawyers</span>
            </div>
          </div>
          <div className="h-64">
            {monthlyStats.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={monthlyStats} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="colorClients" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#F5B900" stopOpacity={0.4} />
                      <stop offset="95%" stopColor="#F5B900" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#F1F5F9" />
                  <XAxis dataKey="month" stroke="#94A3B8" fontSize={12} />
                  <YAxis stroke="#94A3B8" fontSize={12} />
                  <Tooltip />
                  <Area type="monotone" dataKey="clients" stroke="#F5B900" strokeWidth={2} fillOpacity={1} fill="url(#colorClients)" />
                  <Area type="monotone" dataKey="lawyers" stroke="#1E293B" strokeWidth={2} fillOpacity={0} fill="#1E293B" />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-full flex items-center justify-center text-sm text-gray-400">No analytical growth data available</div>
            )}
          </div>
        </div>

        {/* Case Status Distribution */}
        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm flex flex-col justify-between">
          <div>
            <h2 className="text-base font-bold text-gray-900 mb-1">Case Breakdown</h2>
            <p className="text-xs text-gray-500 mb-4">Distribution by current status</p>
            <div className="space-y-4">
              <StatusProgress label="Pending Response" value={stats.casesOverview?.pending || 0} total={stats.totalCases || 1} color="bg-amber-400" />
              <StatusProgress label="In Progress" value={stats.casesOverview?.inProgress || 0} total={stats.totalCases || 1} color="bg-blue-500" />
              <StatusProgress label="Completed / Closed" value={stats.casesOverview?.completed || stats.casesOverview?.closed || 0} total={stats.totalCases || 1} color="bg-emerald-500" />
            </div>
          </div>
          <div className="mt-6 pt-4 border-t border-gray-100 flex items-center justify-between text-xs text-gray-500 font-medium">
            <span>Case Resolution Rate</span>
            <span className="font-bold text-emerald-600">{analyticsData?.caseResolutionRate || "0%"}</span>
          </div>
        </div>
      </div>

      {/* Recent Activity Tables */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Registrations */}
        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold text-gray-900">Recent Users</h2>
            <Link href="/clients" className="text-xs font-semibold text-gold-hover hover:underline flex items-center gap-0.5">
              View all <ArrowUpRight className="w-3.5 h-3.5" />
            </Link>
          </div>
          <div className="divide-y divide-gray-100">
            {stats.recentRegistrations && stats.recentRegistrations.length > 0 ? (
              stats.recentRegistrations.map((u: any) => (
                <div key={u._id} className="py-3 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-semibold text-gray-900">{u.fullName}</p>
                    <p className="text-xs text-gray-500">{u.email} • {u.role}</p>
                  </div>
                  <span className="text-xs text-gray-400 font-medium">{formatDate(u.createdAt)}</span>
                </div>
              ))
            ) : (
              <p className="py-4 text-center text-sm text-gray-400">No recent users</p>
            )}
          </div>
        </div>

        {/* Recent Cases */}
        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold text-gray-900">Recent Cases</h2>
            <Link href="/cases" className="text-xs font-semibold text-gold-hover hover:underline flex items-center gap-0.5">
              View all <ArrowUpRight className="w-3.5 h-3.5" />
            </Link>
          </div>
          <div className="divide-y divide-gray-100">
            {stats.recentCases && stats.recentCases.length > 0 ? (
              stats.recentCases.map((c: any) => (
                <div key={c._id} className="py-3 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-semibold text-gray-900 truncate max-w-xs">{c.title}</p>
                    <p className="text-xs text-gray-500">Client: {c.client?.fullName || "N/A"}</p>
                  </div>
                  <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-700">
                    {c.status}
                  </span>
                </div>
              ))
            ) : (
              <p className="py-4 text-center text-sm text-gray-400">No recent cases</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function StatCard({ title, value, subtitle, icon: Icon, badge, badgeColor, href }: any) {
  return (
    <Link href={href || "#"} className="bg-white p-5 rounded-xl border border-gray-200 shadow-sm hover:shadow-md transition-all group">
      <div className="flex items-center justify-between mb-3">
        <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">{title}</span>
        <div className="w-8 h-8 rounded-lg bg-gray-100 group-hover:bg-gold/20 group-hover:text-gold flex items-center justify-center text-gray-600 transition-colors">
          <Icon className="w-4 h-4" />
        </div>
      </div>
      <div className="flex items-baseline justify-between">
        <span className="text-2xl font-extrabold text-gray-900">{value}</span>
        {badge && <span className={`text-[11px] font-bold px-2 py-0.5 rounded-full ${badgeColor}`}>{badge}</span>}
      </div>
      <p className="text-xs text-gray-500 mt-1">{subtitle}</p>
    </Link>
  );
}

function StatusProgress({ label, value, total, color }: any) {
  const percentage = Math.round((value / total) * 100) || 0;
  return (
    <div>
      <div className="flex justify-between text-xs font-semibold mb-1">
        <span className="text-gray-700">{label}</span>
        <span className="text-gray-900">{value} ({percentage}%)</span>
      </div>
      <div className="w-full h-2 bg-gray-100 rounded-full overflow-hidden">
        <div className={`h-full ${color} rounded-full`} style={{ width: `${percentage}%` }}></div>
      </div>
    </div>
  );
}

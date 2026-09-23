"use client";

import React from "react";
import { useQuery } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Flame, Eye } from "lucide-react";
import { formatDate } from "@/lib/utils";
import Link from "next/link";

export default function UrgentCasesPage() {
  const { data, isLoading } = useQuery({
    queryKey: ["admin", "cases", "urgent"],
    queryFn: adminApi.getUrgentCases,
  });

  const urgentCases = data?.data || [];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-xl bg-red-100 flex items-center justify-center text-red-600">
          <Flame className="w-6 h-6 fill-red-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Real-Time Urgent Cases</h1>
          <p className="text-sm text-gray-500">High urgency legal requests requiring immediate advocate dispatch</p>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500">Scanning urgent cases...</div>
        ) : urgentCases.length === 0 ? (
          <div className="p-12 text-center text-sm text-gray-400">No urgent cases currently active</div>
        ) : (
          <div className="divide-y divide-gray-100">
            {urgentCases.map((c: any) => (
              <div key={c._id} className="p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 hover:bg-gray-50/80 transition-colors">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-red-100 text-red-800 uppercase tracking-wider">
                      {c.urgency || "Urgent"}
                    </span>
                    <h3 className="font-bold text-gray-900 text-base">{c.title}</h3>
                  </div>
                  <p className="text-xs text-gray-500 mt-1">
                    Category: {c.category} • Client: {c.client?.fullName || "N/A"} • Location: {c.location || "N/A"}
                  </p>
                </div>

                <div className="flex items-center gap-3 w-full sm:w-auto justify-end">
                  <span className="text-xs text-gray-400">{formatDate(c.createdAt)}</span>
                  <Link
                    href={`/cases/${c._id}`}
                    className="px-4 py-2 bg-black hover:bg-gray-800 text-white font-semibold text-xs rounded-lg transition-colors flex items-center gap-1.5"
                  >
                    <Eye className="w-3.5 h-3.5" /> View Case
                  </Link>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

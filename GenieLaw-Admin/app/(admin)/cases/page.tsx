"use client";

import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Search, Filter, Eye, Briefcase, Flame } from "lucide-react";
import { formatDate } from "@/lib/utils";
import Link from "next/link";
import { toast } from "sonner";

export default function CasesPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [page, setPage] = useState(1);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["admin", "cases", search, status, page],
    queryFn: () => adminApi.getCases({ page, limit: 15, search, status }),
  });

  const updateStatusMutation = useMutation({
    mutationFn: ({ caseId, status }: { caseId: string; status: string }) =>
      adminApi.updateCaseStatus(caseId, { status }),
    onSuccess: () => {
      toast.success("Case status updated successfully");
      queryClient.invalidateQueries({ queryKey: ["admin", "cases"] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Failed to update case status");
    },
  });

  const cases = data?.data || [];
  const totalPages = data?.pages || 1;

  return (
    <div className="space-y-6">
      {/* Title */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Case Administration</h1>
          <p className="text-sm text-gray-500">Monitor all legal cases submitted on the platform</p>
        </div>
        <Link
          href="/urgent-cases"
          className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-semibold rounded-lg shadow-sm text-sm transition-all flex items-center gap-1.5"
        >
          <Flame className="w-4 h-4 fill-white" /> Urgent Cases
        </Link>
      </div>

      {/* Search and Filters */}
      <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
            placeholder="Search title, category, client name..."
            className="w-full pl-9 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-gold/50"
          />
        </div>

        <div className="flex items-center gap-3 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-gray-400" />
          <select
            value={status}
            onChange={(e) => {
              setStatus(e.target.value);
              setPage(1);
            }}
            className="px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-800 font-medium focus:outline-none focus:ring-2 focus:ring-gold/50"
          >
            <option value="all">All Case Statuses</option>
            <option value="Submitted">Submitted</option>
            <option value="Pending">Pending Acceptance</option>
            <option value="In Progress">In Progress</option>
            <option value="Closed">Closed / Completed</option>
          </select>
        </div>
      </div>

      {/* Cases Table */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500">Loading cases directory...</div>
        ) : isError ? (
          <div className="p-12 text-center text-sm text-red-500">Error loading cases</div>
        ) : cases.length === 0 ? (
          <div className="p-12 text-center text-sm text-gray-400">No cases found matching criteria</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-gray-50 border-b border-gray-200 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                <tr>
                  <th className="px-6 py-3.5">Case Title & Category</th>
                  <th className="px-6 py-3.5">Client</th>
                  <th className="px-6 py-3.5">Assigned Lawyer</th>
                  <th className="px-6 py-3.5">Urgency</th>
                  <th className="px-6 py-3.5">Status</th>
                  <th className="px-6 py-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {cases.map((c: any) => {
                  const client = c.client || {};
                  const lawyer = c.assignedLawyer?.user || c.assignedLawyer || {};
                  return (
                    <tr key={c._id} className="hover:bg-gray-50/80 transition-colors">
                      <td className="px-6 py-4">
                        <p className="font-semibold text-gray-900 truncate max-w-xs">{c.title}</p>
                        <p className="text-xs text-gray-500">{c.category} • {c.location || "N/A"}</p>
                      </td>
                      <td className="px-6 py-4 text-xs font-medium text-gray-800">{client.fullName || "N/A"}</td>
                      <td className="px-6 py-4 text-xs font-medium text-gray-800">{lawyer.fullName || "Unassigned"}</td>
                      <td className="px-6 py-4">
                        <span
                          className={`px-2 py-0.5 rounded text-xs font-bold ${
                            c.urgency?.toLowerCase().includes("urgent") || c.urgency?.toLowerCase().includes("high")
                              ? "bg-red-100 text-red-800"
                              : "bg-gray-100 text-gray-700"
                          }`}
                        >
                          {c.urgency || "Flexible"}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <select
                          value={c.status}
                          onChange={(e) => updateStatusMutation.mutate({ caseId: c._id, status: e.target.value })}
                          className="px-2.5 py-1 bg-gray-50 border border-gray-200 rounded text-xs font-semibold text-gray-800 focus:outline-none"
                        >
                          <option value="Submitted">Submitted</option>
                          <option value="In Progress">In Progress</option>
                          <option value="Closed">Closed</option>
                          <option value="Rejected">Rejected</option>
                        </select>
                      </td>
                      <td className="px-6 py-4 text-right">
                        <Link
                          href={`/cases/${c._id}`}
                          className="inline-flex items-center gap-1 text-xs font-semibold text-gray-700 hover:text-black bg-gray-100 px-3 py-1.5 rounded-lg transition-colors"
                        >
                          <Eye className="w-3.5 h-3.5" /> Details
                        </Link>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="px-6 py-4 border-t border-gray-100 flex items-center justify-between text-xs text-gray-500 font-medium">
            <span>Page {page} of {totalPages}</span>
            <div className="flex gap-2">
              <button
                disabled={page <= 1}
                onClick={() => setPage(page - 1)}
                className="px-3 py-1.5 bg-gray-100 rounded-md disabled:opacity-50 font-semibold"
              >
                Previous
              </button>
              <button
                disabled={page >= totalPages}
                onClick={() => setPage(page + 1)}
                className="px-3 py-1.5 bg-gray-100 rounded-md disabled:opacity-50 font-semibold"
              >
                Next
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

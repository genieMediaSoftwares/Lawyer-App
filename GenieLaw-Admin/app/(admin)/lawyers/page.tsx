"use client";

import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Search, Filter, Eye, ShieldCheck, ShieldAlert, CheckCircle, XCircle, Ban, RefreshCw } from "lucide-react";
import { formatDate } from "@/lib/utils";
import Link from "next/link";
import { toast } from "sonner";

export default function LawyersPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [verificationStatus, setVerificationStatus] = useState("all");
  const [page, setPage] = useState(1);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["admin", "lawyers", search, verificationStatus, page],
    queryFn: () => adminApi.getLawyers({ page, limit: 15, search, verificationStatus }),
  });

  const updateStatusMutation = useMutation({
    mutationFn: ({ lawyerId, data }: { lawyerId: string; data: any }) =>
      adminApi.updateLawyerStatus(lawyerId, data),
    onSuccess: () => {
      toast.success("Lawyer status updated successfully");
      queryClient.invalidateQueries({ queryKey: ["admin", "lawyers"] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Failed to update status");
    },
  });

  const lawyers = data?.data || [];
  const totalPages = data?.pages || 1;

  return (
    <div className="space-y-6">
      {/* Title */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Lawyer Management</h1>
          <p className="text-sm text-gray-500">Manage registered advocate profiles, verification badges, and account access</p>
        </div>
        <Link
          href="/lawyer-verification"
          className="px-4 py-2 bg-black hover:bg-gray-800 text-white font-semibold rounded-lg shadow-sm text-sm transition-all flex items-center gap-2"
        >
          <ShieldCheck className="w-4 h-4 text-gold" />
          <span>Verification Hub</span>
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
            placeholder="Search name, specialization, bar number..."
            className="w-full pl-9 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-gold/50"
          />
        </div>

        <div className="flex items-center gap-3 w-full sm:w-auto">
          <Filter className="w-4 h-4 text-gray-400" />
          <select
            value={verificationStatus}
            onChange={(e) => {
              setVerificationStatus(e.target.value);
              setPage(1);
            }}
            className="px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-800 font-medium focus:outline-none focus:ring-2 focus:ring-gold/50"
          >
            <option value="all">All Verification Statuses</option>
            <option value="verified">Verified Only</option>
            <option value="pending">Pending Verification</option>
            <option value="rejected">Rejected</option>
          </select>
        </div>
      </div>

      {/* Lawyers Table */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500">Loading lawyer directory...</div>
        ) : isError ? (
          <div className="p-12 text-center text-sm text-red-500">Error loading lawyers directory</div>
        ) : lawyers.length === 0 ? (
          <div className="p-12 text-center text-sm text-gray-400">No lawyers found matching criteria</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-gray-50 border-b border-gray-200 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                <tr>
                  <th className="px-6 py-3.5">Advocate</th>
                  <th className="px-6 py-3.5">Specialization</th>
                  <th className="px-6 py-3.5">Bar Number</th>
                  <th className="px-6 py-3.5">Verification</th>
                  <th className="px-6 py-3.5">Account</th>
                  <th className="px-6 py-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {lawyers.map((l: any) => {
                  const u = l.user || {};
                  return (
                    <tr key={l._id} className="hover:bg-gray-50/80 transition-colors">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-full bg-gold/20 flex items-center justify-center font-bold text-gray-800 text-xs">
                            {u.fullName ? u.fullName[0].toUpperCase() : "L"}
                          </div>
                          <div>
                            <p className="font-semibold text-gray-900">{u.fullName || "N/A"}</p>
                            <p className="text-xs text-gray-500">{u.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-gray-700 font-medium">{l.specialization || "General"}</td>
                      <td className="px-6 py-4 font-mono text-xs text-gray-600">{l.barCouncilNumber || "N/A"}</td>
                      <td className="px-6 py-4">
                        <span
                          className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold ${
                            l.verificationStatus === "verified"
                              ? "bg-emerald-100 text-emerald-800"
                              : l.verificationStatus === "rejected"
                              ? "bg-red-100 text-red-800"
                              : "bg-amber-100 text-amber-800"
                          }`}
                        >
                          {l.verificationStatus === "verified" && <CheckCircle className="w-3 h-3" />}
                          {l.verificationStatus === "rejected" && <XCircle className="w-3 h-3" />}
                          {l.verificationStatus || "pending"}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span
                          className={`px-2 py-0.5 rounded text-xs font-semibold ${
                            u.isActive !== false ? "bg-green-50 text-green-700" : "bg-red-50 text-red-700"
                          }`}
                        >
                          {u.isActive !== false ? "Active" : "Suspended"}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-right space-x-2">
                        <Link
                          href={`/lawyers/${l._id}`}
                          className="inline-flex items-center gap-1 text-xs font-semibold text-gray-700 hover:text-black bg-gray-100 px-3 py-1.5 rounded-lg transition-colors"
                        >
                          <Eye className="w-3.5 h-3.5" /> View
                        </Link>

                        {u.isActive !== false ? (
                          <button
                            onClick={() => updateStatusMutation.mutate({ lawyerId: l._id, data: { isActive: false } })}
                            className="inline-flex items-center gap-1 text-xs font-semibold text-red-700 bg-red-50 hover:bg-red-100 px-3 py-1.5 rounded-lg transition-colors"
                          >
                            <Ban className="w-3.5 h-3.5" /> Suspend
                          </button>
                        ) : (
                          <button
                            onClick={() => updateStatusMutation.mutate({ lawyerId: l._id, data: { isActive: true } })}
                            className="inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 bg-emerald-50 hover:bg-emerald-100 px-3 py-1.5 rounded-lg transition-colors"
                          >
                            <RefreshCw className="w-3.5 h-3.5" /> Reactivate
                          </button>
                        )}
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

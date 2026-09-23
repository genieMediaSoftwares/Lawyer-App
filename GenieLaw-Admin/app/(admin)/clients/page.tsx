"use client";

import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Search, Filter, Eye, Ban, RefreshCw } from "lucide-react";
import { formatDate } from "@/lib/utils";
import Link from "next/link";
import { toast } from "sonner";

export default function ClientsPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [page, setPage] = useState(1);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["admin", "clients", search, status, page],
    queryFn: () => adminApi.getClients({ page, limit: 15, search, status }),
  });

  const updateStatusMutation = useMutation({
    mutationFn: ({ clientId, isActive }: { clientId: string; isActive: boolean }) =>
      adminApi.updateClientStatus(clientId, isActive),
    onSuccess: () => {
      toast.success("Client status updated successfully");
      queryClient.invalidateQueries({ queryKey: ["admin", "clients"] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Failed to update client status");
    },
  });

  const clients = data?.data || [];
  const totalPages = data?.pages || 1;

  return (
    <div className="space-y-6">
      {/* Title */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Client Management</h1>
        <p className="text-sm text-gray-500">View and manage registered clients and account statuses</p>
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
            placeholder="Search name, email, phone..."
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
            <option value="all">All Accounts</option>
            <option value="active">Active Only</option>
            <option value="inactive">Inactive / Suspended</option>
          </select>
        </div>
      </div>

      {/* Clients Table */}
      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500">Loading client records...</div>
        ) : isError ? (
          <div className="p-12 text-center text-sm text-red-500">Error loading client directory</div>
        ) : clients.length === 0 ? (
          <div className="p-12 text-center text-sm text-gray-400">No client records found</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-gray-50 border-b border-gray-200 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                <tr>
                  <th className="px-6 py-3.5">Client</th>
                  <th className="px-6 py-3.5">Contact</th>
                  <th className="px-6 py-3.5">Location</th>
                  <th className="px-6 py-3.5">Cases</th>
                  <th className="px-6 py-3.5">Status</th>
                  <th className="px-6 py-3.5">Joined</th>
                  <th className="px-6 py-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {clients.map((c: any) => (
                  <tr key={c._id} className="hover:bg-gray-50/80 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-full bg-gray-100 flex items-center justify-center font-bold text-gray-800 text-xs">
                          {c.fullName ? c.fullName[0].toUpperCase() : "C"}
                        </div>
                        <span className="font-semibold text-gray-900">{c.fullName || "N/A"}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-xs">
                      <p className="text-gray-900 font-medium">{c.email}</p>
                      <p className="text-gray-500">{c.mobile || "N/A"}</p>
                    </td>
                    <td className="px-6 py-4 text-gray-700 text-xs font-medium">{c.location || "N/A"}</td>
                    <td className="px-6 py-4 font-bold text-gray-800 text-xs">{c.casesCount || 0} Cases</td>
                    <td className="px-6 py-4">
                      <span
                        className={`px-2 py-0.5 rounded text-xs font-semibold ${
                          c.isActive !== false ? "bg-green-50 text-green-700" : "bg-red-50 text-red-700"
                        }`}
                      >
                        {c.isActive !== false ? "Active" : "Suspended"}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-xs text-gray-500">{formatDate(c.createdAt)}</td>
                    <td className="px-6 py-4 text-right space-x-2">
                      <Link
                        href={`/clients/${c._id}`}
                        className="inline-flex items-center gap-1 text-xs font-semibold text-gray-700 hover:text-black bg-gray-100 px-3 py-1.5 rounded-lg transition-colors"
                      >
                        <Eye className="w-3.5 h-3.5" /> Profile
                      </Link>

                      {c.isActive !== false ? (
                        <button
                          onClick={() => updateStatusMutation.mutate({ clientId: c._id, isActive: false })}
                          className="inline-flex items-center gap-1 text-xs font-semibold text-red-700 bg-red-50 hover:bg-red-100 px-3 py-1.5 rounded-lg transition-colors"
                        >
                          <Ban className="w-3.5 h-3.5" /> Suspend
                        </button>
                      ) : (
                        <button
                          onClick={() => updateStatusMutation.mutate({ clientId: c._id, isActive: true })}
                          className="inline-flex items-center gap-1 text-xs font-semibold text-emerald-700 bg-emerald-50 hover:bg-emerald-100 px-3 py-1.5 rounded-lg transition-colors"
                        >
                          <RefreshCw className="w-3.5 h-3.5" /> Reactivate
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
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

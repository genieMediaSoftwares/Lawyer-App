"use client";

import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { ShieldAlert, Search, Filter } from "lucide-react";
import { formatDateTime } from "@/lib/utils";

export default function AuditLogsPage() {
  const [action, setAction] = useState("all");
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery({
    queryKey: ["admin", "audit-logs", action, page],
    queryFn: () => adminApi.getAuditLogs({ page, limit: 30, action }),
  });

  const logs = data?.data || [];
  const totalPages = data?.pages || 1;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">System Audit Logs</h1>
        <p className="text-sm text-gray-500">Immutable chronological record of administrative actions and security events</p>
      </div>

      <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Filter className="w-4 h-4 text-gray-400" />
          <select
            value={action}
            onChange={(e) => { setAction(e.target.value); setPage(1); }}
            className="px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-800 font-medium focus:outline-none"
          >
            <option value="all">All Audit Events</option>
            <option value="verify_lawyer">Lawyer Verification</option>
            <option value="update_lawyer_status">Lawyer Status Change</option>
            <option value="update_client_status">Client Status Change</option>
            <option value="process_refund">Refund Processed</option>
            <option value="update_legal_document">Legal Document Change</option>
          </select>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500">Loading audit log entries...</div>
        ) : logs.length === 0 ? (
          <div className="p-12 text-center text-sm text-gray-400">No recorded audit logs</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-gray-50 border-b border-gray-200 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                <tr>
                  <th className="px-6 py-3.5">Timestamp</th>
                  <th className="px-6 py-3.5">Admin User</th>
                  <th className="px-6 py-3.5">Action Code</th>
                  <th className="px-6 py-3.5">Target</th>
                  <th className="px-6 py-3.5">IP Address</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {logs.map((log: any) => (
                  <tr key={log._id} className="hover:bg-gray-50/80 transition-colors">
                    <td className="px-6 py-4 text-xs font-mono text-gray-600">{formatDateTime(log.createdAt)}</td>
                    <td className="px-6 py-4 font-semibold text-gray-900">{log.performedBy?.fullName || "Admin"}</td>
                    <td className="px-6 py-4">
                      <span className="px-2.5 py-1 rounded bg-gray-100 font-mono text-xs font-bold text-gray-800">
                        {log.action}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-xs text-gray-600">
                      {log.targetModel} <span className="font-mono text-gray-400">{log.targetId ? `(#${log.targetId})` : ""}</span>
                    </td>
                    <td className="px-6 py-4 font-mono text-xs text-gray-500">{log.ipAddress || "::1"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

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

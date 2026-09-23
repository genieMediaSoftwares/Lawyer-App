"use client";

import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Search, FileText, Download, Shield } from "lucide-react";
import { formatDate } from "@/lib/utils";

export default function DocumentsPage() {
  const [search, setSearch] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["admin", "documents", search],
    queryFn: () => adminApi.getDocuments({ search }),
  });

  const documents = data?.data || [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Document Management</h1>
        <p className="text-sm text-gray-500">Secure overview of case and user uploaded documents with RBAC controls</p>
      </div>

      <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm flex items-center justify-between">
        <div className="relative w-full sm:w-80">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search document title, filename..."
            className="w-full pl-9 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-gold/50"
          />
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500">Loading documents index...</div>
        ) : documents.length === 0 ? (
          <div className="p-12 text-center text-sm text-gray-400">No documents found</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-gray-50 border-b border-gray-200 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                <tr>
                  <th className="px-6 py-3.5">Document Title</th>
                  <th className="px-6 py-3.5">Uploaded By</th>
                  <th className="px-6 py-3.5">Category</th>
                  <th className="px-6 py-3.5">Date</th>
                  <th className="px-6 py-3.5 text-right">Access</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {documents.map((d: any) => (
                  <tr key={d._id} className="hover:bg-gray-50/80 transition-colors">
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <FileText className="w-4 h-4 text-gold shrink-0" />
                        <div>
                          <p className="font-semibold text-gray-900">{d.title || d.fileName || "Document"}</p>
                          <p className="text-xs text-gray-500 font-mono">{d.fileName}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-xs font-medium text-gray-800">{d.user?.fullName || "N/A"}</td>
                    <td className="px-6 py-4 text-xs text-gray-700">{d.category || "General"}</td>
                    <td className="px-6 py-4 text-xs text-gray-500">{formatDate(d.createdAt)}</td>
                    <td className="px-6 py-4 text-right">
                      {d.fileUrl || d.url ? (
                        <a
                          href={d.fileUrl || d.url}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center gap-1 text-xs font-semibold text-gold-hover bg-gold/10 hover:bg-gold/20 px-3 py-1.5 rounded-lg transition-colors"
                        >
                          <Download className="w-3.5 h-3.5" /> Download
                        </a>
                      ) : (
                        <span className="text-xs text-gray-400">Restricted</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

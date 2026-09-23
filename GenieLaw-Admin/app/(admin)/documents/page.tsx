"use client";

import React, { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import {
  Search,
  FileText,
  Filter,
  Download,
  Trash2,
  AlertTriangle,
  ChevronRight,
  Briefcase,
  File as FileIcon,
} from "lucide-react";
import { formatDate } from "@/lib/utils";
import { cn } from "@/lib/utils";

export default function DocumentsPage() {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["admin", "documents", search, page],
    queryFn: () => adminApi.getDocuments({ page, limit: 20, search }),
  });

  const documents = data?.data || [];
  const totalPages = data?.pages || 1;

  const fileExt = (url?: string) => {
    if (!url) return "FILE";
    const m = url.match(/\.([a-z0-9]+)(?:\?|$)/i);
    return m ? m[1].toUpperCase() : "FILE";
  };

  const extColor = (ext: string) => {
    if (ext === "PDF") return "bg-red-100 text-red-700 border-red-200";
    if (["DOC", "DOCX"].includes(ext)) return "bg-blue-100 text-blue-700 border-blue-200";
    if (["JPG", "JPEG", "PNG"].includes(ext)) return "bg-violet-100 text-violet-700 border-violet-200";
    return "bg-slate-100 text-slate-700 border-slate-200";
  };

  return (
    <div className="page-container">
      <div>
        <h1 className="section-title">Document Repository</h1>
        <p className="section-subtitle">Browse and manage all case-related documents uploaded on the platform</p>
      </div>

      <div className="card">
        <div className="card-body">
          <div className="relative w-full sm:w-96">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 w-4 h-4" />
            <input
              type="text"
              value={search}
              onChange={(e) => { setSearch(e.target.value); setPage(1); }}
              placeholder="Search filename, case ID..."
              className="search-input"
            />
          </div>
        </div>
      </div>

      <div className="card">
        {isLoading ? (
          <div className="loading-state"><div className="w-10 h-10 border-4 border-gold border-t-transparent rounded-full animate-spin mb-3" /><p className="text-sm text-slate-500">Loading documents...</p></div>
        ) : isError ? (
          <div className="empty-state"><AlertTriangle className="w-10 h-10 text-red-400 mb-2" /><p className="text-sm font-semibold text-red-600">Failed to load documents</p></div>
        ) : documents.length === 0 ? (
          <div className="empty-state"><FileText className="w-10 h-10 text-slate-300 mb-2" /><p className="text-sm font-semibold text-slate-700">No documents found</p></div>
        ) : (
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Document</th>
                  <th>Type</th>
                  <th>Case Reference</th>
                  <th>Uploaded</th>
                  <th className="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {documents.map((d: any) => {
                  const ext = fileExt(d.fileUrl || d.url || d.name);
                  return (
                    <tr key={d._id}>
                      <td>
                        <div className="flex items-center gap-3">
                          <span className={cn("px-2 py-1 rounded text-[10px] font-bold border", extColor(ext))}>{ext}</span>
                          <div>
                            <p className="font-semibold text-slate-900 text-sm">{d.fileName || d.name || "Untitled"}</p>
                            <p className="text-xs text-slate-500">{d.description || "Case document"}</p>
                          </div>
                        </div>
                      </td>
                      <td className="text-xs text-slate-600 font-medium">{d.documentType || d.category || "General"}</td>
                      <td className="text-xs font-medium text-slate-700">{d.case?.caseNumber || d.case?.title || "—"}</td>
                      <td className="text-xs text-slate-500">{formatDate(d.createdAt)}</td>
                      <td className="text-right">
                        <div className="flex items-center justify-end gap-2">
                          <a href={d.fileUrl || d.url} target="_blank" rel="noopener noreferrer" className="action-link">
                            <Download className="w-3.5 h-3.5" /> Download
                          </a>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        {totalPages > 1 && (
          <div className="px-6 py-4 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500 font-medium">
            <span>Page {page} of {totalPages}</span>
            <div className="flex gap-2">
              <button disabled={page <= 1} onClick={() => setPage(page - 1)} className="pagination-btn">Previous</button>
              <button disabled={page >= totalPages} onClick={() => setPage(page + 1)} className="pagination-btn">Next</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
"use client";

import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Scale, Plus, CheckCircle } from "lucide-react";
import { formatDate } from "@/lib/utils";
import { toast } from "sonner";

export default function LegalPage() {
  const queryClient = useQueryClient();
  const [type, setType] = useState("platform_terms");
  const [version, setVersion] = useState("1.0");
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");

  const { data: legalDocs = [], isLoading } = useQuery({
    queryKey: ["admin", "legal"],
    queryFn: adminApi.getLegalDocuments,
  });

  const createDocMutation = useMutation({
    mutationFn: (data: any) => adminApi.createLegalDocument(data),
    onSuccess: () => {
      toast.success("Legal document version published");
      setTitle("");
      setContent("");
      queryClient.invalidateQueries({ queryKey: ["admin", "legal"] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Failed to publish document");
    },
  });

  const handlePublish = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !content) return;
    createDocMutation.mutate({
      type,
      version,
      title,
      content,
      isActive: true,
      requiresAcceptance: true,
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Legal Documents Management</h1>
        <p className="text-sm text-gray-500">Publish and manage Terms of Service, Privacy Policies, and AI Disclaimers</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Publish Form */}
        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
          <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
            <Plus className="w-4 h-4 text-gold" /> Publish Legal Document
          </h2>
          <form onSubmit={handlePublish} className="space-y-4 text-sm">
            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Document Type</label>
              <select
                value={type}
                onChange={(e) => setType(e.target.value)}
                className="w-full px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm font-medium focus:outline-none focus:ring-2 focus:ring-gold/50"
              >
                <option value="platform_terms">Platform Terms & Conditions</option>
                <option value="client_terms">Client Terms</option>
                <option value="lawyer_terms">Lawyer Terms</option>
                <option value="privacy_policy">Privacy Policy</option>
                <option value="refund_policy">Payment & Refund Policy</option>
                <option value="ai_disclaimer">AI Legal Advice Disclaimer</option>
                <option value="communication_consent">Communication Consent</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Version String</label>
              <input
                type="text"
                value={version}
                onChange={(e) => setVersion(e.target.value)}
                placeholder="e.g., 1.0"
                required
                className="w-full px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gold/50"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Document Title</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g., Terms of Service (2026 Edition)"
                required
                className="w-full px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gold/50"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">Legal Text Content</label>
              <textarea
                value={content}
                onChange={(e) => setContent(e.target.value)}
                placeholder="Paste legal agreement body text here..."
                rows={6}
                required
                className="w-full px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gold/50 font-mono text-xs"
              />
            </div>

            <button
              type="submit"
              disabled={createDocMutation.isPending}
              className="w-full py-2.5 bg-gold hover:bg-gold-hover text-black font-extrabold rounded-lg shadow-sm transition-colors text-xs"
            >
              Publish Active Document Version
            </button>
          </form>
        </div>

        {/* Existing Legal Documents */}
        <div className="lg:col-span-2 bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
          {isLoading ? (
            <div className="p-12 text-center text-sm text-gray-500">Loading legal documents...</div>
          ) : legalDocs.length === 0 ? (
            <div className="p-12 text-center text-sm text-gray-400">No published legal documents</div>
          ) : (
            <div className="divide-y divide-gray-100">
              {legalDocs.map((doc: any) => (
                <div key={doc._id} className="p-5 space-y-2 hover:bg-gray-50/80 transition-colors">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="font-bold text-gray-900 text-sm">{doc.title}</span>
                      <span className="px-2 py-0.5 bg-gray-100 font-mono text-xs rounded text-gray-700 font-semibold">
                        v{doc.version}
                      </span>
                    </div>
                    {doc.isActive && (
                      <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 flex items-center gap-1">
                        <CheckCircle className="w-3 h-3" /> Active Published Version
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-gray-500">
                    Type: <span className="font-semibold text-gray-700">{doc.type}</span> • Effective Date: {formatDate(doc.effectiveDate)}
                  </p>
                  <p className="text-xs text-gray-600 line-clamp-2 bg-gray-50 p-2.5 rounded border border-gray-100 font-mono">
                    {doc.content}
                  </p>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

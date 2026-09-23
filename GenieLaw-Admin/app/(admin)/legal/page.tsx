"use client";

import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Search, FileText, Edit3, Plus, AlertTriangle, ChevronRight, Save } from "lucide-react";
import Link from "next/link";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

const LEGAL_DOCS = [
  { key: "terms", label: "Terms & Conditions", description: "Platform terms for all users", icon: "📋" },
  { key: "privacy", label: "Privacy Policy", description: "Data handling and privacy notices", icon: "🔒" },
  { key: "lawyerTerms", label: "Lawyer Terms", description: "Advocate-specific agreement", icon: "⚖️" },
  { key: "clientTerms", label: "Client Terms", description: "Client service terms", icon: "📑" },
  { key: "aiDisclaimer", label: "AI Disclaimer", description: "Limitations for AI-generated content", icon: "🤖" },
  { key: "paymentPolicy", label: "Payment & Refund Policy", description: "Transaction rules and refund guidelines", icon: "💳" },
];

export default function LegalDocumentsPage() {
  const [editingDoc, setEditingDoc] = useState<string | null>(null);
  const [content, setContent] = useState("");

  const { data: documents = {}, isLoading } = useQuery({
    queryKey: ["admin", "legal-docs"],
    queryFn: adminApi.getLegalDocuments,
  });

  const updateMutation = useMutation({
    mutationFn: ({ key, content }: { key: string; content: string }) => adminApi.updateLegalDocument(key, content),
    onSuccess: () => {
      toast.success("Legal document updated");
      setEditingDoc(null);
      setContent("");
    },
    onError: () => toast.error("Failed to update document"),
  });

  const handleEdit = (key: string, currentContent: string) => {
    setEditingDoc(key);
    setContent(currentContent || "");
  };

  return (
    <div className="page-container">
      <div>
        <h1 className="section-title">Legal Documents</h1>
        <p className="section-subtitle">Manage platform legal policies, terms of service, and disclosures</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="space-y-3">
          {LEGAL_DOCS.map((doc) => (
            <button
              key={doc.key}
              onClick={() => {
                if (editingDoc === doc.key) return;
                handleEdit(doc.key, (documents as any)[doc.key]?.content || "");
              }}
              className={cn(
                "w-full text-left p-4 rounded-xl border transition-all",
                editingDoc === doc.key
                  ? "border-gold bg-gold-light shadow-sm"
                  : "border-slate-200 hover:border-slate-300 hover:shadow-sm bg-white"
              )}
            >
              <div className="text-2xl mb-1">{doc.icon}</div>
              <p className="text-sm font-semibold text-slate-900">{doc.label}</p>
              <p className="text-xs text-slate-500 mt-0.5">{doc.description}</p>
              {editingDoc === doc.key && <p className="text-[10px] text-gold-hover font-bold uppercase tracking-wider mt-1">Editing now...</p>}
            </button>
          ))}
        </div>

        <div className="lg:col-span-2 card">
          {editingDoc ? (
            <>
              <div className="card-header">
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-base font-bold text-slate-900">{LEGAL_DOCS.find(d => d.key === editingDoc)?.label}</h2>
                    <p className="text-xs text-slate-500 mt-0.5">Edit document content — changes apply immediately</p>
                  </div>
                  <button
                    onClick={() => updateMutation.mutate({ key: editingDoc, content })}
                    disabled={updateMutation.isPending}
                    className="btn btn-primary text-xs px-4 py-2"
                  >
                    <Save className="w-3.5 h-3.5" /> {updateMutation.isPending ? "Saving..." : "Publish"}
                  </button>
                </div>
              </div>
              <div className="card-body">
                <textarea
                  value={content}
                  onChange={(e) => setContent(e.target.value)}
                  placeholder="Enter legal document content..."
                  rows={20}
                  className="form-textarea w-full font-mono text-sm leading-relaxed"
                />
              </div>
            </>
          ) : (
            <div className="card-body">
              <div className="empty-state">
                <FileText className="w-12 h-12 text-slate-300 mb-3" />
                <p className="text-sm font-semibold text-slate-700">Select a document to edit</p>
                <p className="text-xs text-slate-400 mt-1">Choose a legal document from the sidebar</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
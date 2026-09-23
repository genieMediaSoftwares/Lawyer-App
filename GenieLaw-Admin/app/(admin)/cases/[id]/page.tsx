"use client";

import React from "react";
import { useParams } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { ArrowLeft, Briefcase, Calendar, MapPin, User, FileText, CheckCircle2 } from "lucide-react";
import { formatDate } from "@/lib/utils";
import Link from "next/link";
import { toast } from "sonner";

export default function CaseDetailPage() {
  const routeParams = useParams<{ id: string }>();
  const caseId = Array.isArray(routeParams?.id) ? routeParams.id[0] : routeParams?.id || "";
  const queryClient = useQueryClient();

  const { data: caseItem, isLoading, isError } = useQuery({
    queryKey: ["admin", "case", caseId],
    queryFn: () => adminApi.getCaseById(caseId),
  });

  const updateStatusMutation = useMutation({
    mutationFn: (status: string) => adminApi.updateCaseStatus(caseId, { status }),
    onSuccess: () => {
      toast.success("Case status updated");
      queryClient.invalidateQueries({ queryKey: ["admin", "case", caseId] });
    },
  });

  if (isLoading) return <div className="p-12 text-center text-gray-500">Loading case details...</div>;
  if (isError || !caseItem) return <div className="p-12 text-center text-red-500">Case record not found</div>;

  const client = caseItem.client || {};
  const lawyer = caseItem.assignedLawyer?.user || caseItem.assignedLawyer || {};
  const proposals = caseItem.proposals || [];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/cases" className="p-2 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
          <ArrowLeft className="w-4 h-4 text-gray-700" />
        </Link>
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">{caseItem.title}</h1>
          <p className="text-sm text-gray-500">Case Category: {caseItem.category} • Created: {formatDate(caseItem.createdAt)}</p>
        </div>
      </div>

      {/* Main Info Card */}
      <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-gray-100 pb-4">
          <div>
            <span className="text-xs text-gray-400 font-semibold uppercase tracking-wider block">Current Status</span>
            <div className="flex items-center gap-2 mt-1">
              <span className="px-3 py-1 bg-gold/15 text-gold-hover border border-gold/30 rounded-full font-bold text-xs">
                {caseItem.status}
              </span>
              <span className="text-xs font-semibold text-gray-500">Urgency: {caseItem.urgency || "Flexible"}</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => updateStatusMutation.mutate("In Progress")}
              className="px-3 py-1.5 bg-blue-600 text-white rounded-lg font-semibold text-xs hover:bg-blue-700"
            >
              Mark In Progress
            </button>
            <button
              onClick={() => updateStatusMutation.mutate("Closed")}
              className="px-3 py-1.5 bg-emerald-600 text-white rounded-lg font-semibold text-xs hover:bg-emerald-700"
            >
              Mark Closed
            </button>
          </div>
        </div>

        <div>
          <h3 className="text-sm font-bold text-gray-900 mb-1">Description</h3>
          <p className="text-sm text-gray-700 leading-relaxed whitespace-pre-line">{caseItem.description}</p>
        </div>
      </div>

      {/* Client and Lawyer Info */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-3">
          <h3 className="text-base font-bold text-gray-900 flex items-center gap-2">
            <User className="w-4 h-4 text-gold" /> Client Information
          </h3>
          <div className="text-sm space-y-1.5 text-gray-700">
            <p><span className="font-semibold">Name:</span> {client.fullName || "N/A"}</p>
            <p><span className="font-semibold">Email:</span> {client.email || "N/A"}</p>
            <p><span className="font-semibold">Mobile:</span> {client.mobile || "N/A"}</p>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-3">
          <h3 className="text-base font-bold text-gray-900 flex items-center gap-2">
            <Briefcase className="w-4 h-4 text-gold" /> Assigned Lawyer
          </h3>
          {lawyer.fullName ? (
            <div className="text-sm space-y-1.5 text-gray-700">
              <p><span className="font-semibold">Name:</span> {lawyer.fullName}</p>
              <p><span className="font-semibold">Email:</span> {lawyer.email}</p>
              <p><span className="font-semibold">Mobile:</span> {lawyer.mobile || "N/A"}</p>
            </div>
          ) : (
            <p className="text-xs text-gray-400 py-2">No advocate assigned yet</p>
          )}
        </div>
      </div>
    </div>
  );
}

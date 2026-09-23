"use client";

import React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { ShieldCheck, CheckCircle, XCircle, FileText, Eye, AlertCircle } from "lucide-react";
import { formatDate } from "@/lib/utils";
import Link from "next/link";
import { toast } from "sonner";

export default function LawyerVerificationPage() {
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["admin", "lawyers", "pending"],
    queryFn: () => adminApi.getLawyers({ verificationStatus: "pending", limit: 50 }),
  });

  const verifyMutation = useMutation({
    mutationFn: ({ lawyerId, data }: { lawyerId: string; data: any }) =>
      adminApi.verifyLawyer(lawyerId, data),
    onSuccess: (res) => {
      toast.success(res.message || "Lawyer status updated");
      queryClient.invalidateQueries({ queryKey: ["admin", "lawyers"] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Action failed");
    },
  });

  const lawyers = data?.data || [];

  return (
    <div className="space-y-6">
      {/* Title */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Lawyer Verification Center</h1>
          <p className="text-sm text-gray-500">Review submitted bar credentials and verify advocate profiles</p>
        </div>
        <div className="px-3 py-1.5 bg-amber-50 border border-amber-200 text-amber-800 rounded-lg text-xs font-semibold flex items-center gap-1.5">
          <AlertCircle className="w-4 h-4" /> {lawyers.length} Advocates Pending Review
        </div>
      </div>

      {/* Grid of Verification Cards */}
      {isLoading ? (
        <div className="p-12 text-center text-sm text-gray-500">Loading pending verifications...</div>
      ) : lawyers.length === 0 ? (
        <div className="bg-white p-12 rounded-xl border border-gray-200 text-center text-gray-500">
          <ShieldCheck className="w-12 h-12 text-emerald-500 mx-auto mb-3" />
          <p className="font-bold text-gray-900 text-base">All Verifications Cleared</p>
          <p className="text-xs text-gray-500 mt-1">There are currently no advocate applications awaiting review.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {lawyers.map((l: any) => {
            const u = l.user || {};
            return (
              <div key={l._id} className="bg-white p-5 rounded-xl border border-gray-200 shadow-sm flex flex-col justify-between space-y-4">
                <div>
                  <div className="flex items-center gap-3 mb-3">
                    <div className="w-11 h-11 rounded-full bg-gold/20 flex items-center justify-center font-bold text-gray-800 text-base">
                      {u.fullName ? u.fullName[0].toUpperCase() : "L"}
                    </div>
                    <div>
                      <h3 className="font-bold text-gray-900 text-sm">{u.fullName || "Advocate"}</h3>
                      <p className="text-xs text-gray-500">{l.specialization} Advocate</p>
                    </div>
                  </div>

                  <div className="space-y-2 text-xs text-gray-600 bg-gray-50 p-3 rounded-lg border border-gray-100">
                    <p><span className="font-semibold text-gray-700">Email:</span> {u.email}</p>
                    <p><span className="font-semibold text-gray-700">Mobile:</span> {u.mobile}</p>
                    <p><span className="font-semibold text-gray-700">Bar Number:</span> <span className="font-mono">{l.barCouncilNumber || "N/A"}</span></p>
                    <p><span className="font-semibold text-gray-700">Experience:</span> {l.experience} Years</p>
                  </div>

                  {l.barCertificate && (
                    <a
                      href={l.barCertificate}
                      target="_blank"
                      rel="noreferrer"
                      className="mt-3 p-2 bg-blue-50 text-blue-700 rounded-lg text-xs font-semibold flex items-center justify-between hover:bg-blue-100 transition-colors"
                    >
                      <span className="flex items-center gap-1.5"><FileText className="w-3.5 h-3.5" /> Bar Certificate</span>
                      <span>View File</span>
                    </a>
                  )}
                </div>

                <div className="flex items-center gap-2 pt-3 border-t border-gray-100">
                  <button
                    onClick={() => verifyMutation.mutate({ lawyerId: l._id, data: { status: "verified" } })}
                    className="flex-1 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-lg text-xs transition-colors flex items-center justify-center gap-1"
                  >
                    <CheckCircle className="w-3.5 h-3.5" /> Approve
                  </button>

                  <button
                    onClick={() => {
                      const reason = prompt("Enter rejection reason:");
                      if (reason) verifyMutation.mutate({ lawyerId: l._id, data: { status: "rejected", rejectionReason: reason } });
                    }}
                    className="flex-1 py-2 bg-red-600 hover:bg-red-700 text-white font-semibold rounded-lg text-xs transition-colors flex items-center justify-center gap-1"
                  >
                    <XCircle className="w-3.5 h-3.5" /> Reject
                  </button>

                  <Link
                    href={`/lawyers/${l._id}`}
                    className="p-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg transition-colors"
                    title="View Profile"
                  >
                    <Eye className="w-4 h-4" />
                  </Link>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

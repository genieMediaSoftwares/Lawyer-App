"use client";

import React from "react";
import { useParams } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { ArrowLeft, ShieldCheck, CheckCircle, XCircle, Award, FileText, Phone, Mail, MapPin, Calendar, Star, Briefcase } from "lucide-react";
import { formatDate } from "@/lib/utils";
import Link from "next/link";
import { toast } from "sonner";

export default function LawyerDetailPage() {
  const routeParams = useParams<{ id: string }>();
  const lawyerId = Array.isArray(routeParams?.id) ? routeParams.id[0] : routeParams?.id || "";
  const queryClient = useQueryClient();

  const { data: lawyer, isLoading, isError } = useQuery({
    queryKey: ["admin", "lawyer", lawyerId],
    queryFn: () => adminApi.getLawyerById(lawyerId),
  });

  const verifyMutation = useMutation({
    mutationFn: (data: { status: string; rejectionReason?: string }) =>
      adminApi.verifyLawyer(lawyerId, data),
    onSuccess: (res) => {
      toast.success(res.message || "Lawyer status updated");
      queryClient.invalidateQueries({ queryKey: ["admin", "lawyer", lawyerId] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Action failed");
    },
  });

  if (isLoading) return <div className="p-12 text-center text-gray-500">Loading lawyer profile...</div>;
  if (isError || !lawyer) return <div className="p-12 text-center text-red-500">Lawyer record not found</div>;

  const user = lawyer.user || {};
  const cases = lawyer.cases || [];
  const appointments = lawyer.appointments || [];
  const reviews = lawyer.reviews || [];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/lawyers" className="p-2 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
          <ArrowLeft className="w-4 h-4 text-gray-700" />
        </Link>
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">{user.fullName || "Advocate Profile"}</h1>
          <p className="text-sm text-gray-500">Bar Registration: {lawyer.barCouncilNumber || "N/A"}</p>
        </div>
      </div>

      {/* Main Profile Header Card */}
      <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 rounded-full bg-gold/20 border-2 border-gold flex items-center justify-center font-bold text-2xl text-gray-800">
            {user.fullName ? user.fullName[0].toUpperCase() : "L"}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-bold text-gray-900">{user.fullName}</h2>
              <span
                className={`px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                  lawyer.verificationStatus === "verified"
                    ? "bg-emerald-100 text-emerald-800"
                    : lawyer.verificationStatus === "rejected"
                    ? "bg-red-100 text-red-800"
                    : "bg-amber-100 text-amber-800"
                }`}
              >
                {lawyer.verificationStatus}
              </span>
            </div>
            <p className="text-sm font-semibold text-gold-hover mt-0.5">{lawyer.specialization} Advocate</p>
            <div className="flex flex-wrap gap-4 text-xs text-gray-500 mt-2">
              <span className="flex items-center gap-1"><Mail className="w-3.5 h-3.5" /> {user.email}</span>
              <span className="flex items-center gap-1"><Phone className="w-3.5 h-3.5" /> {user.mobile}</span>
              <span className="flex items-center gap-1"><MapPin className="w-3.5 h-3.5" /> {user.location || lawyer.officeAddress || "N/A"}</span>
            </div>
          </div>
        </div>

        {/* Verification Action buttons */}
        <div className="flex items-center gap-3">
          {lawyer.verificationStatus !== "verified" && (
            <button
              onClick={() => verifyMutation.mutate({ status: "verified" })}
              className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold rounded-lg shadow-sm text-sm transition-all flex items-center gap-1.5"
            >
              <CheckCircle className="w-4 h-4" /> Approve & Verify
            </button>
          )}

          {lawyer.verificationStatus !== "rejected" && (
            <button
              onClick={() => {
                const reason = prompt("Enter rejection reason:");
                if (reason) verifyMutation.mutate({ status: "rejected", rejectionReason: reason });
              }}
              className="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-semibold rounded-lg shadow-sm text-sm transition-all flex items-center gap-1.5"
            >
              <XCircle className="w-4 h-4" /> Reject Profile
            </button>
          )}
        </div>
      </div>

      {/* Details Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Professional Details */}
        <div className="space-y-6">
          <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
            <h3 className="text-base font-bold text-gray-900 border-b border-gray-100 pb-2">Professional Info</h3>
            <div className="text-sm space-y-3">
              <div>
                <span className="text-xs text-gray-400 font-medium block">Experience</span>
                <span className="font-semibold text-gray-800">{lawyer.experience} Years</span>
              </div>
              <div>
                <span className="text-xs text-gray-400 font-medium block">Consultation Fee</span>
                <span className="font-semibold text-gray-800">₹{lawyer.consultationFee || 0}</span>
              </div>
              <div>
                <span className="text-xs text-gray-400 font-medium block">Bar Council Registration</span>
                <span className="font-mono text-gray-800 font-semibold">{lawyer.barCouncilNumber || "N/A"}</span>
              </div>
              <div>
                <span className="text-xs text-gray-400 font-medium block">Rating</span>
                <div className="flex items-center gap-1 text-amber-500 font-bold">
                  <Star className="w-4 h-4 fill-amber-400" /> {lawyer.rating || 0} ({lawyer.totalReviews || 0} reviews)
                </div>
              </div>
            </div>
          </div>

          {/* Bar Certificate Preview */}
          <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
            <h3 className="text-base font-bold text-gray-900 border-b border-gray-100 pb-2 mb-3">Bar Certificate Document</h3>
            {lawyer.barCertificate ? (
              <a
                href={lawyer.barCertificate}
                target="_blank"
                rel="noreferrer"
                className="p-3 bg-gray-50 border border-gray-200 rounded-lg flex items-center justify-between text-sm hover:bg-gray-100 transition-colors"
              >
                <span className="flex items-center gap-2 font-medium text-gray-800">
                  <FileText className="w-4 h-4 text-gold" /> Bar Certificate.pdf
                </span>
                <span className="text-xs font-bold text-gold-hover">View File</span>
              </a>
            ) : (
              <p className="text-xs text-gray-400">No bar certificate uploaded by lawyer</p>
            )}
          </div>
        </div>

        {/* Right Assigned Cases & Appointments */}
        <div className="lg:col-span-2 space-y-6">
          {/* Associated Cases */}
          <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
            <h3 className="text-base font-bold text-gray-900 mb-3 flex items-center gap-2">
              <Briefcase className="w-4 h-4 text-gold" /> Associated Cases ({cases.length})
            </h3>
            {cases.length > 0 ? (
              <div className="divide-y divide-gray-100 text-sm">
                {cases.map((c: any) => (
                  <div key={c._id} className="py-3 flex items-center justify-between">
                    <div>
                      <p className="font-semibold text-gray-900">{c.title}</p>
                      <p className="text-xs text-gray-500">Client: {c.client?.fullName}</p>
                    </div>
                    <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-gray-100 text-gray-700">
                      {c.status}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-gray-400 py-2">No active cases assigned to this lawyer</p>
            )}
          </div>

          {/* Appointments */}
          <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
            <h3 className="text-base font-bold text-gray-900 mb-3 flex items-center gap-2">
              <Calendar className="w-4 h-4 text-gold" /> Recent Appointments ({appointments.length})
            </h3>
            {appointments.length > 0 ? (
              <div className="divide-y divide-gray-100 text-sm">
                {appointments.map((a: any) => (
                  <div key={a._id} className="py-3 flex items-center justify-between">
                    <div>
                      <p className="font-semibold text-gray-900">Client: {a.client?.fullName}</p>
                      <p className="text-xs text-gray-500">Slot: {a.timeSlot} • Mode: {a.mode}</p>
                    </div>
                    <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-50 text-blue-700">
                      {a.status}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-gray-400 py-2">No appointments scheduled</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

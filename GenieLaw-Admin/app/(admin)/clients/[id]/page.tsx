"use client";

import React, { use } from "react";
import { useQuery } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { ArrowLeft, Mail, Phone, MapPin, Briefcase, Calendar, FileText, AlertTriangle } from "lucide-react";
import { formatDate } from "@/lib/utils";
import Link from "next/link";

export default function ClientDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const resolvedParams = use(params);
  const clientId = resolvedParams.id;

  const { data: client, isLoading, isError } = useQuery({
    queryKey: ["admin", "client", clientId],
    queryFn: () => adminApi.getClientById(clientId),
  });

  if (isLoading) return <div className="p-12 text-center text-gray-500">Loading client profile...</div>;
  if (isError || !client) return <div className="p-12 text-center text-red-500">Client profile record not found</div>;

  const cases = client.cases || [];
  const appointments = client.appointments || [];
  const documents = client.documents || [];
  const issues = client.issues || [];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center gap-4">
        <Link href="/clients" className="p-2 bg-white border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors">
          <ArrowLeft className="w-4 h-4 text-gray-700" />
        </Link>
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">{client.fullName || "Client Profile"}</h1>
          <p className="text-sm text-gray-500">Member since {formatDate(client.createdAt)}</p>
        </div>
      </div>

      {/* Client Overview Card */}
      <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 rounded-full bg-gray-100 flex items-center justify-center font-bold text-2xl text-gray-800">
            {client.fullName ? client.fullName[0].toUpperCase() : "C"}
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-xl font-bold text-gray-900">{client.fullName}</h2>
              <span
                className={`px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                  client.isActive !== false ? "bg-emerald-100 text-emerald-800" : "bg-red-100 text-red-800"
                }`}
              >
                {client.isActive !== false ? "Active Account" : "Suspended"}
              </span>
            </div>
            <div className="flex flex-wrap gap-4 text-xs text-gray-500 mt-2">
              <span className="flex items-center gap-1"><Mail className="w-3.5 h-3.5" /> {client.email}</span>
              <span className="flex items-center gap-1"><Phone className="w-3.5 h-3.5" /> {client.mobile || "N/A"}</span>
              <span className="flex items-center gap-1"><MapPin className="w-3.5 h-3.5" /> {client.location || "N/A"}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Grid of Client Data */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Cases */}
        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <h3 className="text-base font-bold text-gray-900 mb-4 flex items-center gap-2">
            <Briefcase className="w-4 h-4 text-gold" /> Client Legal Cases ({cases.length})
          </h3>
          {cases.length > 0 ? (
            <div className="divide-y divide-gray-100 text-sm">
              {cases.map((c: any) => (
                <div key={c._id} className="py-3 flex items-center justify-between">
                  <div>
                    <p className="font-semibold text-gray-900">{c.title}</p>
                    <p className="text-xs text-gray-500">Lawyer: {c.assignedLawyer?.fullName || "Unassigned"}</p>
                  </div>
                  <span className="px-2 py-0.5 rounded text-xs font-semibold bg-gray-100 text-gray-700">
                    {c.status}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-xs text-gray-400 py-2">No legal cases opened by client</p>
          )}
        </div>

        {/* Appointments */}
        <div className="bg-white p-6 rounded-xl border border-gray-200 shadow-sm">
          <h3 className="text-base font-bold text-gray-900 mb-4 flex items-center gap-2">
            <Calendar className="w-4 h-4 text-gold" /> Scheduled Appointments ({appointments.length})
          </h3>
          {appointments.length > 0 ? (
            <div className="divide-y divide-gray-100 text-sm">
              {appointments.map((a: any) => (
                <div key={a._id} className="py-3 flex items-center justify-between">
                  <div>
                    <p className="font-semibold text-gray-900">Lawyer: {a.lawyer?.fullName || "N/A"}</p>
                    <p className="text-xs text-gray-500">Slot: {a.timeSlot} • Mode: {a.mode}</p>
                  </div>
                  <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-50 text-blue-700">
                    {a.status}
                  </span>
                </div>
              ))}
            </div>
          ) : (
            <p className="text-xs text-gray-400 py-2">No appointments found</p>
          )}
        </div>
      </div>
    </div>
  );
}

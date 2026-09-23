"use client";

import React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { AlertTriangle, CheckCircle, MessageSquare } from "lucide-react";
import { formatDate } from "@/lib/utils";
import { toast } from "sonner";

export default function DisputesPage() {
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["admin", "disputes"],
    queryFn: adminApi.getDisputes,
  });

  const updateTicketMutation = useMutation({
    mutationFn: ({ id, status }: { id: string; status: string }) =>
      adminApi.updateSupportTicket(id, status),
    onSuccess: () => {
      toast.success("Dispute status updated");
      queryClient.invalidateQueries({ queryKey: ["admin", "disputes"] });
    },
  });

  const disputes = data?.data || [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Disputes & Support Tickets</h1>
        <p className="text-sm text-gray-500">Manage client complaints, payment issues, and platform support cases</p>
      </div>

      <div className="space-y-4">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500">Loading disputes...</div>
        ) : disputes.length === 0 ? (
          <div className="bg-white p-12 rounded-xl border border-gray-200 text-center text-gray-400">
            <CheckCircle className="w-10 h-10 text-emerald-500 mx-auto mb-2" />
            <p className="font-bold text-gray-900">No Pending Disputes</p>
          </div>
        ) : (
          disputes.map((d: any) => (
            <div key={d._id} className="bg-white p-5 rounded-xl border border-gray-200 shadow-sm space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-bold text-gray-900 text-sm">{d.title}</h3>
                  <p className="text-xs text-gray-500">Category: {d.category} • Client: {d.clientId?.fullName || "N/A"}</p>
                </div>
                <select
                  value={d.status}
                  onChange={(e) => updateTicketMutation.mutate({ id: d._id, status: e.target.value })}
                  className="px-3 py-1 bg-gray-50 border border-gray-200 rounded-lg text-xs font-semibold text-gray-800"
                >
                  <option value="Pending">Pending</option>
                  <option value="Assigned">Assigned</option>
                  <option value="Resolved">Resolved</option>
                  <option value="Closed">Closed</option>
                </select>
              </div>

              <p className="text-sm text-gray-700 bg-gray-50 p-3 rounded-lg border border-gray-100">
                {d.description}
              </p>

              <div className="flex items-center justify-between text-xs text-gray-400 pt-2 border-t border-gray-100">
                <span>Filed on {formatDate(d.createdAt)}</span>
                <span className="font-semibold text-gray-700">Urgency: {d.urgency || "Flexible"}</span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

"use client";

import React from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Crown, CheckCircle } from "lucide-react";
import { formatDate } from "@/lib/utils";
import { toast } from "sonner";

export default function SubscriptionsPage() {
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["admin", "subscriptions"],
    queryFn: () => adminApi.getSubscriptions({ limit: 50 }),
  });

  const updateSubMutation = useMutation({
    mutationFn: ({ id, plan }: { id: string; plan: string }) =>
      adminApi.updateSubscription(id, { plan }),
    onSuccess: () => {
      toast.success("Subscription updated");
      queryClient.invalidateQueries({ queryKey: ["admin", "subscriptions"] });
    },
  });

  const subscriptions = data?.data || [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Lawyer Subscriptions</h1>
        <p className="text-sm text-gray-500">Manage advocate platform subscription tiers and billing plans</p>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500">Loading subscriptions...</div>
        ) : subscriptions.length === 0 ? (
          <div className="p-12 text-center text-sm text-gray-400">No active subscription records</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-gray-50 border-b border-gray-200 text-xs font-semibold text-gray-500 uppercase tracking-wider">
                <tr>
                  <th className="px-6 py-3.5">Lawyer</th>
                  <th className="px-6 py-3.5">Subscription Plan</th>
                  <th className="px-6 py-3.5">Status</th>
                  <th className="px-6 py-3.5">End Date</th>
                  <th className="px-6 py-3.5 text-right">Tier Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {subscriptions.map((s: any) => (
                  <tr key={s._id} className="hover:bg-gray-50/80 transition-colors">
                    <td className="px-6 py-4 font-semibold text-gray-900">{s.user?.fullName || "N/A"}</td>
                    <td className="px-6 py-4">
                      <span className="inline-flex items-center gap-1 font-bold text-gray-900">
                        <Crown className="w-3.5 h-3.5 text-gold" /> {s.plan || "Free"}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800">
                        {s.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-xs text-gray-500">{formatDate(s.endDate)}</td>
                    <td className="px-6 py-4 text-right">
                      <select
                        value={s.plan}
                        onChange={(e) => updateSubMutation.mutate({ id: s._id, plan: e.target.value })}
                        className="px-2.5 py-1 bg-gray-50 border border-gray-200 rounded text-xs font-semibold text-gray-800"
                      >
                        <option value="Free">Free</option>
                        <option value="Starter">Starter</option>
                        <option value="Professional">Professional</option>
                        <option value="Premium">Premium</option>
                        <option value="Elite">Elite</option>
                      </select>
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

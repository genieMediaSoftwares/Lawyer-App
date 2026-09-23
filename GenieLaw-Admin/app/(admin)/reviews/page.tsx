"use client";

import React, { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Star, EyeOff, Eye, Flag, ShieldAlert } from "lucide-react";
import { formatDate } from "@/lib/utils";
import { toast } from "sonner";

export default function ReviewsPage() {
  const queryClient = useQueryClient();
  const [isReported, setIsReported] = useState("all");

  const { data, isLoading } = useQuery({
    queryKey: ["admin", "reviews", isReported],
    queryFn: () => adminApi.getReviews({ isReported: isReported === "true" ? "true" : undefined, limit: 50 }),
  });

  const updateVisibilityMutation = useMutation({
    mutationFn: ({ id, isHidden, isReported }: { id: string; isHidden?: boolean; isReported?: boolean }) =>
      adminApi.updateReviewVisibility(id, { isHidden, isReported }),
    onSuccess: () => {
      toast.success("Review visibility updated");
      queryClient.invalidateQueries({ queryKey: ["admin", "reviews"] });
    },
  });

  const reviews = data?.data || [];

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Review Moderation</h1>
        <p className="text-sm text-gray-500">Inspect client reviews, moderate reported feedback, and manage visibility</p>
      </div>

      <div className="bg-white p-4 rounded-xl border border-gray-200 shadow-sm flex items-center justify-between">
        <select
          value={isReported}
          onChange={(e) => setIsReported(e.target.value)}
          className="px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-800 font-medium focus:outline-none"
        >
          <option value="all">All Reviews</option>
          <option value="true">Flagged / Reported Reviews Only</option>
        </select>
      </div>

      <div className="space-y-4">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500">Loading reviews...</div>
        ) : reviews.length === 0 ? (
          <div className="bg-white p-12 rounded-xl border border-gray-200 text-center text-gray-400">
            No reviews found matching filter
          </div>
        ) : (
          reviews.map((r: any) => (
            <div key={r._id} className="bg-white p-5 rounded-xl border border-gray-200 shadow-sm space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-full bg-gold/20 flex items-center justify-center font-bold text-xs">
                    {r.client?.fullName ? r.client.fullName[0].toUpperCase() : "C"}
                  </div>
                  <div>
                    <h3 className="font-bold text-gray-900 text-sm">{r.client?.fullName || "Client"}</h3>
                    <p className="text-xs text-gray-500">Review for Advocate: {r.lawyer?.fullName || "N/A"}</p>
                  </div>
                </div>

                <div className="flex items-center gap-1 text-amber-500 font-bold text-sm">
                  <Star className="w-4 h-4 fill-amber-400" /> {r.rating} / 5
                </div>
              </div>

              <p className="text-sm text-gray-700 bg-gray-50 p-3 rounded-lg border border-gray-100 italic">
                "{r.review}"
              </p>

              <div className="flex items-center justify-between pt-2 border-t border-gray-100 text-xs">
                <span className="text-gray-400">{formatDate(r.createdAt)}</span>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => updateVisibilityMutation.mutate({ id: r._id, isHidden: !r.isHidden })}
                    className={`px-3 py-1 rounded-lg font-semibold flex items-center gap-1 transition-colors ${
                      r.isHidden ? "bg-amber-100 text-amber-800" : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                    }`}
                  >
                    {r.isHidden ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
                    {r.isHidden ? "Unhide Review" : "Hide Review"}
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

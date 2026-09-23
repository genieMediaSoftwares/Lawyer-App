"use client";

import React from "react";
import { useQuery } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Tag } from "lucide-react";

export default function PromotionsPage() {
  const { data: promotions = [], isLoading } = useQuery({
    queryKey: ["admin", "promotions"],
    queryFn: adminApi.getPromotions,
  });

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Platform Promotions & Discounts</h1>
        <p className="text-sm text-gray-500">View promotional discount codes and platform offers</p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        {isLoading ? (
          <div className="p-12 text-center text-sm text-gray-500 col-span-full">Loading promotional offers...</div>
        ) : promotions.length === 0 ? (
          <div className="p-12 text-center text-sm text-gray-400 col-span-full">No active promotions</div>
        ) : (
          promotions.map((p: any) => (
            <div key={p.id} className="bg-white p-5 rounded-xl border border-gray-200 shadow-sm space-y-3">
              <div className="flex items-center justify-between">
                <span className="px-2.5 py-1 bg-gold/15 text-gold-hover border border-gold/30 rounded-lg text-xs font-mono font-bold">
                  {p.code}
                </span>
                <span className="text-xs font-semibold px-2 py-0.5 rounded bg-emerald-50 text-emerald-700">Active</span>
              </div>
              <h3 className="font-bold text-gray-900 text-base">{p.name}</h3>
              <p className="text-xs text-gray-500">Discount Amount: <span className="font-bold text-gray-900">{p.discount}</span></p>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

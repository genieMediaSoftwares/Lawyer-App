"use client";

import React, { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Bell, Send } from "lucide-react";
import { toast } from "sonner";

export default function NotificationsPage() {
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [targetRole, setTargetRole] = useState("all");

  const broadcastMutation = useMutation({
    mutationFn: (data: { title: string; message: string; targetRole?: string }) =>
      adminApi.broadcastNotification(data),
    onSuccess: (res) => {
      toast.success(res.message || "Notification broadcast sent successfully");
      setTitle("");
      setMessage("");
    },
    onError: (err: any) => {
      toast.error(err.message || "Broadcast failed");
    },
  });

  const handleBroadcast = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title || !message) return;
    broadcastMutation.mutate({ title, message, targetRole });
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Admin Notification Center</h1>
        <p className="text-sm text-gray-500">Broadcast platform announcements and push notifications to users in real-time</p>
      </div>

      <div className="max-w-2xl bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-4">
        <h2 className="text-base font-bold text-gray-900 flex items-center gap-2">
          <Send className="w-4 h-4 text-gold" /> Broadcast System Notification
        </h2>

        <form onSubmit={handleBroadcast} className="space-y-4 text-sm">
          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">Target Audience</label>
            <select
              value={targetRole}
              onChange={(e) => setTargetRole(e.target.value)}
              className="w-full px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-800 font-medium focus:outline-none focus:ring-2 focus:ring-gold/50"
            >
              <option value="all">All Users (Clients & Lawyers)</option>
              <option value="client">Clients Only</option>
              <option value="lawyer">Advocates / Lawyers Only</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">Notification Title</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="e.g., Platform Maintenance Update"
              required
              className="w-full px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gold/50"
            />
          </div>

          <div>
            <label className="block text-xs font-semibold text-gray-700 mb-1">Message Content</label>
            <textarea
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              placeholder="Type your message broadcast here..."
              rows={4}
              required
              className="w-full px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gold/50"
            />
          </div>

          <button
            type="submit"
            disabled={broadcastMutation.isPending}
            className="w-full py-3 bg-gold hover:bg-gold-hover text-black font-extrabold rounded-lg shadow-sm transition-all duration-150 flex items-center justify-center gap-2 text-sm disabled:opacity-50"
          >
            <Send className="w-4 h-4" />
            <span>{broadcastMutation.isPending ? "Sending Broadcast..." : "Send Real-Time Notification"}</span>
          </button>
        </form>
      </div>
    </div>
  );
}

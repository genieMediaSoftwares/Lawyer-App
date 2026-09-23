"use client";

import React, { useState, useEffect } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { adminApi } from "@/lib/api/adminApi";
import { Settings, Save, ShieldCheck } from "lucide-react";
import { toast } from "sonner";

export default function SettingsPage() {
  const queryClient = useQueryClient();
  const [pushNotifications, setPushNotifications] = useState(true);
  const [emailNotifications, setEmailNotifications] = useState(true);
  const [language, setLanguage] = useState("English");
  const [twoFactorAuthentication, setTwoFactorAuthentication] = useState(false);

  const { data: settingsData, isLoading } = useQuery({
    queryKey: ["admin", "settings"],
    queryFn: adminApi.getSettings,
  });

  useEffect(() => {
    if (settingsData) {
      setPushNotifications(settingsData.pushNotifications !== false);
      setEmailNotifications(settingsData.emailNotifications !== false);
      setLanguage(settingsData.language || "English");
      setTwoFactorAuthentication(Boolean(settingsData.twoFactorAuthentication));
    }
  }, [settingsData]);

  const updateSettingsMutation = useMutation({
    mutationFn: (data: any) => adminApi.updateSettings(data),
    onSuccess: () => {
      toast.success("Admin preferences saved successfully");
      queryClient.invalidateQueries({ queryKey: ["admin", "settings"] });
    },
    onError: (err: any) => {
      toast.error(err.message || "Failed to update settings");
    },
  });

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    updateSettingsMutation.mutate({
      pushNotifications,
      emailNotifications,
      language,
      twoFactorAuthentication,
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Admin & Platform Settings</h1>
        <p className="text-sm text-gray-500">System configuration, security options, and admin notification preferences</p>
      </div>

      <div className="max-w-2xl bg-white p-6 rounded-xl border border-gray-200 shadow-sm space-y-6">
        <h2 className="text-base font-bold text-gray-900 flex items-center gap-2 border-b border-gray-100 pb-3">
          <Settings className="w-4 h-4 text-gold" /> System Preferences
        </h2>

        {isLoading ? (
          <div className="p-8 text-center text-sm text-gray-500">Loading settings...</div>
        ) : (
          <form onSubmit={handleSave} className="space-y-5 text-sm">
            <div className="flex items-center justify-between py-2 border-b border-gray-100">
              <div>
                <p className="font-semibold text-gray-900">Push Notifications</p>
                <p className="text-xs text-gray-500">Receive instant alerts for new verification requests</p>
              </div>
              <input
                type="checkbox"
                checked={pushNotifications}
                onChange={(e) => setPushNotifications(e.target.checked)}
                className="w-4 h-4 accent-gold rounded cursor-pointer"
              />
            </div>

            <div className="flex items-center justify-between py-2 border-b border-gray-100">
              <div>
                <p className="font-semibold text-gray-900">Email Notifications</p>
                <p className="text-xs text-gray-500">Receive email alerts for system error reports and audit events</p>
              </div>
              <input
                type="checkbox"
                checked={emailNotifications}
                onChange={(e) => setEmailNotifications(e.target.checked)}
                className="w-4 h-4 accent-gold rounded cursor-pointer"
              />
            </div>

            <div className="flex items-center justify-between py-2 border-b border-gray-100">
              <div>
                <p className="font-semibold text-gray-900">Two-Factor Authentication (2FA)</p>
                <p className="text-xs text-gray-500">Enforce extra security verification on admin sign-in</p>
              </div>
              <input
                type="checkbox"
                checked={twoFactorAuthentication}
                onChange={(e) => setTwoFactorAuthentication(e.target.checked)}
                className="w-4 h-4 accent-gold rounded cursor-pointer"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-gray-700 mb-1">System Language</label>
              <select
                value={language}
                onChange={(e) => setLanguage(e.target.value)}
                className="w-full px-3 py-2 bg-gray-50 border border-gray-200 rounded-lg text-sm text-gray-900 font-medium focus:outline-none"
              >
                <option value="English">English</option>
                <option value="Hindi">Hindi</option>
              </select>
            </div>

            <button
              type="submit"
              disabled={updateSettingsMutation.isPending}
              className="w-full py-3 bg-gold hover:bg-gold-hover text-black font-extrabold rounded-lg shadow-sm transition-all duration-150 flex items-center justify-center gap-2 text-sm disabled:opacity-50"
            >
              <Save className="w-4 h-4" />
              <span>{updateSettingsMutation.isPending ? "Saving..." : "Save Preferences"}</span>
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

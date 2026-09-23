import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { io, Socket } from "socket.io-client";
import { toast } from "sonner";

let socket: Socket | null = null;

export function useSocket() {
  const queryClient = useQueryClient();

  useEffect(() => {
    const adminToken =
      typeof window !== "undefined"
        ? document.cookie
            .split("; ")
            .find((c) => c.startsWith("admin_token="))
            ?.split("=")[1] ||
          localStorage.getItem("admin_token")
        : null;

    if (!socket) {
      const socketUrl = process.env.NEXT_PUBLIC_SOCKET_URL || "https://lawyerappvizag.duckdns.org";

      socket = io(socketUrl, {
        transports: ["websocket", "polling"],
        reconnection: true,
        reconnectionAttempts: 5,
        auth: adminToken ? { token: adminToken } : undefined,
      });
    }

    const onConnect = () => {
      console.log("⚡ Admin Socket connected:", socket?.id);
    };

    const onError = (err: any) => {
      console.warn("Socket error:", err?.message || err);
    };

    const invalidate = (keys: string[][]) =>
      keys.forEach((k) => queryClient.invalidateQueries({ queryKey: k }));

    const handlers: Record<string, () => void> = {
      lawyer_verification_updated: () => {
        toast.info("A lawyer verification status was updated");
        invalidate([["admin", "lawyers"], ["admin", "stats"]]);
      },
      admin_broadcast: () => {
        toast.success("A new broadcast notification was sent");
        invalidate([["admin", "notifications"]]);
      },
      new_case_submitted: () => {
        toast.info("A new case was submitted");
        invalidate([["admin", "cases"], ["admin", "stats"]]);
      },
      case_status_changed: () => {
        invalidate([["admin", "cases"], ["admin", "stats"]]);
      },
      new_lawyer_registered: () => {
        toast.info("A new advocate registered on the platform");
        invalidate([["admin", "lawyers"], ["admin", "stats"]]);
      },
      new_client_registered: () => {
        toast.info("A new client registered on the platform");
        invalidate([["admin", "clients"], ["admin", "stats"]]);
      },
      new_appointment: () => {
        invalidate([["admin", "appointments"], ["admin", "stats"]]);
      },
      payment_completed: () => {
        toast.success("A new payment was completed");
        invalidate([["admin", "payments"], ["admin", "stats"]]);
      },
      refund_processed: () => {
        toast.info("A refund was processed");
        invalidate([["admin", "payments"], ["admin", "stats"]]);
      },
      new_review: () => {
        invalidate([["admin", "reviews"]]);
      },
      new_dispute: () => {
        toast.warning("A new dispute was filed");
        invalidate([["admin", "disputes"], ["admin", "stats"]]);
      },
      urgent_case_created: () => {
        toast.warning("An urgent case was flagged on the platform");
        invalidate([["admin", "urgent-cases"], ["admin", "cases"], ["admin", "stats"]]);
      },
    };

    socket.on("connect", onConnect);
    socket.on("connect_error", onError);

    Object.entries(handlers).forEach(([event, handler]) => {
      socket?.on(event, handler);
    });

    return () => {
      socket?.off("connect", onConnect);
      socket?.off("connect_error", onError);
      Object.entries(handlers).forEach(([event, handler]) => {
        socket?.off(event, handler);
      });
    };
  }, [queryClient]);
}

import { useEffect } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { io, Socket } from "socket.io-client";
import { toast } from "sonner";

let socket: Socket | null = null;

export function useSocket() {
  const queryClient = useQueryClient();

  useEffect(() => {
    const socketUrl = process.env.NEXT_PUBLIC_SOCKET_URL || "http://localhost:5000";

    if (!socket) {
      socket = io(socketUrl, {
        transports: ["websocket", "polling"],
        reconnection: true,
        reconnectionAttempts: 5,
      });
    }

    socket.on("connect", () => {
      console.log("⚡ Admin Socket connected:", socket?.id);
    });

    socket.on("lawyer_verification_updated", (data) => {
      toast.info(`Lawyer verification updated (${data.status})`);
      queryClient.invalidateQueries({ queryKey: ["admin", "lawyers"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "stats"] });
    });

    socket.on("admin_broadcast", (data) => {
      toast.success(`Broadcast Sent: ${data.title}`);
      queryClient.invalidateQueries({ queryKey: ["admin", "notifications"] });
    });

    socket.on("new_case_submitted", () => {
      toast.info("New case submitted");
      queryClient.invalidateQueries({ queryKey: ["admin", "cases"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "stats"] });
    });

    socket.on("case_status_changed", () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "cases"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "stats"] });
    });

    return () => {
      // Keep socket active or clean listeners
      socket?.off("lawyer_verification_updated");
      socket?.off("admin_broadcast");
      socket?.off("new_case_submitted");
      socket?.off("case_status_changed");
    };
  }, [queryClient]);
}

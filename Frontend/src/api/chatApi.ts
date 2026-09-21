import { apiClient, unwrap } from './apiClient';
import type { ApiSuccess } from '../types/api';
import type { ChatConversation, ChatMessage, MessageAttachment } from '../types/domain';

export const chatApi = {
  /** GET /chats → list of user conversations */
  async getChats(): Promise<ChatConversation[]> {
    const response = await apiClient.get<ApiSuccess<ChatConversation[]>>('/chats');
    return unwrap(response);
  },

  /** POST /chats → get or create chat with another user */
  async getOrCreateChat(otherUserId: string): Promise<ChatConversation> {
    const response = await apiClient.post<ApiSuccess<ChatConversation>>('/chats', {
      otherUserId,
    });
    return unwrap(response);
  },

  /** GET /chats/:chatId/messages → messages in a conversation */
  async getMessages(chatId: string): Promise<ChatMessage[]> {
    const response = await apiClient.get<ApiSuccess<ChatMessage[]>>(
      `/chats/${encodeURIComponent(chatId)}/messages`,
    );
    return unwrap(response);
  },

  /** POST /chats/:chatId/messages → send message */
  async sendMessage(
    chatId: string,
    content: string,
    attachments?: MessageAttachment[],
  ): Promise<ChatMessage> {
    const response = await apiClient.post<ApiSuccess<ChatMessage>>(
      `/chats/${encodeURIComponent(chatId)}/messages`,
      { content, attachments },
    );
    return unwrap(response);
  },

  /** PUT /chats/:chatId/read → mark conversation messages as read */
  async markAsRead(chatId: string): Promise<void> {
    await apiClient.put<ApiSuccess<null>>(
      `/chats/${encodeURIComponent(chatId)}/read`,
    );
  },
};

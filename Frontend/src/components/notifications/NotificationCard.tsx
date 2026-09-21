import React, { useState } from 'react';
import { Pressable, View } from 'react-native';
import { GenieAvatar } from '../ui/GenieAvatar';
import { GenieText } from '../ui/GenieText';
import {
  BellIcon,
  BriefcaseIcon,
  ChatIcon,
  ChevronRightIcon,
  CloseIcon,
  FileIcon,
  TrashIcon,
} from '../icons/ClientIcons';
import {
  CalendarIcon,
  ChartIcon,
  UserPlusIcon,
} from '../icons/LawyerIcons';
import { CheckIcon, MailIcon } from '../icons/Icons';
import { formatRelative } from '../../utils/format';
import type { AppNotification } from '../../types/domain';
import { colors } from '../../theme';

interface NotificationCardProps {
  item: AppNotification;
  isSelectMode?: boolean;
  isSelected?: boolean;
  onToggleSelect?: () => void;
  onPress: () => void;
  onMarkRead: () => void;
  onDelete: () => void;
}

const getTypeIcon = (type: string) => {
  switch (type) {
    case 'case_posted':
    case 'proposal_received':
    case 'proposal_accepted':
    case 'proposal_rejected':
      return BriefcaseIcon;
    case 'chat_message':
      return ChatIcon;
    case 'document_uploaded':
      return FileIcon;
    case 'appointment_requested':
    case 'appointment_confirmed':
    case 'appointment_cancelled':
    case 'reminder':
      return CalendarIcon;
    case 'case_status_updated':
      return ChartIcon;
    case 'profile_verification':
    case 'review_received':
      return UserPlusIcon;
    default:
      return BellIcon;
  }
};

export const NotificationCard: React.FC<NotificationCardProps> = ({
  item,
  isSelectMode = false,
  isSelected = false,
  onToggleSelect,
  onPress,
  onMarkRead,
  onDelete,
}) => {
  const [showActions, setShowActions] = useState(false);
  const [isDismissing, setIsDismissing] = useState(false);
  const IconComp = getTypeIcon(item.type);
  const hasSenderAvatar = Boolean(item.senderId?.profileImage || item.senderId?.fullName);

  const handlePushAway = () => {
    setIsDismissing(true);
    setTimeout(() => {
      onDelete();
    }, 200);
  };

  if (isDismissing) {
    return null;
  }

  return (
    <View className="mb-3 w-full max-w-3xl mx-auto">
      <View className="flex-row items-center gap-2">
        {isSelectMode ? (
          <Pressable
            onPress={onToggleSelect}
            className="p-1 active:opacity-70"
          >
            <View
              className={`h-6 w-6 items-center justify-center rounded-full border ${
                isSelected
                  ? 'border-gold bg-gold'
                  : 'border-border/60 bg-surface-alt'
              }`}
            >
              {isSelected ? (
                <CheckIcon size={14} color={colors.onGold} />
              ) : null}
            </View>
          </Pressable>
        ) : null}

        <Pressable
          onPress={() => {
            if (isSelectMode) {
              onToggleSelect?.();
            } else {
              onPress();
            }
          }}
          onLongPress={() => {
            if (!isSelectMode) {
              setShowActions(!showActions);
            }
          }}
          className={`flex-1 rounded-2xl p-4 transition-all ${
            isSelected
              ? 'border-2 border-gold bg-amber-950/20'
              : item.isRead
              ? 'border border-border/30 bg-surface-alt'
              : 'border border-gold/40 bg-surface-alt shadow-sm'
          }`}
        >
          <View className="flex-row items-start gap-3">
            {hasSenderAvatar ? (
              <View className="relative">
                <GenieAvatar
                  uri={item.senderId?.profileImage}
                  name={item.senderId?.fullName || item.title}
                  size="md"
                />
                <View className="absolute -bottom-1 -right-1 items-center justify-center rounded-full bg-surface p-1 border border-border">
                  <IconComp size={10} color={colors.gold} />
                </View>
              </View>
            ) : (
              <View className="h-11 w-11 items-center justify-center rounded-full border border-amber-600/40 bg-amber-950/40">
                <IconComp size={20} color={colors.gold} />
              </View>
            )}

            <View className="flex-1 pr-1">
              <GenieText
                className="font-bold text-base text-text-primary"
                numberOfLines={1}
              >
                {item.title}
              </GenieText>

              <GenieText
                className="mt-0.5 text-xs text-text-secondary leading-4"
                numberOfLines={2}
              >
                {item.message}
              </GenieText>

              <GenieText className="mt-1.5 text-xs text-text-muted">
                {formatRelative(item.createdAt)}
              </GenieText>
            </View>

            <View className="flex-row items-center gap-2 pt-0.5">
              {!item.isRead ? (
                <View className="h-2.5 w-2.5 rounded-full bg-gold" />
              ) : null}

              {!isSelectMode ? (
                <Pressable
                  onPress={handlePushAway}
                  hitSlop={8}
                  className="rounded-full bg-surface-alt p-1.5 active:bg-border/40"
                  accessibilityLabel="Push alert away"
                >
                  <CloseIcon size={14} color={colors.textMuted} />
                </Pressable>
              ) : null}

              <ChevronRightIcon size={16} color={colors.textMuted} />
            </View>
          </View>
        </Pressable>
      </View>

      {showActions && !isSelectMode ? (
        <View className="mt-2 flex-row gap-2">
          {!item.isRead ? (
            <Pressable
              onPress={() => {
                setShowActions(false);
                onMarkRead();
              }}
              className="flex-1 flex-row items-center justify-center gap-2 rounded-xl border border-border/50 bg-surface-alt py-2.5"
            >
              <MailIcon size={16} color={colors.gold} />
              <GenieText className="font-semibold text-xs text-text-primary">
                Mark Read
              </GenieText>
            </Pressable>
          ) : null}

          <Pressable
            onPress={() => {
              setShowActions(false);
              onDelete();
            }}
            className="flex-1 flex-row items-center justify-center gap-2 rounded-xl bg-red-600/90 py-2.5 active:bg-red-700"
          >
            <TrashIcon size={16} color={colors.white} />
            <GenieText className="font-bold text-xs text-white">
              Delete
            </GenieText>
          </Pressable>
        </View>
      ) : null}
    </View>
  );
};

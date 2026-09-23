import React, { useEffect, useState } from 'react';
import { TextInput, View } from 'react-native';

import {
  GenieBottomSheet,
  GenieButton,
  GenieNotice,
  GenieStarRating,
  GenieText,
} from '../ui';
import { colors } from '../../theme';

const MAX_REVIEW = 1000;

export interface WriteReviewSheetProps {
  visible: boolean;
  lawyerName: string;
  isSubmitting: boolean;
  error?: string | null;
  onClose: () => void;
  onSubmit: (input: { rating: number; review: string }) => void;
}

export const WriteReviewSheet: React.FC<WriteReviewSheetProps> = ({
  visible,
  lawyerName,
  isSubmitting,
  error,
  onClose,
  onSubmit,
}) => {
  const [rating, setRating] = useState(0);
  const [review, setReview] = useState('');

  useEffect(() => {
    if (visible) {
      setRating(0);
      setReview('');
    }
  }, [visible]);

  const canSubmit = rating > 0 && review.trim().length > 0 && !isSubmitting;

  return (
    <GenieBottomSheet
      visible={visible}
      onClose={onClose}
      title={`Review ${lawyerName}`}
      footer={
        <GenieButton
          label="Submit review"
          loadingLabel="Submitting..."
          loading={isSubmitting}
          disabled={!canSubmit}
          onPress={() => onSubmit({ rating, review: review.trim() })}
        />
      }
    >
      <View className="pb-2">
        <GenieText variant="body-sm" tone="secondary">
          Your name and rating are shown publicly on this advocate's profile.
        </GenieText>

        <GenieText variant="label" className="mb-2 mt-4">
          Your rating
        </GenieText>
        <GenieStarRating value={rating} onChange={setRating} size={28} />

        <GenieText variant="label" className="mb-2 mt-4">
          Your review
        </GenieText>
        <TextInput
          value={review}
          onChangeText={text => setReview(text.slice(0, MAX_REVIEW))}
          placeholder="What was your experience with this advocate?"
          placeholderTextColor={colors.textMuted}
          multiline
          textAlignVertical="top"
          accessibilityLabel="Your review"
          className="min-h-[120px] rounded-control border border-border bg-card px-4 py-3 text-body-md text-white"
        />
        <GenieText variant="caption" tone="muted" className="mt-1 self-end">
          {`${review.length}/${MAX_REVIEW}`}
        </GenieText>

        {error ? <GenieNotice tone="error" message={error} className="mt-3" /> : null}
      </View>
    </GenieBottomSheet>
  );
};

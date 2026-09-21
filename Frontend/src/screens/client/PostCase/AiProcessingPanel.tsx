import React, { useEffect, useRef } from 'react';
import { ActivityIndicator, Animated, Easing, View } from 'react-native';

import { GenieText } from '../../../components';
import { SparkleIcon } from '../../../components/icons/ClientIcons';
import { CheckIcon } from '../../../components/icons/Icons';
import { colors } from '../../../theme';
import { USE_NATIVE_DRIVER } from '../../../utils/platform';

/**
 * What the client watches while the assistant works.
 *
 * Every number here comes from the server. `percent` is the pipeline's own
 * stage-weighted figure and `message` its own line ("Reading document 2 of
 * 5"); nothing is derived from a timer, so the bar cannot claim progress that
 * has not happened. During the upload itself the fraction is the real transfer
 * progress from axios.
 *
 * The only animation is cosmetic: a pulsing mark and an eased tween between
 * two real percentages, so the bar slides rather than jumps.
 */

/**
 * The checklist shown beneath the bar, and which server stages each row covers.
 *
 * The ids on the right are `PIPELINE_STAGES` from
 * `services/ai/aiSmartCasePipeline.js`. A row reads as done only once the
 * server has actually moved past it — nothing here ticks on a timer, and the
 * last row does not tick at all until the analysis really is finished.
 */
const STAGE_ROWS: { label: string; stages: string[] }[] = [
  { label: 'Uploading documents', stages: ['uploading'] },
  { label: 'Reading documents', stages: ['queued', 'ocr', 'transcribing'] },
  { label: 'Extracting case information', stages: ['extracting'] },
  { label: 'Preparing case details', stages: ['classifying'] },
  { label: 'Finding suitable lawyers', stages: ['completed'] },
];

const rowIndexForStage = (stage: string): number => {
  const index = STAGE_ROWS.findIndex(row => row.stages.includes(stage));
  // An unknown stage means the server added one this build does not know
  // about. Treating it as "reading" keeps the list sane, and the server's own
  // message above it is still shown verbatim.
  return index === -1 ? 1 : index;
};

interface AiProcessingPanelProps {
  percent: number;
  message: string;
  current?: number | null;
  total?: number | null;
  /** The server's own stage id, or "uploading" while the transfer runs. */
  stage?: string;
  /** Upload phase rather than analysis — changes only the closing line. */
  uploading?: boolean;
}

export const AiProcessingPanel: React.FC<AiProcessingPanelProps> = ({
  percent,
  message,
  current,
  total,
  stage = 'queued',
  uploading = false,
}) => {
  const pulse = useRef(new Animated.Value(0)).current;
  const width = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {
          toValue: 1,
          duration: 900,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: USE_NATIVE_DRIVER,
        }),
        Animated.timing(pulse, {
          toValue: 0,
          duration: 900,
          easing: Easing.inOut(Easing.quad),
          useNativeDriver: USE_NATIVE_DRIVER,
        }),
      ]),
    );
    animation.start();
    return () => animation.stop();
  }, [pulse]);

  useEffect(() => {
    Animated.timing(width, {
      toValue: Math.max(0, Math.min(100, percent)),
      duration: 400,
      easing: Easing.out(Easing.quad),
      // A width cannot be driven natively, so this one runs on the JS thread.
      useNativeDriver: false,
    }).start();
  }, [percent, width]);

  const scale = pulse.interpolate({
    inputRange: [0, 1],
    outputRange: [1, 1.08],
  });

  return (
    <View className="flex-1 items-center justify-center px-6">
      <Animated.View
        style={{ transform: [{ scale }] }}
        className="h-20 w-20 items-center justify-center rounded-full bg-gold-muted"
      >
        <SparkleIcon size={34} color={colors.gold} />
      </Animated.View>

      <GenieText variant="heading-sm" className="mt-5 text-center">
        {message}
      </GenieText>

      {typeof current === 'number' && typeof total === 'number' && total > 0 ? (
        <GenieText variant="body-sm" tone="secondary" className="mt-1">
          {current} of {total}
        </GenieText>
      ) : null}

      <View className="mt-5 h-1.5 w-full overflow-hidden rounded-pill bg-surface-alt">
        <Animated.View
          className="h-full rounded-pill bg-gold"
          style={{
            width: width.interpolate({
              inputRange: [0, 100],
              outputRange: ['0%', '100%'],
            }),
          }}
        />
      </View>

      <GenieText variant="body-sm" tone="gold" className="mt-2 font-bold">
        {`${Math.round(percent)}%`}
      </GenieText>

      {/* The checklist. Each row's state comes from the server's stage id, so
          a tick means that part of the pipeline genuinely finished. */}
      <View className="mt-6 w-full">
        {STAGE_ROWS.map((row, index) => {
          const activeIndex = rowIndexForStage(uploading ? 'uploading' : stage);
          const isDone = index < activeIndex;
          const isActive = index === activeIndex;

          return (
            <View key={row.label} className="flex-row items-center gap-3 py-1.5">
              <View
                className={`h-5 w-5 items-center justify-center rounded-full border ${
                  isDone
                    ? 'border-success bg-success'
                    : isActive
                    ? 'border-gold bg-gold-muted'
                    : 'border-border'
                }`}
              >
                {isDone ? (
                  <CheckIcon size={12} color={colors.background} />
                ) : isActive ? (
                  <ActivityIndicator size="small" color={colors.gold} />
                ) : null}
              </View>

              <GenieText
                variant="body-sm"
                tone={isDone ? 'secondary' : isActive ? 'gold' : 'muted'}
                className={isActive ? 'font-semibold' : ''}
              >
                {row.label}
              </GenieText>
            </View>
          );
        })}
      </View>

      <GenieText variant="caption" tone="muted" className="mt-5 text-center">
        {uploading
          ? 'Keep this screen open until the upload finishes.'
          : 'Reading documents takes the longest. Your case details will be filled in automatically.'}
      </GenieText>
    </View>
  );
};

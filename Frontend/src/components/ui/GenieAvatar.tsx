import React, { useEffect, useState } from 'react';
import { Image, View } from 'react-native';
import { GenieText } from './GenieText';
import { getUploadUrl, resolveFileUrl } from '../../utils/urls';

export type GenieAvatarSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

const SIZES: Record<GenieAvatarSize, { box: string; text: string }> = {
  xs: { box: 'h-8 w-8', text: 'text-caption' },
  sm: { box: 'h-11 w-11', text: 'text-body-sm' },
  md: { box: 'h-12 w-12', text: 'text-body-lg' },
  lg: { box: 'h-16 w-16', text: 'text-head-md' },
  xl: { box: 'h-24 w-24', text: 'text-head-xl' },
};

function initialsOf(name?: string | null): string {
  if (!name) {
    return 'GL';
  }
  return name
    .split(' ')
    .filter(Boolean)
    .map(part => part[0])
    .join('')
    .slice(0, 2)
    .toUpperCase();
}

export interface GenieAvatarProps {
  uri?: string | null;
  name?: string | null;
  size?: GenieAvatarSize;
  ring?: boolean;
  className?: string;
}

export const GenieAvatar: React.FC<GenieAvatarProps> = ({
  uri,
  name,
  size = 'sm',
  ring = false,
  className = '',
}) => {
  const { box, text } = SIZES[size];
  const [imageError, setImageError] = useState(false);

  const resolved = getUploadUrl(uri) ?? resolveFileUrl(uri);

  useEffect(() => {
    setImageError(false);
  }, [uri]);

  return (
    <View
      className={[
        box,
        'items-center justify-center overflow-hidden rounded-full bg-surface',
        ring ? 'border-2 border-gold' : '',
        className,
      ].join(' ')}
    >
      {resolved && !imageError ? (
        <Image
          source={{ uri: resolved }}
          className={`${box} rounded-full`}
          resizeMode="cover"
          accessibilityLabel={name ? `${name}'s photo` : 'Profile photo'}
          onError={e => {
            setImageError(true);
            if (__DEV__) {
              console.warn(
                `[GenieAvatar] Image failed to load from resolved URL: "${resolved}" (raw input: "${uri}"). Error:`,
                e.nativeEvent?.error,
              );
            }
          }}
        />
      ) : (
        <GenieText tone="gold" className={`${text} font-bold`}>
          {initialsOf(name)}
        </GenieText>
      )}
    </View>
  );
};

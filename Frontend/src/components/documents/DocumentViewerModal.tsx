import React, { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { GenieButton, GenieHeader, GenieText } from '../ui';
import { DownloadIcon, EyeIcon, FileIcon, ImageIcon, ShieldIcon } from '../icons/ClientIcons';
import { formatDocumentMeta, getDocumentBadgeInfo } from './documentUtils';
import { documentsApi } from '../../api/documentsApi';
import type { DocxPreviewResult } from '../../api/documentsApi';
import type { AppDocument } from '../../types/domain';
import { colors } from '../../theme';

export interface DocumentViewerModalProps {
  visible: boolean;
  document: AppDocument | null;
  onClose: () => void;
  onDownload: (document: AppDocument) => void;
}

export const DocumentViewerModal: React.FC<DocumentViewerModalProps> = ({
  visible,
  document,
  onClose,
  onDownload,
}) => {
  const [previewData, setPreviewData] = useState<DocxPreviewResult | null>(null);
  const [blobUrl, setBlobUrl] = useState<string | null>(null);
  const [textContent, setTextContent] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [errorText, setErrorText] = useState<string | null>(null);

  useEffect(() => {
    let currentBlobUrl: string | null = null;

    if (!visible || !document) {
      setPreviewData(null);
      setBlobUrl(null);
      setTextContent(null);
      setIsLoading(false);
      setErrorText(null);
      return;
    }

    const badge = getDocumentBadgeInfo(document);
    setIsLoading(true);
    setErrorText(null);
    setPreviewData(null);
    setBlobUrl(null);
    setTextContent(null);

    if (badge.category === 'docx') {
      Promise.allSettled([
        documentsApi.getPreview(document._id),
        documentsApi.fetchViewBlob(document._id),
      ])
        .then(([previewRes, blobRes]) => {
          if (previewRes.status === 'fulfilled') {
            setPreviewData(previewRes.value);
          }
          if (blobRes.status === 'fulfilled') {
            const globalWin = (globalThis as any).window;
            if (globalWin && globalWin.URL && globalWin.URL.createObjectURL) {
              const url = globalWin.URL.createObjectURL(blobRes.value);
              currentBlobUrl = url;
              setBlobUrl(url);
            }
          } else if (previewRes.status === 'rejected') {
            const err = previewRes.reason;
            const status = err?.response?.status;
            if (status === 403 || status === 401) {
              setErrorText("You don't have permission to access this document.");
            }
          }
        })
        .finally(() => {
          setIsLoading(false);
        });
      return;
    }

    documentsApi
      .fetchViewBlob(document._id)
      .then(async blob => {
        if (badge.category === 'text') {
          try {
            const text = typeof (blob as any).text === 'function'
              ? await (blob as any).text()
              : await new Response(blob).text();
            setTextContent(text);
          } catch {
            setTextContent('Unable to parse text content.');
          }
        }

        const globalWin = (globalThis as any).window;
        if (globalWin && globalWin.URL && globalWin.URL.createObjectURL) {
          const url = globalWin.URL.createObjectURL(blob);
          currentBlobUrl = url;
          setBlobUrl(url);
        }
      })
      .catch(err => {
        console.warn('Document view error:', err);
        const status = err?.response?.status;
        if (status === 403 || status === 401) {
          setErrorText("You don't have permission to access this document.");
        } else if (status === 404) {
          setErrorText('Document file is no longer available.');
        } else {
          setErrorText(err.message || 'Failed to retrieve document file.');
        }
      })
      .finally(() => {
        setIsLoading(false);
      });

    return () => {
      const globalWin = (globalThis as any).window;
      if (currentBlobUrl && globalWin && globalWin.URL && globalWin.URL.revokeObjectURL) {
        globalWin.URL.revokeObjectURL(currentBlobUrl);
      }
    };
  }, [visible, document]);

  if (!document) {
    return null;
  }

  const badge = getDocumentBadgeInfo(document);
  const displayName = document.name || document.originalName || 'Untitled Document';
  const metaText = formatDocumentMeta(document);

  const renderContent = () => {
    if (isLoading) {
      return (
        <View className="flex-1 items-center justify-center p-6 gap-3">
          <ActivityIndicator size="large" color={colors.gold} />
          <GenieText variant="body-md" tone="secondary">
            Retrieving document securely...
          </GenieText>
        </View>
      );
    }

    if (errorText) {
      return (
        <View className="flex-1 items-center justify-center p-6 text-center gap-3 bg-[#151515]">
          <View className="h-16 w-16 items-center justify-center rounded-full bg-error-surface mb-2">
            <ShieldIcon size={32} color={colors.error} />
          </View>
          <GenieText variant="heading-sm" className="font-bold text-center">
            Access Restricted
          </GenieText>
          <GenieText variant="body-sm" tone="secondary" className="text-center max-w-[280px]">
            {errorText}
          </GenieText>
        </View>
      );
    }

    if (badge.category === 'image' && blobUrl) {
      return (
        <View className="flex-1 items-center justify-center p-4 bg-black">
          <Image
            source={{ uri: blobUrl }}
            className="h-full w-full rounded-card"
            resizeMode="contain"
          />
        </View>
      );
    }

    if (badge.category === 'docx') {
      if (previewData?.blocks && previewData.blocks.length > 0) {
        const renderRunsOrText = (block: any) => {
          if (block.runs && Array.isArray(block.runs) && block.runs.length > 0) {
            return block.runs.map((run: any, rIdx: number) => {
              const styles = [
                run.bold ? 'font-bold' : '',
                run.italic ? 'italic' : '',
                run.underline ? 'underline' : '',
              ]
                .filter(Boolean)
                .join(' ');

              return (
                <GenieText key={rIdx} variant="body-sm" className={`text-gray-900 ${styles}`}>
                  {run.text}
                </GenieText>
              );
            });
          }
          return block.text || '';
        };

        return (
          <ScrollView
            className="flex-1 bg-white p-6"
            contentContainerClassName="pb-10"
            showsVerticalScrollIndicator={false}
          >
            {previewData.blocks.map((block, idx) => {
              if (block.type === 'spacer') {
                return <View key={idx} className="h-3" />;
              }

              if (block.type === 'heading' || block.heading) {
                const headClass =
                  block.level === 1
                    ? 'text-xl font-bold text-black mb-3 mt-4'
                    : block.level === 2
                    ? 'text-lg font-bold text-black mb-2 mt-3'
                    : 'text-base font-bold text-black mb-2 mt-2';

                return (
                  <GenieText key={idx} variant="heading-sm" className={headClass}>
                    {renderRunsOrText(block)}
                  </GenieText>
                );
              }

              if (block.type === 'listItem') {
                return (
                  <View key={idx} className="mb-2 flex-row items-start ml-2">
                    <GenieText variant="body-sm" className="mr-2 text-gray-900 font-bold">
                      •
                    </GenieText>
                    <GenieText variant="body-sm" className="flex-1 text-gray-900 leading-relaxed">
                      {renderRunsOrText(block)}
                    </GenieText>
                  </View>
                );
              }

              if (block.type === 'table' && block.rows) {
                return (
                  <View key={idx} className="my-4 overflow-hidden rounded border border-gray-300 bg-gray-50">
                    {block.rows.map((row, rowIdx) => (
                      <View
                        key={rowIdx}
                        className={`flex-row border-b border-gray-200 ${
                          rowIdx === 0 ? 'bg-gray-200' : ''
                        }`}
                      >
                        {row.map((cell, cellIdx) => (
                          <View
                            key={cellIdx}
                            className="flex-1 justify-center border-r border-gray-200 p-2"
                          >
                            <GenieText
                              variant="caption"
                              className={`text-gray-900 ${
                                rowIdx === 0 ? 'font-bold' : 'font-normal'
                              }`}
                            >
                              {cell}
                            </GenieText>
                          </View>
                        ))}
                      </View>
                    ))}
                  </View>
                );
              }

              return (
                <GenieText key={idx} variant="body-sm" className="mb-2 text-gray-900 leading-relaxed">
                  {renderRunsOrText(block)}
                </GenieText>
              );
            })}
          </ScrollView>
        );
      }

      return (
        <View className="flex-1 items-center justify-center p-6 bg-[#151515] text-center gap-4">
          <View className="h-16 w-16 items-center justify-center rounded-full bg-gold/15 border border-gold/30">
            <FileIcon size={32} color={colors.gold} />
          </View>
          <GenieText variant="heading-sm" className="font-bold text-center text-white">
            Preview Unavailable
          </GenieText>
          <GenieText variant="body-sm" tone="secondary" className="text-center max-w-[280px]">
            Open this document with a compatible document viewer.
          </GenieText>
          <View className="w-full gap-3 mt-2 px-4">
            {blobUrl ? (
              <Pressable
                onPress={() => {
                  const globalWin = (globalThis as any).window;
                  if (globalWin && globalWin.open) {
                    globalWin.open(blobUrl, '_blank');
                  }
                }}
                className="h-12 flex-row items-center justify-center gap-2 rounded-control bg-gold px-4 active:bg-gold-bright"
              >
                <EyeIcon size={18} color={colors.onGold} />
                <GenieText variant="button" tone="on-gold">
                  Open Document
                </GenieText>
              </Pressable>
            ) : null}
            <Pressable
              onPress={() => onDownload(document)}
              className="h-12 flex-row items-center justify-center gap-2 rounded-control bg-surface-alt border border-border px-4 active:bg-surface-highlight"
            >
              <DownloadIcon size={18} color={colors.white} />
              <GenieText variant="button" tone="primary">
                Download
              </GenieText>
            </Pressable>
          </View>
        </View>
      );
    }

    if (badge.category === 'text' && textContent !== null) {
      return (
        <ScrollView
          className="flex-1 bg-[#111111] p-5"
          contentContainerClassName="pb-10"
          showsVerticalScrollIndicator={false}
        >
          <GenieText variant="caption" tone="gold" className="mb-3 font-mono font-bold uppercase tracking-widest">
            TEXT FILE CONTENT
          </GenieText>
          <GenieText variant="body-sm" className="font-mono text-gray-200 leading-relaxed">
            {textContent}
          </GenieText>
        </ScrollView>
      );
    }

    if (badge.category === 'pdf' && blobUrl && Platform.OS === 'web') {
      return (
        <View className="flex-1 bg-white">
          <iframe
            src={blobUrl}
            title={displayName}
            style={{ width: '100%', height: '100%', border: 'none' }}
          />
        </View>
      );
    }

    return (
      <View className="flex-1 bg-white p-6">
        <ScrollView contentContainerClassName="pb-10" showsVerticalScrollIndicator={false}>
          <View className="mb-6 items-center">
            <View className="h-16 w-16 items-center justify-center rounded-full bg-red-100 mb-3">
              <FileIcon size={32} color="#EF4444" />
            </View>
            <GenieText variant="heading-sm" className="text-black font-bold text-center">
              {displayName}
            </GenieText>
            <GenieText variant="caption" className="text-gray-500 mt-1">
              Legal Case Document ({badge.ext.toUpperCase()})
            </GenieText>
          </View>

          <View className="gap-3 rounded-lg bg-gray-50 p-4 border border-gray-200">
            <GenieText variant="body-md" className="font-bold text-black">
              Document Summary
            </GenieText>
            <GenieText variant="body-sm" className="text-gray-700">
              • Filename: {document.originalName}
            </GenieText>
            <GenieText variant="body-sm" className="text-gray-700">
              • Type: {document.mimeType || badge.ext.toUpperCase()}
            </GenieText>
            <GenieText variant="body-sm" className="text-gray-700">
              • Size: {metaText}
            </GenieText>
          </View>

          {blobUrl ? (
            <Pressable
              onPress={() => {
                const globalWin = (globalThis as any).window;
                if (globalWin && globalWin.open) {
                  globalWin.open(blobUrl, '_blank');
                }
              }}
              className="mt-6 h-12 flex-row items-center justify-center gap-2 rounded-control bg-black px-4 active:bg-gray-800"
            >
              <EyeIcon size={18} color={colors.white} />
              <GenieText variant="button" className="text-white">
                Open in Full Window
              </GenieText>
            </Pressable>
          ) : null}
        </ScrollView>
      </View>
    );
  };

  return (
    <Modal
      visible={visible}
      transparent={false}
      animationType="slide"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <SafeAreaView edges={['top', 'bottom']} className="flex-1 bg-background">
        <GenieHeader
          title={displayName}
          onBack={onClose}
        />

        <View className="flex-1 p-3">
          <View className="flex-1 overflow-hidden rounded-card border border-border bg-[#151515]">
            {renderContent()}
          </View>

          <View className="mt-3 gap-3">
            <View className="flex-row items-center rounded-card border border-border bg-[#151515] p-3">
              <View
                className={`h-11 w-11 items-center justify-center rounded-lg border ${badge.bgColor} ${badge.borderColor}`}
              >
                {badge.category === 'image' ? (
                  <ImageIcon size={18} color="#34D399" />
                ) : (
                  <FileIcon size={18} color={colors.gold} />
                )}
              </View>

              <View className="ml-3 flex-1">
                <GenieText variant="body-md" className="font-bold" numberOfLines={1}>
                  {displayName}
                </GenieText>
                <GenieText variant="caption" tone="secondary" className="mt-0.5">
                  {metaText}
                </GenieText>
              </View>
            </View>

            <Pressable
              onPress={() => onDownload(document)}
              disabled={isLoading || Boolean(errorText)}
              accessibilityRole="button"
              accessibilityLabel="Download document"
              className={`h-13 flex-row items-center justify-center gap-2 rounded-control bg-gold px-4 active:bg-gold-bright ${
                isLoading || Boolean(errorText) ? 'opacity-50' : ''
              }`}
            >
              <DownloadIcon size={20} color={colors.onGold} />
              <GenieText variant="button" tone="on-gold">
                Download
              </GenieText>
            </Pressable>
          </View>
        </View>
      </SafeAreaView>
    </Modal>
  );
};

import { formatDate } from '../../utils/format';
import { formatFileSize } from '../../utils/urls';
import type { AppDocument } from '../../types/domain';

export interface DocumentBadgeInfo {
  ext: string;
  category: 'pdf' | 'docx' | 'image' | 'text' | 'other';
  bgColor: string;
  textColor: string;
  borderColor: string;
}

export const getDocumentBadgeInfo = (doc: AppDocument): DocumentBadgeInfo => {
  const fileName = doc.name || doc.originalName || doc.fileName || '';
  const match = /\.([a-z0-9]+)$/i.exec(fileName);
  const ext = match ? match[1].toLowerCase() : '';
  const mime = (doc.mimeType || '').toLowerCase();

  if (ext === 'pdf' || mime.includes('pdf')) {
    return {
      ext: 'pdf',
      category: 'pdf',
      bgColor: 'bg-red-950/60',
      textColor: 'text-red-500',
      borderColor: 'border-red-900/60',
    };
  }

  if (ext === 'docx' || ext === 'doc' || mime.includes('word') || mime.includes('officedocument')) {
    return {
      ext: ext || 'doc',
      category: 'docx',
      bgColor: 'bg-blue-950/60',
      textColor: 'text-blue-400',
      borderColor: 'border-blue-900/60',
    };
  }

  if (['jpg', 'jpeg', 'png', 'webp', 'gif'].includes(ext) || mime.startsWith('image/')) {
    return {
      ext: ext || 'img',
      category: 'image',
      bgColor: 'bg-emerald-950/60',
      textColor: 'text-emerald-400',
      borderColor: 'border-emerald-900/60',
    };
  }

  if (['txt', 'md', 'csv'].includes(ext) || mime.startsWith('text/')) {
    return {
      ext: ext || 'txt',
      category: 'text',
      bgColor: 'bg-zinc-800',
      textColor: 'text-zinc-300',
      borderColor: 'border-zinc-700',
    };
  }

  return {
    ext: ext || 'file',
    category: 'other',
    bgColor: 'bg-zinc-800',
    textColor: 'text-zinc-300',
    borderColor: 'border-zinc-700',
  };
};

export const formatDocumentMeta = (doc: AppDocument): string => {
  const sizeStr = formatFileSize(doc.fileSize) || 'Unknown size';
  const dateStr = formatDate(doc.uploadedAt || doc.createdAt) || '';
  return dateStr ? `${sizeStr} • ${dateStr}` : sizeStr;
};

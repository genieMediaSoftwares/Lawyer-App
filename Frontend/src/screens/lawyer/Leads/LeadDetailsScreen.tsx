import React, { useState } from 'react';
import { View } from 'react-native';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  GenieAvatar,
  GenieButton,
  GenieNotice,
  GenieStatusBadge,
  GenieText,
} from '../../../components';
import {
  ClockIcon,
  CourtIcon,
  FileIcon,
  LocationIcon,
  ScalesIcon,
} from '../../../components/icons/ClientIcons';
import { CalendarIcon } from '../../../components/icons/LawyerIcons';
import { casesApi } from '../../../api/casesApi';
import { lawyerApi } from '../../../api/lawyerApi';
import { useAuthStore } from '../../../store/authStore';
import { toAppError } from '../../../utils/errors';
import { formatDate, formatDateTime } from '../../../utils/format';
import type { LegalCase } from '../../../types/domain';
import type { LawyerLead } from '../../../types/lawyer';
import type { LawyerStackScreenProps } from '../../../types/navigation';
import { colors } from '../../../theme';
import {
  CaseDocumentsSection,
  DetailRow,
  DetailSection,
  clientOf,
  shortId,
} from '../shared/CaseDetailParts';
import { DetailScaffold } from '../shared/DetailScaffold';

const OPEN_STATUSES = [
  'Submitted',
  'Awaiting Lawyer Acceptance',
  'Pending Lawyer Response',
  'Interested',
];

const idOf = (value: unknown): string | null => {
  if (!value) {
    return null;
  }
  if (typeof value === 'object') {
    return String((value as { _id?: string })._id ?? '') || null;
  }
  return String(value);
};

type RequestView =
  | { kind: 'open' }
  | { kind: 'mine' }
  | { kind: 'closed'; message: string };

const requestView = (item: LegalCase, myId: string | null): RequestView => {
  const assigned = idOf(item.assignedLawyer);
  if (assigned && myId && assigned === myId) {
    return { kind: 'mine' };
  }
  if (assigned) {
    return { kind: 'closed', message: 'This case has already been accepted by another lawyer.' };
  }
  const mine = item.myRequestStatus;
  if (mine === 'Pending' || (!mine && OPEN_STATUSES.includes(item.status))) {
    return { kind: 'open' };
  }
  if (mine === 'Declined') {
    return { kind: 'closed', message: 'You declined this case request.' };
  }
  return { kind: 'closed', message: 'This case request is no longer available.' };
};

export const LeadDetailsScreen: React.FC<LawyerStackScreenProps<'LeadDetails'>> = ({
  navigation,
  route,
}) => {
  const { caseId } = route.params;
  const queryClient = useQueryClient();
  const myId = useAuthStore(state => state.user?.id ?? null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [justAccepted, setJustAccepted] = useState(false);

  const caseQuery = useQuery({
    queryKey: ['lawyer', 'lead', caseId],
    queryFn: () => casesApi.getById(caseId),
    retry: (count, error) => {
      const status = toAppError(error).status;
      return count < 2 && (status === undefined || status >= 500);
    },
  });

  // The list already fetched this lead; reuse its match score instead of refetching.
  const listed = queryClient
    .getQueryData<LawyerLead[]>(['lawyer', 'leads'])
    ?.find(lead => String(lead.caseId) === caseId);

  const refreshLists = async () => {
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: ['lawyer', 'leads'] }),
      queryClient.invalidateQueries({ queryKey: ['lawyer', 'clients'] }),
      queryClient.invalidateQueries({ queryKey: ['chats'] }),
    ]);
  };

  const acceptMutation = useMutation({
    mutationFn: () => lawyerApi.acceptLead(caseId),
    onSuccess: async () => {
      setJustAccepted(true);
      await refreshLists();
      await caseQuery.refetch();
    },
    onError: async error => {
      setActionError(toAppError(error).message);
      await refreshLists();
    },
  });

  const declineMutation = useMutation({
    mutationFn: () => lawyerApi.rejectLead(caseId),
    onSuccess: async () => {
      await refreshLists();
      navigation.goBack();
    },
    onError: async error => {
      setActionError(toAppError(error).message);
      await refreshLists();
    },
  });

  const item = caseQuery.data;
  const busy = acceptMutation.isPending || declineMutation.isPending;

  return (
    <DetailScaffold
      title="Lead Details"
      onBack={() => navigation.goBack()}
      isPending={caseQuery.isPending}
      error={caseQuery.isError ? caseQuery.error : null}
      isRefetching={caseQuery.isRefetching}
      onRefresh={() => void caseQuery.refetch()}
    >
      {item ? (
        <LeadBody
          item={item}
          view={requestView(item, myId)}
          matchPercentage={listed?.matchPercentage ?? null}
          busy={busy}
          accepting={acceptMutation.isPending}
          declining={declineMutation.isPending}
          actionError={actionError}
          justAccepted={justAccepted}
          onAccept={() => {
            setActionError(null);
            acceptMutation.mutate();
          }}
          onDecline={() => {
            setActionError(null);
            declineMutation.mutate();
          }}
          onViewClient={clientId =>
            navigation.navigate('LawyerClientDetails', { clientId, caseId: item._id })
          }
        />
      ) : null}
    </DetailScaffold>
  );
};

interface LeadBodyProps {
  item: LegalCase;
  view: RequestView;
  matchPercentage: number | null;
  busy: boolean;
  accepting: boolean;
  declining: boolean;
  actionError: string | null;
  justAccepted: boolean;
  onAccept: () => void;
  onDecline: () => void;
  onViewClient: (clientId: string) => void;
}

const LeadBody: React.FC<LeadBodyProps> = ({
  item,
  view,
  matchPercentage,
  busy,
  accepting,
  declining,
  actionError,
  justAccepted,
  onAccept,
  onDecline,
  onViewClient,
}) => {
  const client = clientOf(item.client);
  const clientName = client?.fullName || 'Client';
  const documents = item.documents ?? [];
  const myRequest = item.lawyerRequests?.[0];
  const receivedAt = myRequest?.createdAt || item.createdAt;
  const category = [item.category, item.subcategory].filter(Boolean).join(' · ');

  return (
    <View testID="lead-details">
      <View className="flex-row items-center gap-3 rounded-card border border-border bg-surface p-4">
        <GenieAvatar uri={client?.profileImage} name={clientName} size="lg" />
        <View className="flex-1">
          <GenieText variant="heading-sm" numberOfLines={2} testID="lead-client-name">
            {clientName}
          </GenieText>
          {client?._id ? (
            <GenieText variant="caption" tone="muted" className="mt-0.5">
              Client ID: {shortId(client._id)}
            </GenieText>
          ) : null}
        </View>
        {matchPercentage !== null && matchPercentage !== undefined ? (
          <View className="rounded-md border border-success bg-success-surface px-2 py-1">
            <GenieText variant="caption" tone="success" className="font-bold">
              {matchPercentage}% Match
            </GenieText>
          </View>
        ) : null}
      </View>

      <GenieText variant="heading-lg" className="mt-5" testID="lead-case-title">
        {item.title || 'Untitled case'}
      </GenieText>
      <View className="mt-2 flex-row flex-wrap items-center gap-2">
        <GenieStatusBadge status={item.status} />
        <GenieText variant="caption" tone="muted">
          Posted {formatDate(item.createdAt)}
        </GenieText>
      </View>

      <DetailSection title="Case Information">
        <DetailRow
          label="Category"
          value={category}
          icon={<ScalesIcon size={15} color={colors.gold} />}
        />
        <DetailRow
          label="Urgency"
          value={item.urgency}
          icon={<ClockIcon size={15} color={colors.gold} />}
        />
        <DetailRow
          label="Posted on"
          value={formatDate(item.createdAt)}
          icon={<CalendarIcon size={15} color={colors.gold} />}
        />
        <DetailRow
          label="Documents"
          value={`${documents.length} ${documents.length === 1 ? 'document' : 'documents'}`}
          icon={<FileIcon size={15} color={colors.gold} />}
        />
      </DetailSection>

      <DetailSection title="Case Description">
        <GenieText
          variant="body-sm"
          tone={item.description ? 'secondary' : 'muted'}
          testID="lead-description"
        >
          {item.description || 'The client has not added a description.'}
        </GenieText>
      </DetailSection>

      <DetailSection title="Location & Court">
        <DetailRow
          label="Location"
          value={item.location || item.locationCity}
          icon={<LocationIcon size={15} color={colors.gold} />}
        />
        <DetailRow
          label="Preferred court"
          value={item.preferredCourt}
          icon={<CourtIcon size={15} color={colors.gold} />}
        />
      </DetailSection>

      <CaseDocumentsSection documents={documents} />

      <DetailSection title="Request Status" testID="lead-request-status">
        <DetailRow label="Received" value={formatDateTime(receivedAt)} />
        <DetailRow
          label="Your request"
          value={
            view.kind === 'mine'
              ? 'Accepted by you'
              : item.myRequestStatus || (view.kind === 'open' ? 'Pending' : '')
          }
        />
        {view.kind === 'open' ? (
          <GenieText variant="body-sm" tone="secondary">
            The first lawyer to accept takes this case.
          </GenieText>
        ) : null}
        {view.kind === 'closed' ? (
          <GenieNotice tone="warning" message={view.message} />
        ) : null}
        {view.kind === 'mine' ? (
          <GenieNotice
            tone="success"
            message={
              justAccepted
                ? 'Case accepted. The client is now in your Clients list.'
                : 'You accepted this case.'
            }
          />
        ) : null}
      </DetailSection>

      {actionError ? (
        <GenieNotice message={actionError} className="mt-4" />
      ) : null}

      {view.kind === 'open' ? (
        <View className="mt-5 flex-row gap-3" testID="lead-actions">
          <View className="flex-1">
            <GenieButton
              testID="lead-details-decline"
              label="Decline"
              variant="outline"
              loading={declining}
              loadingLabel="Declining..."
              disabled={busy}
              onPress={onDecline}
              fullWidth
            />
          </View>
          <View className="flex-1">
            <GenieButton
              testID="lead-details-accept"
              label="Accept Case"
              loading={accepting}
              loadingLabel="Accepting..."
              disabled={busy}
              onPress={onAccept}
              fullWidth
            />
          </View>
        </View>
      ) : null}

      {view.kind === 'mine' && client?._id ? (
        <GenieButton
          testID="lead-details-view-client"
          label="View Client"
          className="mt-5"
          onPress={() => onViewClient(client._id)}
          fullWidth
        />
      ) : null}
    </View>
  );
};

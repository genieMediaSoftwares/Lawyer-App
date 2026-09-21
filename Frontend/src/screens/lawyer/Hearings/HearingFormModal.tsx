import React, { useEffect, useState } from 'react';
import { Pressable, ScrollView, TextInput, View } from 'react-native';

import {
  GenieButton,
  GenieModal,
  GenieNotice,
  GenieText,
} from '../../../components';
import type {
  HearingInput,
  HearingStatus,
  LawyerClientRow,
  LawyerHearing,
} from '../../../types/lawyer';
import { colors } from '../../../theme';

/**
 * Add or edit a hearing.
 *
 * ── Why the fields are what they are ──────────────────────────────────────
 *
 * Exactly the six `Case.hearings[]` carries: date, timeSlot, court, purpose,
 * status, notes. There is no reminder field on the schema and no attendee
 * list, so neither is offered — a control that writes nowhere is worse than
 * an absent one.
 *
 * `timeSlot` and `court` are free text on purpose, and the model says why:
 * courts do not publish precise slots, and a hearing must be recordable at a
 * bench the seeded Court directory does not list. A time picker would be a
 * worse fit than the field it is replacing.
 *
 * The **case** is chosen rather than typed, from the advocate's own matters,
 * because the id becomes the route: `POST /cases/:id/hearings`. It is locked
 * when editing — moving a hearing to another case is not something the API
 * supports, and pretending otherwise would send an update to the wrong route.
 */

const STATUSES: { value: HearingStatus; label: string }[] = [
  { value: 'scheduled', label: 'Scheduled' },
  { value: 'completed', label: 'Completed' },
  { value: 'adjourned', label: 'Adjourned' },
  { value: 'cancelled', label: 'Cancelled' },
];

/** `YYYY-MM-DD`, which `new Date()` parses and the controller validates. */
const isValidDate = (value: string): boolean =>
  /^\d{4}-\d{2}-\d{2}$/.test(value.trim()) &&
  !Number.isNaN(Date.parse(value.trim()));

export interface HearingFormModalProps {
  visible: boolean;
  onClose: () => void;
  /** Present when editing; absent when adding. */
  hearing?: LawyerHearing | null;
  /** The advocate's matters, for the case picker when adding. */
  cases: LawyerClientRow[];
  isSaving: boolean;
  error: string | null;
  onSubmit: (caseId: string, payload: HearingInput) => void;
}

const Field: React.FC<{
  label: string;
  required?: boolean;
  children: React.ReactNode;
}> = ({ label, required = false, children }) => (
  <View className="mb-4">
    <GenieText variant="body-sm" className="mb-2 font-medium">
      {label}
      {required ? (
        <GenieText variant="body-sm" tone="error">
          {' *'}
        </GenieText>
      ) : null}
    </GenieText>
    {children}
  </View>
);

export const HearingFormModal: React.FC<HearingFormModalProps> = ({
  visible,
  onClose,
  hearing,
  cases,
  isSaving,
  error,
  onSubmit,
}) => {
  const isEditing = Boolean(hearing);

  const [caseId, setCaseId] = useState('');
  const [date, setDate] = useState('');
  const [timeSlot, setTimeSlot] = useState('');
  const [court, setCourt] = useState('');
  const [purpose, setPurpose] = useState('');
  const [status, setStatus] = useState<HearingStatus>('scheduled');
  const [notes, setNotes] = useState('');
  const [touched, setTouched] = useState(false);

  // Reset to the hearing being edited each time the sheet opens, so a
  // cancelled edit never leaks its half-typed values into the next one.
  useEffect(() => {
    if (!visible) {
      return;
    }
    setTouched(false);
    setCaseId(hearing?.caseId ?? '');
    setDate(hearing?.date ? hearing.date.slice(0, 10) : '');
    setTimeSlot(hearing?.timeSlot ?? '');
    setCourt(hearing?.court ?? '');
    setPurpose(hearing?.purpose ?? '');
    setStatus((hearing?.status as HearingStatus) ?? 'scheduled');
    setNotes(hearing?.notes ?? '');
  }, [hearing, visible]);

  const dateError =
    touched && !date.trim()
      ? 'A hearing date is required.'
      : touched && !isValidDate(date)
      ? 'Use the format YYYY-MM-DD.'
      : null;

  const caseError = touched && !caseId ? 'Choose the matter.' : null;

  const submit = () => {
    setTouched(true);

    if (!caseId || !isValidDate(date)) {
      return;
    }

    onSubmit(caseId, {
      date: date.trim(),
      timeSlot: timeSlot.trim(),
      court: court.trim(),
      purpose: purpose.trim(),
      status,
      notes: notes.trim(),
    });
  };

  return (
    <GenieModal
      visible={visible}
      onClose={onClose}
      title={isEditing ? 'Edit Hearing' : 'Add Hearing'}
      dismissOnBackdropPress={!isSaving}
    >
      <ScrollView
        className="max-h-[420px]"
        showsVerticalScrollIndicator={false}
        keyboardShouldPersistTaps="handled"
      >
        {/* Case */}
        {isEditing ? (
          <Field label="Matter">
            <View className="rounded-control border border-border bg-card px-4 py-3">
              <GenieText variant="body-md" numberOfLines={1}>
                {hearing?.caseTitle}
              </GenieText>
              <GenieText variant="caption" tone="muted" className="mt-0.5">
                {hearing?.clientName}
              </GenieText>
            </View>
          </Field>
        ) : (
          <Field label="Matter" required>
            {cases.length === 0 ? (
              <GenieText variant="body-sm" tone="muted">
                You have no matters to add a hearing to yet.
              </GenieText>
            ) : (
              <ScrollView
                className="max-h-40"
                showsVerticalScrollIndicator={false}
                nestedScrollEnabled
              >
                {cases.map(row => {
                  const active = caseId === row.caseId;
                  return (
                    <Pressable
                      key={row.caseId}
                      onPress={() => setCaseId(row.caseId)}
                      accessibilityRole="button"
                      accessibilityState={{ selected: active }}
                      className={`mb-2 min-h-touch justify-center rounded-control border px-4 py-3 active:opacity-80 ${
                        active
                          ? 'border-gold bg-gold-muted'
                          : 'border-border bg-card'
                      }`}
                    >
                      <GenieText
                        variant="body-md"
                        tone={active ? 'gold' : 'primary'}
                        numberOfLines={1}
                      >
                        {row.issue}
                      </GenieText>
                      <GenieText variant="caption" tone="muted" className="mt-0.5">
                        {row.name}
                      </GenieText>
                    </Pressable>
                  );
                })}
              </ScrollView>
            )}
            {caseError ? (
              <GenieText variant="caption" tone="error" className="mt-1">
                {caseError}
              </GenieText>
            ) : null}
          </Field>
        )}

        <Field label="Date" required>
          <TextInput
            value={date}
            onChangeText={setDate}
            placeholder="YYYY-MM-DD"
            placeholderTextColor={colors.textMuted}
            editable={!isSaving}
            className={`min-h-control rounded-control border bg-card px-4 py-3 text-body-lg text-white ${
              dateError ? 'border-error' : 'border-border'
            }`}
            accessibilityLabel="Hearing date"
          />
          {dateError ? (
            <GenieText variant="caption" tone="error" className="mt-1">
              {dateError}
            </GenieText>
          ) : null}
        </Field>

        <Field label="Time">
          <TextInput
            value={timeSlot}
            onChangeText={setTimeSlot}
            placeholder="10:30 AM, or Item 42"
            placeholderTextColor={colors.textMuted}
            editable={!isSaving}
            className="min-h-control rounded-control border border-border bg-card px-4 py-3 text-body-lg text-white"
            accessibilityLabel="Hearing time"
          />
        </Field>

        <Field label="Court">
          <TextInput
            value={court}
            onChangeText={setCourt}
            placeholder="Leave blank to use the case's preferred court"
            placeholderTextColor={colors.textMuted}
            editable={!isSaving}
            className="min-h-control rounded-control border border-border bg-card px-4 py-3 text-body-lg text-white"
            accessibilityLabel="Court"
          />
        </Field>

        <Field label="Purpose">
          <TextInput
            value={purpose}
            onChangeText={setPurpose}
            placeholder="Framing of charges, final arguments..."
            placeholderTextColor={colors.textMuted}
            editable={!isSaving}
            className="min-h-control rounded-control border border-border bg-card px-4 py-3 text-body-lg text-white"
            accessibilityLabel="Purpose of hearing"
          />
        </Field>

        <Field label="Status">
          <View className="flex-row flex-wrap gap-2">
            {STATUSES.map(option => {
              const active = status === option.value;
              return (
                <Pressable
                  key={option.value}
                  onPress={() => setStatus(option.value)}
                  disabled={isSaving}
                  accessibilityRole="button"
                  accessibilityState={{ selected: active }}
                  className={`min-h-touch justify-center rounded-pill border px-4 ${
                    active
                      ? 'border-gold bg-gold-muted'
                      : 'border-border active:opacity-80'
                  }`}
                >
                  <GenieText
                    variant="body-sm"
                    tone={active ? 'gold' : 'secondary'}
                    className={active ? 'font-semibold' : ''}
                  >
                    {option.label}
                  </GenieText>
                </Pressable>
              );
            })}
          </View>
        </Field>

        <Field label="Notes">
          <TextInput
            value={notes}
            onChangeText={setNotes}
            placeholder="Outcome, directions, what to prepare..."
            placeholderTextColor={colors.textMuted}
            multiline
            textAlignVertical="top"
            editable={!isSaving}
            className="min-h-[90px] rounded-control border border-border bg-card px-4 py-3 text-body-lg text-white"
            accessibilityLabel="Hearing notes"
          />
          <GenieText variant="caption" tone="muted" className="mt-1">
            Visible with the case, not private — your own notebook is under
            Notes.
          </GenieText>
        </Field>

        {error ? <GenieNotice tone="error" message={error} /> : null}
      </ScrollView>

      <View className="mt-4 flex-row gap-3">
        <GenieButton
          label="Cancel"
          variant="outline"
          onPress={onClose}
          disabled={isSaving}
          className="flex-1"
        />
        <GenieButton
          label={isEditing ? 'Save Changes' : 'Add Hearing'}
          loading={isSaving}
          onPress={submit}
          className="flex-1"
        />
      </View>
    </GenieModal>
  );
};

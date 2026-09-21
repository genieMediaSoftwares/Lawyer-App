import React, { useState } from 'react';
import { LayoutAnimation, Pressable, View } from 'react-native';

import { GenieText } from '../../../components';
import { ChevronRightIcon } from '../../../components/icons/ClientIcons';
import { ChevronDownIcon } from '../../../components/icons/Icons';
import { colors } from '../../../theme';

/**
 * Renders a research answer as collapsible sections.
 *
 * ── Why the headings are not a fixed list ─────────────────────────────────
 *
 * They come from the model, and the model is told which to use by
 * `RESEARCH_SYSTEM_INSTRUCTION` in `controllers/ai/aiController.js`:
 *
 *   ### Issue · ### Analysis · ### Authorities To Verify
 *   ### Practical Considerations · ### Gaps
 *
 * and that instruction tells it to **omit any heading that does not apply**.
 * So this splits on whatever headings arrive rather than looking for a set it
 * expects — a hardcoded list would render empty shells for omitted sections
 * and silently drop any heading the prompt later adds.
 *
 * "Authorities To Verify" is opened by default and marked, because the backend
 * prompt is explicit that remembered authority is a lead to check and never a
 * verified result. That framing is the server's, and it is surfaced rather
 * than softened.
 */

export interface ResearchSection {
  heading: string;
  body: string;
}

/** True for the section whose contents a court could be misled by. */
const isAuthorities = (heading: string): boolean =>
  /authorit|citation|precedent|case law/i.test(heading);

/**
 * Splits an answer into `### heading` blocks.
 *
 * Text before the first heading is kept under an empty heading and rendered
 * as a plain lead-in, so a short answer that carries no headings at all still
 * shows in full instead of vanishing.
 */
export const splitIntoSections = (text: string): ResearchSection[] => {
  const lines = (text || '').split('\n');
  const sections: ResearchSection[] = [];
  let current: ResearchSection = { heading: '', body: '' };

  for (const line of lines) {
    const match = line.trim().match(/^#{2,4}\s*(.+)$/);
    if (match) {
      if (current.heading || current.body.trim()) {
        sections.push({ ...current, body: current.body.trim() });
      }
      current = { heading: match[1].trim(), body: '' };
    } else {
      current.body += `${line}\n`;
    }
  }

  if (current.heading || current.body.trim()) {
    sections.push({ ...current, body: current.body.trim() });
  }

  return sections.filter(s => s.heading || s.body);
};

/** Bullets, bold runs and paragraphs. Deliberately small — not a full parser. */
const Body: React.FC<{ text: string }> = ({ text }) => (
  <View className="gap-2">
    {text.split('\n').map((line, index) => {
      const trimmed = line.trim();

      if (!trimmed) {
        return <View key={index} className="h-1" />;
      }

      if (/^[-*•]\s+/.test(trimmed)) {
        return (
          <View key={index} className="flex-row items-start gap-2 pl-1">
            <View className="mt-2 h-1.5 w-1.5 rounded-full bg-gold" />
            <GenieText variant="body-sm" tone="secondary" className="flex-1 leading-5">
              {trimmed.replace(/^[-*•]\s+/, '').replace(/\*\*/g, '')}
            </GenieText>
          </View>
        );
      }

      return (
        <GenieText key={index} variant="body-sm" tone="secondary" className="leading-5">
          {trimmed.replace(/\*\*/g, '')}
        </GenieText>
      );
    })}
  </View>
);

const SectionCard: React.FC<{ section: ResearchSection }> = ({ section }) => {
  const authorities = isAuthorities(section.heading);
  const [isOpen, setIsOpen] = useState(authorities);

  if (!section.heading) {
    return (
      <View className="mb-3 rounded-card border border-border bg-card p-4">
        <Body text={section.body} />
      </View>
    );
  }

  return (
    <View className="mb-3 overflow-hidden rounded-card border border-border bg-card">
      <Pressable
        onPress={() => {
          LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
          setIsOpen(open => !open);
        }}
        accessibilityRole="button"
        accessibilityState={{ expanded: isOpen }}
        accessibilityLabel={section.heading}
        className="min-h-touch flex-row items-center gap-3 px-4 py-3.5 active:opacity-80"
      >
        <GenieText variant="body-lg" tone="gold" className="flex-1 font-bold">
          {section.heading}
        </GenieText>

        {isOpen ? (
          <ChevronDownIcon size={18} color={colors.textSecondary} />
        ) : (
          <ChevronRightIcon size={18} color={colors.textSecondary} />
        )}
      </Pressable>

      {isOpen ? (
        <View className="px-4 pb-4">
          {authorities ? (
            <View className="mb-3 rounded-control border border-warning/40 bg-warning-surface px-3 py-2">
              <GenieText variant="caption" tone="warning" className="leading-4">
                Leads to verify, not verified results. Lawfly has no case-law
                database — check every authority in a reporter before relying
                on it.
              </GenieText>
            </View>
          ) : null}

          <Body text={section.body} />
        </View>
      ) : null}
    </View>
  );
};

export const ResearchAnswer: React.FC<{ text: string }> = ({ text }) => {
  const sections = splitIntoSections(text);

  if (sections.length === 0) {
    return null;
  }

  return (
    <View>
      {sections.map((section, index) => (
        <SectionCard key={`${section.heading}-${index}`} section={section} />
      ))}
    </View>
  );
};

const zlib = require("zlib");

/**
 * Minimal, dependency-free DOCX text extractor.
 *
 * A .docx is a ZIP archive whose body lives in `word/document.xml`, deflate-
 * compressed. The previous implementation read the archive as UTF-8 and
 * regexed for `<w:t>` tags — the tags are inside the compressed stream, so on
 * every real-world .docx it found nothing, returned an empty string, and the
 * caller's "almost no text" branch then raised a fraud flag accusing the
 * client's document of being a bad scan.
 *
 * This reads the ZIP central directory and inflates the one entry it needs.
 * Implemented on `zlib` rather than adding a dependency, because the archive
 * shape needed here is fixed and tiny.
 *
 * Format reference: PKWARE APPNOTE 6.3.x, sections 4.3.6-4.3.16.
 */

const EOCD_SIGNATURE = 0x06054b50;
const CENTRAL_FILE_SIGNATURE = 0x02014b50;
const LOCAL_FILE_SIGNATURE = 0x04034b50;

const STORED = 0;
const DEFLATED = 8;

/** Locates the End Of Central Directory record, scanning back over the comment. */
const findEndOfCentralDirectory = (buffer) => {
  // The EOCD is 22 bytes plus a comment of up to 65535 bytes.
  const earliest = Math.max(0, buffer.length - (22 + 0xffff));
  for (let i = buffer.length - 22; i >= earliest; i--) {
    if (buffer.readUInt32LE(i) === EOCD_SIGNATURE) return i;
  }
  return -1;
};

/**
 * Reads one named entry out of a ZIP buffer.
 * @returns {Buffer|null} the decompressed bytes, or null when absent.
 */
const readZipEntry = (buffer, wantedName) => {
  const eocd = findEndOfCentralDirectory(buffer);
  if (eocd === -1) return null;

  const entryCount = buffer.readUInt16LE(eocd + 10);
  let offset = buffer.readUInt32LE(eocd + 16);

  for (let i = 0; i < entryCount; i++) {
    if (offset + 46 > buffer.length) return null;
    if (buffer.readUInt32LE(offset) !== CENTRAL_FILE_SIGNATURE) return null;

    const compressionMethod = buffer.readUInt16LE(offset + 10);
    const compressedSize = buffer.readUInt32LE(offset + 20);
    const nameLength = buffer.readUInt16LE(offset + 28);
    const extraLength = buffer.readUInt16LE(offset + 30);
    const commentLength = buffer.readUInt16LE(offset + 32);
    const localOffset = buffer.readUInt32LE(offset + 42);
    const name = buffer.toString("utf8", offset + 46, offset + 46 + nameLength);

    if (name === wantedName) {
      if (buffer.readUInt32LE(localOffset) !== LOCAL_FILE_SIGNATURE) return null;

      // The local header repeats the name/extra lengths, and its extra field
      // routinely differs in length from the central one — so the data offset
      // must be computed from the local header, never the central entry.
      const localNameLength = buffer.readUInt16LE(localOffset + 26);
      const localExtraLength = buffer.readUInt16LE(localOffset + 28);
      const dataStart = localOffset + 30 + localNameLength + localExtraLength;
      const data = buffer.subarray(dataStart, dataStart + compressedSize);

      if (compressionMethod === STORED) return data;
      if (compressionMethod === DEFLATED) return zlib.inflateRawSync(data);
      return null; // bzip2/lzma: not produced by any Word version we accept.
    }

    offset += 46 + nameLength + extraLength + commentLength;
  }

  return null;
};

/** Decodes the five XML entities that can appear in `w:t` text runs. */
const decodeXmlEntities = (value) =>
  value
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");

/**
 * Extracts the visible text of a .docx.
 *
 * @param {Buffer} buffer  Raw file bytes.
 * @returns {string} Plain text, paragraph-separated. Empty when the archive
 *   holds no document body — the caller distinguishes that from a failure.
 * @throws when the file is not a readable DOCX, so the caller can report it as
 *   an extraction failure rather than as an empty document.
 */
const extractDocxText = (buffer) => {
  const documentXml = readZipEntry(buffer, "word/document.xml");
  if (!documentXml) {
    throw new Error("Not a readable .docx archive (no word/document.xml).");
  }

  const xml = documentXml.toString("utf8");

  // Paragraph and line breaks become newlines so sentences do not run together;
  // tab runs become spaces. Everything else is dropped with the tag strip.
  const withBreaks = xml
    .replace(/<w:p[\s>]/g, "\n<w:p ")
    .replace(/<w:br\s*\/?>/g, "\n")
    .replace(/<w:tab\s*\/?>/g, " ");

  const runs = withBreaks.match(/<w:t[^>]*>([\s\S]*?)<\/w:t>/g) || [];
  if (runs.length === 0) return "";

  // Rebuild in document order, preserving the newlines injected above by
  // walking the string rather than the match list alone.
  let text = "";
  let cursor = 0;
  for (const run of runs) {
    const at = withBreaks.indexOf(run, cursor);
    const between = withBreaks.slice(cursor, at);
    if (between.includes("\n")) text += "\n";
    text += decodeXmlEntities(run.replace(/<[^>]+>/g, ""));
    cursor = at + run.length;
  }

  return text.replace(/\n{3,}/g, "\n\n").trim();
};

module.exports = { extractDocxText, readZipEntry };

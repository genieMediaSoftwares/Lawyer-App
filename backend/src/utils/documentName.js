const path = require("path");

/**
 * Display-name handling for documents.
 *
 * A document's display name is chosen by its owner and then travels into two
 * places that treat text as syntax: a `Content-Disposition` header, and
 * whatever filesystem the browser saves to. Neither forgives a stray quote, a
 * newline or a `../`, so names are normalised once, here, rather than at each
 * call site.
 *
 * Nothing in this module touches the STORED file. `fileName` on disk is a
 * random token chosen at upload and never changes — renaming is metadata only.
 * That is what keeps two documents called "Petition.pdf" from colliding, and
 * what makes a malicious name unable to reach the filesystem at all.
 */

/** Windows reserves these regardless of extension. */
const RESERVED_STEMS = new Set([
  "con", "prn", "aux", "nul",
  "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9",
  "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9",
]);

/**
 * Characters that are illegal in a filename on Windows, plus the path
 * separators and control characters that make a name dangerous anywhere.
 */
// eslint-disable-next-line no-control-regex
const ILLEGAL = /[<>:"/\\|?*\u0000-\u001f]/g;

/** Longest display name accepted. Comfortably under every filesystem's limit. */
const MAX_NAME_LENGTH = 120;

/**
 * The name to show for a document.
 *
 * `name` is the owner's choice and `originalName` is what they uploaded.
 * Documents predating renaming have no `name`, so this is the one place the
 * two are resolved — everything else asks for the display name.
 */
const displayName = (document) => {
  const chosen = (document?.name || "").trim();
  return chosen || (document?.originalName || "").trim() || "document";
};

/** The extension of the stored file, which a rename must never change. */
const storedExtension = (document) => {
  const fromStored = path.extname(document?.fileName || "");
  if (fromStored) return fromStored.toLowerCase();
  return path.extname(document?.originalName || "").toLowerCase();
};

/**
 * Turns whatever the client typed into a safe display name carrying the
 * stored file's extension.
 *
 * Rules, in order:
 *  - path separators and control characters are stripped, so "../../etc/passwd"
 *    becomes "etcpasswd" rather than escaping anywhere;
 *  - leading dots are removed, so a name cannot be made hidden or empty;
 *  - a trailing extension the user typed is dropped when it already matches the
 *    stored one, so "Petition.pdf" does not become "Petition.pdf.pdf" — while
 *    "Exhibit A.1" keeps its ".1", because that is not the file's extension;
 *  - the real extension is appended, always, so a .pdf cannot be renamed into
 *    something that presents as a .html;
 *  - Windows reserved stems are prefixed rather than rejected, because "CON"
 *    is a legitimate abbreviation in a legal filename.
 *
 * @returns {{ok: true, name: string} | {ok: false, reason: string}}
 */
const sanitiseDisplayName = (rawInput, document) => {
  if (typeof rawInput !== "string") {
    return { ok: false, reason: "A document name is required." };
  }

  const extension = storedExtension(document);

  let candidate = rawInput
    .replace(ILLEGAL, "")
    // Collapse whitespace, including the newlines that would break a header.
    .replace(/\s+/g, " ")
    .trim()
    // A name may not start with a dot: that hides the file on unix systems and
    // "..", on its own, is a traversal token.
    .replace(/^\.+/, "")
    .trim();

  if (!candidate) {
    return { ok: false, reason: "A document name is required." };
  }

  // Drop a user-typed extension only when it is the file's own, so renaming
  // "report" to "report.pdf" does not yield "report.pdf.pdf".
  //
  // Repeatedly, because a name pasted from a previous rename can already carry
  // the doubling this exists to prevent ("Case.pdf.pdf"). Stripping stops
  // before the name is emptied, so ".pdf.pdf" on its own is rejected below
  // rather than silently becoming a bare extension.
  if (extension) {
    while (candidate.toLowerCase().endsWith(extension)) {
      const stripped = candidate.slice(0, -extension.length).trim();
      if (!stripped) break;
      candidate = stripped;
    }
  }

  if (!candidate || candidate.toLowerCase() === extension) {
    return { ok: false, reason: "A document name is required." };
  }

  if (RESERVED_STEMS.has(candidate.toLowerCase())) {
    candidate = `${candidate}_file`;
  }

  // Measured before the extension is added, so the limit is on what the user
  // controls and a long extension cannot push a valid name over.
  if (candidate.length > MAX_NAME_LENGTH) {
    return {
      ok: false,
      reason: `A document name may be at most ${MAX_NAME_LENGTH} characters.`,
    };
  }

  return { ok: true, name: `${candidate}${extension}` };
};

/**
 * A `Content-Disposition` value that survives a non-ASCII name.
 *
 * Two filename parameters are emitted on purpose: a quoted ASCII fallback for
 * old clients, and RFC 5987 `filename*` carrying the real UTF-8 name. A Telugu
 * or Hindi document name reaches the user intact through the second, and does
 * not corrupt the header for anything reading only the first.
 */
const contentDisposition = (type, name) => {
  const safeName = String(name || "document");

  // Quotes and backslashes would terminate or escape the quoted string.
  const ascii =
    safeName
      .replace(/[^\x20-\x7e]/g, "_")
      .replace(/["\\]/g, "_")
      .trim() || "document";

  const encoded = encodeURIComponent(safeName);

  return `${type}; filename="${ascii}"; filename*=UTF-8''${encoded}`;
};

module.exports = {
  displayName,
  storedExtension,
  sanitiseDisplayName,
  contentDisposition,
  MAX_NAME_LENGTH,
};

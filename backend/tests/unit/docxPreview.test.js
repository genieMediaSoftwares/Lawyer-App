const zlib = require("zlib");
const { docxToBlocks } = require("../../src/services/document/docxPreview");

function makeDocx(documentXml, entryName = "word/document.xml") {
  const name = Buffer.from(entryName, "utf8");
  const raw = Buffer.from(documentXml, "utf8");
  const deflated = zlib.deflateRawSync(raw);
  const crc = zlib.crc32 ? zlib.crc32(raw) : 0;

  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50, 0);
  local.writeUInt16LE(20, 4);
  local.writeUInt16LE(0, 6);
  local.writeUInt16LE(8, 8);
  local.writeUInt32LE(crc, 14);
  local.writeUInt32LE(deflated.length, 18);
  local.writeUInt32LE(raw.length, 22);
  local.writeUInt16LE(name.length, 26);
  local.writeUInt16LE(0, 28);

  const localBlock = Buffer.concat([local, name, deflated]);

  const central = Buffer.alloc(46);
  central.writeUInt32LE(0x02014b50, 0);
  central.writeUInt16LE(20, 4);
  central.writeUInt16LE(20, 6);
  central.writeUInt16LE(0, 8);
  central.writeUInt16LE(8, 10);
  central.writeUInt32LE(crc, 16);
  central.writeUInt32LE(deflated.length, 20);
  central.writeUInt32LE(raw.length, 24);
  central.writeUInt16LE(name.length, 28);
  central.writeUInt32LE(0, 42);

  const centralBlock = Buffer.concat([central, name]);

  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(1, 8);
  eocd.writeUInt16LE(1, 10);
  eocd.writeUInt32LE(centralBlock.length, 12);
  eocd.writeUInt32LE(localBlock.length, 16);

  return Buffer.concat([localBlock, centralBlock, eocd]);
}

const doc = (body) =>
  makeDocx(
    `<?xml version="1.0"?><w:document xmlns:w="x"><w:body>${body}</w:body></w:document>`
  );

const para = (text, props = "") =>
  `<w:p>${props}<w:r><w:t>${text}</w:t></w:r></w:p>`;

describe("docxToBlocks", () => {
  it("reads paragraphs out of a real archive", () => {
    const { blocks } = docxToBlocks(doc(para("First para") + para("Second para")));

    expect(blocks).toHaveLength(2);
    expect(blocks[0]).toMatchObject({ type: "paragraph", text: "First para" });
    expect(blocks[1].text).toBe("Second para");
  });

  it("recognises headings from the paragraph style", () => {
    const body =
      `<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Title</w:t></w:r></w:p>` +
      `<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Sub</w:t></w:r></w:p>` +
      para("Body");

    const { blocks } = docxToBlocks(doc(body));

    expect(blocks[0]).toMatchObject({ type: "heading", level: 1, text: "Title" });
    expect(blocks[1]).toMatchObject({ type: "heading", level: 2, text: "Sub" });
    expect(blocks[2].type).toBe("paragraph");
  });

  it("carries bold, italic and underline per run", () => {
    const body =
      `<w:p>` +
      `<w:r><w:rPr><w:b/></w:rPr><w:t>Bold </w:t></w:r>` +
      `<w:r><w:rPr><w:i/></w:rPr><w:t>Italic </w:t></w:r>` +
      `<w:r><w:rPr><w:u w:val="single"/></w:rPr><w:t>Under</w:t></w:r>` +
      `<w:r><w:t> plain</w:t></w:r>` +
      `</w:p>`;

    const { blocks } = docxToBlocks(doc(body));
    const runs = blocks[0].runs;

    expect(runs[0]).toMatchObject({ text: "Bold ", bold: true, italic: false });
    expect(runs[1]).toMatchObject({ italic: true, bold: false });
    expect(runs[2]).toMatchObject({ underline: true });
    expect(runs[3]).toMatchObject({ bold: false, italic: false, underline: false });
    expect(blocks[0].text).toBe("Bold Italic Under plain");
  });

  it("treats w:val=\"0\" as formatting switched OFF", () => {
    const body =
      `<w:p><w:r><w:rPr><w:b w:val="0"/></w:rPr><w:t>Not bold</w:t></w:r></w:p>`;

    const { blocks } = docxToBlocks(doc(body));
    expect(blocks[0].runs[0].bold).toBe(false);
  });

  it("recognises list items and their indent level", () => {
    const body =
      `<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr><w:r><w:t>Top</w:t></w:r></w:p>` +
      `<w:p><w:pPr><w:numPr><w:ilvl w:val="1"/></w:numPr></w:pPr><w:r><w:t>Nested</w:t></w:r></w:p>`;

    const { blocks } = docxToBlocks(doc(body));

    expect(blocks[0]).toMatchObject({ type: "listItem", indent: 0, text: "Top" });
    expect(blocks[1]).toMatchObject({ type: "listItem", indent: 1, text: "Nested" });
  });

  it("reads tables into rows and cells", () => {
    const cell = (t) => `<w:tc>${para(t)}</w:tc>`;
    const body =
      `<w:tbl>` +
      `<w:tr>${cell("Name")}${cell("Role")}</w:tr>` +
      `<w:tr>${cell("Ananya Rao")}${cell("Petitioner")}</w:tr>` +
      `</w:tbl>`;

    const { blocks } = docxToBlocks(doc(body));

    expect(blocks[0].type).toBe("table");
    expect(blocks[0].rows).toEqual([
      ["Name", "Role"],
      ["Ananya Rao", "Petitioner"],
    ]);
  });

  it("keeps a table's paragraphs from leaking out as body text", () => {
    const cell = (t) => `<w:tc>${para(t)}</w:tc>`;
    const body =
      `<w:tbl><w:tr>${cell("In table")}</w:tr></w:tbl>` + para("After table");

    const { blocks } = docxToBlocks(doc(body));

    expect(blocks).toHaveLength(2);
    expect(blocks[0].type).toBe("table");
    expect(blocks[1]).toMatchObject({ type: "paragraph", text: "After table" });
  });

  it("decodes XML entities, ampersand last", () => {
    const body = para("Smith &amp; Co &lt;tag&gt; &quot;quoted&quot; &amp;lt;");

    const { blocks } = docxToBlocks(doc(body));
    expect(blocks[0].text).toBe('Smith & Co <tag> "quoted" &lt;');
  });

  it("turns tabs and breaks into real whitespace", () => {
    const body =
      `<w:p><w:r><w:t>A</w:t><w:tab/><w:t>B</w:t><w:br/><w:t>C</w:t></w:r></w:p>`;

    const { blocks } = docxToBlocks(doc(body));
    expect(blocks[0].text).toBe("A\tB\nC");
  });

  it("collapses runs of blank paragraphs and trims the ends", () => {
    const blank = "<w:p></w:p>";
    const body = blank + blank + para("Body") + blank + blank + para("More") + blank;

    const { blocks } = docxToBlocks(doc(body));

    expect(blocks.map((b) => b.type)).toEqual([
      "paragraph",
      "spacer",
      "paragraph",
    ]);
  });

  it("reports truncation rather than returning an unbounded document", () => {
    const body = Array.from({ length: 2500 }, (_, i) => para(`Line ${i}`)).join("");

    const { blocks, truncated } = docxToBlocks(doc(body));

    expect(truncated).toBe(true);
    expect(blocks.length).toBeLessThanOrEqual(2000);
  });

  it("throws on an archive that is not a .docx", () => {
    expect(() => docxToBlocks(makeDocx("<x/>", "some/other.xml"))).toThrow(
      /not a readable .docx/i
    );
  });

  it("throws on bytes that are not a ZIP at all", () => {
    expect(() => docxToBlocks(Buffer.from("%PDF-1.4 this is a pdf"))).toThrow();
  });
});

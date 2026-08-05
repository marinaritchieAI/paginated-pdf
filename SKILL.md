---
name: paginated-pdf
description: Use whenever the user wants a PDF or printable document, a proposal, report, catalogue, guide, one-pager, brochure or handout produced from HTML or markdown, or when an existing HTML document converts to PDF or print badly, with wrong page breaks, floating footers, repeated or wrong page numbers, missing background colours, a heading stranded at a page bottom, or a blank last page.
---

# Paginated PDF

This skill solves one problem: positioning content on A4 pages so the document looks right in PDF and in print. HTML is the medium because it structures and presents information better than a rigid word processor file can; this skill's only job is to control where that content falls on each page. Produce the document as a single self-contained HTML file that paginates identically on screen and in PDF, then verify the PDF before calling it done.

Out of scope: brand systems. The four CSS variables in step 2 are the only styling hook. Palettes, type systems and logo treatments are a separate concern and a separate skill; do not add them here.

Do not use a PDF library. Do not use `position:fixed` headers. Do not let the browser print its own header or footer.

## When to use which surface

The HTML is built the same way everywhere. Only the render step differs.

- **Claude Code, or any environment with a local Chrome**: build the HTML, render it headless, verify with poppler. Full pipeline, steps 1 to 5.
- **Claude app (claude.ai)**: the sandbox has no local Chrome. Build the HTML, give it to the user, and tell them to open it in Chrome and print with **Margins: None** and **Background graphics: on**. The `@page` rules make that come out identical to the headless render. Skip step 4, do as much of step 5 as the user can run.

## 1. Structure: one `.sheet` per printed page

```html
<div class="doc">

  <!-- PAGE 1: cover, no running header -->
  <div class="sheet">
    <header class="cover"> ... full-bleed cover content ... </header>
    <div class="pagefoot">
      <span>LEFT FOOTER TEXT</span>
      <span>DOCUMENT NAME &middot; <b>1</b> / 5</span>
    </div>
  </div>

  <!-- PAGES 2..N: running header, body, running footer -->
  <div class="sheet">
    <div class="pagehead">
      <span>DOCUMENT NAME</span>
      <span>Section title</span>
    </div>
    <div class="pg">
      <section>
        <div class="sechead"><span class="secnum">01</span><h2>Heading</h2></div>
        ... body ...
      </section>
    </div>
    <div class="pagefoot">
      <span>LEFT FOOTER TEXT</span>
      <span>DOCUMENT NAME &middot; <b>2</b> / 5</span>
    </div>
  </div>

</div>
```

Rules:

- One `.sheet` is one physical page. Content does not flow between sheets. If a section is too long for its page, split it into another `.sheet` yourself.
- `.sheet` is a flex column: `.pagehead` at the top (`flex:none`), `.pg` fills the middle (`flex:1`), `.pagefoot` pinned to the bottom (`margin-top:auto`).
- Header and footer text is written into each sheet by hand. There is no CSS counter, which is exactly why the numbers are checkable by a script (step 5).
- Every sheet carries the same `/ N` total. Update all of them when you add or remove a page.

## 2. CSS: the page layer

Swap the four variables at the top for the document's brand. Everything below them is structural and stays as it is.

```css
:root{
  --page-bg:#ffffff;      /* the paper */
  --desk-bg:#e6e4de;      /* behind the pages, screen only */
  --ink:#1a1a1a;
  --rule:#e2e0da;         /* header and footer hairlines */
}

html{ -webkit-print-color-adjust:exact; print-color-adjust:exact; }
body{ background:var(--desk-bg); color:var(--ink); }

.doc{ max-width:210mm; margin:0 auto; }
.sheet{ position:relative; background:var(--page-bg); }
.pg{ padding:18mm; }

/* running header and footer share one type treatment */
.pagehead,.pagefoot{
  display:none;                       /* switched on by the screen and print blocks */
  justify-content:space-between; align-items:center;
  padding:11px 18mm;
  font-size:.72rem; font-weight:600; letter-spacing:.06em;
}
.pagehead{ border-bottom:1px solid var(--rule); }
.pagefoot{ border-top:1px solid var(--rule); }

/* ---- screen preview: draw each sheet as a discrete A4 page ---- */
@media screen{
  .doc{ padding:28px 0; }
  .sheet{
    width:210mm; min-height:297mm; margin:0 auto 26px;
    display:flex; flex-direction:column;
    box-shadow:0 6px 28px rgba(0,0,0,.16);
  }
  .sheet>.cover{ min-height:0; flex:1; }
  .pg{ flex:1; }
  .pagehead{ display:flex; flex:none; }
  .pagefoot{ display:flex; margin-top:auto; flex:none; }
}

/* ---- print and PDF ---- */
@page{ size:A4; margin:0; }            /* margin 0: the sheet owns its own margins */
@media print{
  body{ background:#fff; }
  .doc{ max-width:none; margin:0; box-shadow:none; }
  .sheet{
    min-height:296mm;                  /* 1mm under A4, see note */
    display:flex; flex-direction:column;
    break-after:page;
  }
  .sheet:last-child{ break-after:auto; }  /* no trailing blank page */
  .sheet>.cover{ flex:1; min-height:0; }
  .pg{ flex:1; padding-top:14mm; padding-bottom:10mm; }
  .pagehead{ display:flex; flex:none; }
  .pagefoot{ display:flex; margin-top:auto; flex:none; }

  /* never split these across a page boundary */
  .card,.quote,.table-block,.signoff,table{ break-inside:avoid; }
  .sechead{ break-after:avoid; }       /* heading never orphaned at page bottom */
}
```

Why each line matters:

- `@page{ margin:0 }` plus padding on `.pg` gives one margin system, controlled by you, identical on screen and in PDF. Mixing `@page` margins with element padding is the usual cause of a footer that drifts between preview and export.
- `break-after:page` on `.sheet`, reset with `:last-child{ break-after:auto }`. Without the reset you get a blank final page.
- `print-color-adjust:exact` keeps background fills, coloured bars and reversed panels in the PDF. Without it Chrome drops them and the document prints hollow.
- `min-height:296mm` is defensive slack. Chrome tolerates a full 297mm, including with a border and extra padding on the sheet, so the 1mm is not a Chrome workaround. Keep it anyway: it costs nothing and protects against other print engines and against a stray border added later.
- No `position:fixed` header or footer. Fixed positioning repeats unreliably across print engines. The per-sheet flex header and footer are deterministic.

`reference/template.html` is a working three-sheet document using exactly this CSS. Start from it rather than retyping.

## 3. Images and fonts

- Embed every image as a base64 `data:` URI. The finished HTML must render correctly with no sibling asset folder. External paths fail silently in a headless render.
- Use a system font stack, or embed the font as base64 inside `@font-face`. A webfont fetched over the network may not arrive before the renderer snapshots the page.

## 4. Render to PDF

macOS:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless \
  --print-to-pdf=/tmp/doc.pdf \
  --no-pdf-header-footer \
  /absolute/path/to/doc.html
```

Linux: same flags, binary `google-chrome` or `chromium`.

- `--no-pdf-header-footer` is mandatory. Without it Chrome stamps its own URL, date and page numbers over your footer.
- Add `--force-prefers-reduced-motion` if the page has CSS animation or reveal-on-scroll, so nothing is captured mid-transition.
- Pass an absolute path to the HTML. Relative paths and `~` fail under `--headless`.
- Chrome writes harmless noise to stderr, such as allocator warnings and web-app install errors. Judge success by the `N bytes written to file` line, not by stderr.

Manual equivalent, for the Claude app or any user without a terminal: open the HTML in Chrome, press Cmd+P or Ctrl+P, set **Destination: Save as PDF**, **Margins: None**, and tick **Background graphics**. Those three settings are what the headless flags do.

## 5. Verify before calling it done

Never claim a document is finished without running this.

```bash
bash reference/checker.sh /absolute/path/to/doc.html /tmp/doc.pdf
```

The script checks what a script can check: the page count against the `/ N` written in the footers, a single distinct total across all sheets, a footer present for every page from 1 to N, no blank trailing page, and no leftover `{{TOKEN}}` placeholders. It exits non-zero listing every failure.

Then look at the pages yourself:

```bash
pdfinfo /tmp/doc.pdf | grep -E "Pages|Page size"   # expect N and A4, 595 x 842 pts
pdftotext -layout /tmp/doc.pdf - | head -40        # header and footer text per page
pdftoppm -png -r 78 /tmp/doc.pdf /tmp/page         # one PNG per page, then read them
```

Confirm, page by page:

1. Page count matches the `/ N` written in the footers.
2. Page size is A4, 595 x 842 pts.
3. No blank trailing page.
4. Running header and footer appear on every page they should, in the same position.
5. No heading stranded at a page bottom with its body on the next page.
6. No card, table or quote split across a break.
7. Background fills and accent colours survived.
8. No unresolved `{{TOKEN}}` placeholders.

Poppler supplies `pdfinfo`, `pdftotext` and `pdftoppm`. On macOS install it with `brew install poppler`; on Debian or Ubuntu with `apt install poppler-utils`. If poppler is unavailable, say so plainly rather than claiming the document is verified.

## Failure modes this prevents

| Symptom | Cause | Fix |
|---|---|---|
| Chrome's URL and date printed over your footer | default headless behaviour | `--no-pdf-header-footer` |
| Colours and fills missing in the PDF | Chrome strips backgrounds when printing | `print-color-adjust:exact` |
| Footer floats mid-page | sheet is not a flex column | flex column plus `margin-top:auto` |
| Blank page at the end | `break-after:page` on the last sheet | `:last-child{ break-after:auto }` |
| Screen preview and PDF disagree | two competing margin systems | `@page margin:0`, padding on `.pg` |
| Images missing in the PDF | external file paths | base64 data URIs |
| Header appears once, not per page | `position:fixed` | per-sheet `.pagehead` |
| Heading alone at the bottom of a page | no break control | `.sechead{ break-after:avoid }` |
| Page numbers wrong after an edit | hand-written numbers | `reference/checker.sh` |

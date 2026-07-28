# paginated-pdf

A skill for Claude that builds HTML documents which convert to PDF cleanly, every time.

Models write good-looking HTML quickly. That HTML usually converts to PDF badly:
page numbers repeat, the footer floats halfway up the page, background colours
disappear, headings strand at the bottom of a page with their body overleaf, and
there is a blank page at the end.

This skill fixes that with a one-sheet-per-page model, a print stylesheet that
gives screen and PDF a single shared margin system, and a checker script that
proves the output before you send it.

Brand-neutral. Swap the four colour variables at the top of the CSS and it works
for any business.

## What is in the box

| File | What it does |
|---|---|
| `SKILL.md` | The instructions Claude follows: the sheet model, the CSS, the render commands, the verification checklist |
| `reference/template.html` | A working three-sheet A4 document. Start here rather than from a blank file |
| `reference/checker.sh` | Verifies a document: page count against the footer totals, one footer per page, no blank trailing page, no leftover placeholders |

## Install for Claude Code

```bash
git clone https://github.com/marinaritchieAI/paginated-pdf.git ~/.claude/skills/paginated-pdf
```

That is the whole install. Claude Code reads `~/.claude/skills/` at startup, so
restart your session and the skill is available. To scope it to one project
instead of your whole machine, clone into `.claude/skills/paginated-pdf` inside
that project.

No git? Download the zip from the repository, unzip it, and rename the folder to
`paginated-pdf` inside `~/.claude/skills/`.

**Check it worked.** Start a session and ask for something that should trigger it,
without naming the skill:

> Turn this markdown into an A4 PDF with running headers and page numbers.

Claude should announce the `paginated-pdf` skill. If it does not, confirm the path
is `~/.claude/skills/paginated-pdf/SKILL.md` exactly, and that you restarted.

### Prerequisites for the full pipeline

Rendering and verification run on your own machine:

- **Google Chrome**, for the headless render.
- **poppler**, for the verification tools. macOS: `brew install poppler`.
  Debian or Ubuntu: `sudo apt install poppler-utils`.

Without poppler the skill still builds correct HTML and Chrome still renders the
PDF; you just cannot run the automated checks.

## Install for the Claude app (claude.ai)

The app takes skills as a zip.

1. Download `paginated-pdf.zip` from the repository releases, or make it yourself:
   `zip -r paginated-pdf.zip paginated-pdf` from the folder *above* this one.
   The zip must contain a single top-level folder named `paginated-pdf` holding
   `SKILL.md`. Files loose in the zip root will be rejected.
2. In Claude, go to **Settings**, then **Capabilities**, and turn on code
   execution. Skills do not run without it.
3. Go to **Customize**, then **Skills**, click **Add**, and upload the zip.
4. Toggle the skill on.

Custom skills in the app need a Pro, Max, Team or Enterprise plan, and they are
per user: each person on your team uploads their own copy.

**One difference in the app.** The app runs in a sandbox with no local Chrome, so
it cannot render the PDF for you. It gives you the finished HTML instead. To get
the PDF:

1. Download the HTML file and open it in Chrome.
2. Press Cmd+P, or Ctrl+P on Windows.
3. Set **Destination** to *Save as PDF*, **Margins** to *None*, and tick
   **Background graphics**.

Those three settings do what the headless flags do. The document is built so that
the print output matches the on-screen preview exactly.

## Using it

Ask for the document you want. The skill triggers on its own for proposals,
reports, catalogues, guides, one-pagers, brochures and handouts, and on any
request to fix an HTML document that converts to PDF badly.

To verify a finished document yourself:

```bash
bash ~/.claude/skills/paginated-pdf/reference/checker.sh /path/to/doc.html /path/to/doc.pdf
```

It exits non-zero and lists every failure, so it can go in a build script.

## Licence

MIT. Use it, change it, ship it.

Built by [Marina Ritchie](https://marinaritchie.com), AI Strategy and Adoption.

# Booklet

This repository allows you to transform a Markdown file into a printable **A6 booklet**.

You simply write your content in Markdown and run a build script.
The script generates:

* an **A6 PDF** with correctly ordered pages
* a second **imposed PDF** ready for booklet printing

## Step 1 — Create your Markdown file

Create a Markdown document:

```bash
notes.md
```

Write your content normally using Markdown.

## Step 2 — Build the booklet

Run the build script:

```bash
./build.sh <input-markdown> <output-name>
```

Example:

```bash
./build.sh notes.md my-booklet
```

## Output

After execution, the `output/` folder will contain:

```plain
output/
├── my-booklet-a6.pdf
└── my-booklet-imposed-a4.pdf
```

### `my-booklet-a6.pdf`

A6-sized PDF with pages already ordered correctly.

### `my-booklet-imposed-a4.pdf`

Booklet imposition version ready for printing.

---

## Print

Print the `*-imposed-a4.pdf` file:

* double-sided printing
* flip on **short edge**
* fold sheets in half

Your booklet is ready.

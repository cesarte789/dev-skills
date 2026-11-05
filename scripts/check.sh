#!/usr/bin/env bash
# The pre-push checks for this plugin. CI runs this same script
# (.github/workflows/validate.yml), so a green local run means a green check.
#
# Usage: scripts/check.sh [<base-ref>]
#   With a base ref (e.g. origin/main), also require a higher plugin.json
#   version when what the plugin ships changed since the branch left it.
set -euo pipefail
cd "$(dirname "$0")/.."

# Skills learn from private repos, and a lesson copied back here could leak their
# names or data. The term list lives outside the repo so it never leaks either;
# CI has none, so there this step is skipped. A push publishes commits, not the
# working tree, so every commit since <base-ref> (or HEAD alone) is scanned too:
# its files, paths, message, author and committer, plus the branch name.
private_terms="${DEV_SKILLS_PRIVATE_TERMS:-$HOME/.config/dev-skills/private-terms}"
if [ -n "${DEV_SKILLS_PRIVATE_TERMS:-}" ] && [ ! -f "$private_terms" ]; then
  echo "error: DEV_SKILLS_PRIVATE_TERMS names no file: $private_terms" >&2
  exit 1
fi
found_terms() {
  local status=0
  "$@" || status=$?
  if [ "$status" -gt 1 ]; then
    echo "error: $1 failed searching for private terms" >&2
    exit 1
  fi
  [ "$status" -eq 0 ]
}
if [ -f "$private_terms" ]; then
  terms="$(sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$private_terms")"
  term_args=()
  while IFS= read -r term; do
    [ -n "$term" ] && term_args+=(-e "$term")
  done <<<"$terms"
  if [ "${#term_args[@]}" -gt 0 ]; then
    revs=(HEAD)
    if [ -n "${1:-}" ] && git rev-parse --verify --quiet "$1^{commit}" >/dev/null; then
      revs=()
      while IFS= read -r rev; do revs+=("$rev"); done < <(git rev-list "$1..HEAD")
    fi
    paths_and_messages="$(
      git -c core.quotePath=false ls-files --cached --others --exclude-standard | sed 's|^|path: |'
      git rev-parse --abbrev-ref HEAD | sed 's|^|branch: |'
      for rev in ${revs[@]+"${revs[@]}"}; do
        git -c core.quotePath=false ls-tree -r --name-only "$rev" | sed "s|^|$rev path: |"
        git log -1 --format='%B%n%an <%ae>%n%cn <%ce>' "$rev" | sed "s|^|$rev message: |"
      done
    )"
    leaked=0
    found_terms git grep -n -i -F "${term_args[@]}" --untracked && leaked=1
    [ "${#revs[@]}" -gt 0 ] && found_terms git grep -n -i -F "${term_args[@]}" "${revs[@]}" && leaked=1
    found_terms grep -i -F "${term_args[@]}" <<<"$paths_and_messages" && leaked=1
    if [ "$leaked" -eq 1 ]; then
      echo "error: the lines above contain a term from $private_terms" >&2
      exit 1
    fi
    echo "no private terms found"
  fi
fi

# Both are needed: on the repo root, validate checks only marketplace.json;
# validating plugin.json is what parses each skill's SKILL.md frontmatter.
claude plugin validate . --strict
claude plugin validate .claude-plugin/plugin.json --strict

# validate never parses output-style frontmatter, and a broken one loads silently.
python3 - <<'PY'
import glob
import sys

import yaml

failed = False
for path in sorted(glob.glob("output-styles/*.md")):
    lines = open(path, encoding="utf-8-sig").read().splitlines()
    closing = next((i for i, line in enumerate(lines[1:], 1) if line.strip() == "---"), None)
    if not lines or lines[0].strip() != "---" or closing is None:
        print(f"error: {path}: no '---' frontmatter block at the top", file=sys.stderr)
        failed = True
        continue
    try:
        meta = yaml.safe_load("\n".join(lines[1:closing]))
    except yaml.YAMLError as e:
        print(f"error: {path}: frontmatter failed to parse: {e}", file=sys.stderr)
        failed = True
        continue
    missing = [k for k in ("name", "description")
               if not isinstance(meta, dict) or not isinstance(meta.get(k), str) or not meta[k].strip()]
    for key in missing:
        print(f"error: {path}: frontmatter needs a non-empty '{key}'", file=sys.stderr)
    failed = failed or bool(missing)
    if not missing:
        print(f"{path}: frontmatter ok")
sys.exit(1 if failed else 0)
PY

# Each skill loads on its own, so the repo-conventions rule is inlined in every
# skill that uses it rather than shared from one file. Keep the copies identical,
# and present wherever a skill relies on the term.
python3 - <<'PY'
import glob
import re
import sys

BLOCK = re.compile(r"<!-- repo-conventions -->\n.*?\n<!-- /repo-conventions -->", re.S)

failed = False
blocks = {}
for path in sorted(glob.glob("skills/*/SKILL.md")):
    text = open(path, encoding="utf-8").read()
    found = BLOCK.findall(text)
    opens, closes = text.count("<!-- repo-conventions -->"), text.count("<!-- /repo-conventions -->")
    if len(found) > 1 or opens != len(found) or closes != len(found):
        print(f"error: {path}: needs exactly one balanced repo-conventions block", file=sys.stderr)
        failed = True
    elif found:
        blocks[path] = found[0]
    elif re.search(r"repo\s+conventions", text, re.I):
        print(f"error: {path}: says 'repo conventions' but carries no repo-conventions block", file=sys.stderr)
        failed = True
if len(set(blocks.values())) > 1:
    first = next(iter(blocks))
    for path, block in blocks.items():
        if block != blocks[first]:
            print(f"error: {path}: repo-conventions block differs from {first}'s; copy it word for word", file=sys.stderr)
    failed = True
if not failed:
    print(f"repo-conventions block identical in {len(blocks)} skills")
sys.exit(1 if failed else 0)
PY

# A skill with an Operations section promises that a port, or a dev-skills-ops
# override, needs to replace that section alone, so no gh or git command may
# appear outside it. Skills without the section are not checked yet.
# README's "Platform overrides" lists the entry names of each such section, one
# line per skill, for override authors: keep each list equal to the skill's own
# entries, and the section in the layout read below.
python3 - <<'PY'
import glob
import re
import sys

# Command-shaped only: the tool, any global options, then one of its
# subcommands, so prose such as "a git repo" or "use gh" passes, while a
# quoted, tab-separated or `git -C <dir> diff` form is caught.
GIT = ("add am apply bisect blame branch cat-file checkout cherry-pick clean clone commit config describe diff "
       "fetch for-each-ref format-patch gc grep init log notes reflog ls-files ls-remote ls-tree merge merge-base mv pull push "
       "rebase remote reset restore rev-list rev-parse revert rm show stash status switch "
       "show-ref submodule symbolic-ref tag update-ref worktree")
GH = ("api auth browse cache codespace extension gist issue label org pr project release repo ruleset run search secret status "
      "variable workflow")
OPTIONS = r"(?:\s+(?:-[A-Za-z]\s+\S+|--[\w-]+(?:=\S+|\s+[^\s-]\S*)?))*"
COMMAND = re.compile(r"(?:^|[\s`'\"(])(?:(git)" + OPTIONS + r"\s+(?:" + "|".join(GIT.split())
                     + r")|(gh)" + OPTIONS + r"\s+(?:" + "|".join(GH.split()) + r"))(?![\w-])", re.M)

# Operations sections and the README list keep the strict layout that
# .claude/CLAUDE.md states under "Before pushing" (stated there only, so the two
# never drift), so a reader needs no markdown parser to find every item.
# Anything off it fails, rather than risk an entry being read past silently.
BULLET = re.compile(r"^- \*\*(.+?)\*\*(.*)$")
MARKER = re.compile(r"(?:[-*+]|\d+[.)])(?:\s|$)")
OPEN_FENCE = re.compile(r"  ```[\w-]*")
CLOSE_FENCE = "  ```"
# The start of any raw HTML (a tag, `<?`, `<!X`, `<![CDATA[`), closed on the
# line or not; a `<!--` comment is left to the comment rule.
TAG = re.compile(r"<(?:[A-Za-z/?]|!(?!--))")
OPERATIONS = re.compile(r" {0,3}##[ \t]+Operations\b")
OVERRIDES = re.compile(r"## Platform overrides")  # matched whole: the heading exactly
FENCE_START = ("```", "~~~")
SENTENCE = " keep every platform command in an "  # the README sentence naming the skills with an Operations section
# A one-line comment that reads the same under every CommonMark version: no `<!-->` or `<!--->` opener and no
# `--` inside. Any other `<!--` fails, so text a comment seems to hide is never text that renders.
COMMENT = re.compile(r"<!--(?!-?>)(?:(?!--).)*-->")
HEADING = re.compile(r" {0,3}#{1,6}(?:[ \t]|$)")
UNDERLINE = re.compile(r" {0,3}(?:=+|-+)[ \t]*")
RULE = re.compile(r" {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*|" + UNDERLINE.pattern)  # a thematic break or setext underline


def unfenced_lines(lines, start=0):
    """The indices of lines[start:] that lie outside code fences."""
    fenced = False
    for i in range(start, len(lines)):
        if lines[i].lstrip(" ").startswith(FENCE_START):
            fenced = not fenced
        elif not fenced:
            yield i


def section_end(lines, start):
    """Where the section opened at lines[start] ends: the next level-1 or level-2
    ATX heading at the margin, outside code fences. An indented heading, a rule
    or a setext underline inside the section fails as off the layout instead,
    so none is misread as the section's end."""
    return next((i for i in unfenced_lines(lines, start + 1) if re.match(r"##?(?:[ \t]|$)", lines[i])), len(lines))


CONTAINER = re.compile(r"[ \t]*(?:(?:>|[-*+]|\d+[.)])[ \t]*)*")  # leading blockquote and list markers


def as_title(text):
    """text with HTML tags, `*`, `_`, backticks and backslashes blanked: a title as it reads."""
    return re.sub(r"<[^>]*>|[*_`\\]", " ", text)


def setext_title(lines, i, title):
    """Whether lines[i:] open a setext title matching `title`: the lines from i
    up to a `=`/`-` underline (read past its blockquote markers) in the same
    run of non-blank lines, each read past its blockquote and list markers, joined as one title (a title may
    wrap) and read through `as_title()`, so an emphasised or quoted title counts."""
    for k in range(i + 1, len(lines)):
        if not lines[k].strip():
            return False
        if UNDERLINE.fullmatch(re.sub(r"^[ \t]*(?:>[ \t]*)+", "", lines[k])):  # an underline may be quoted
            joined = " ".join(line[CONTAINER.match(line).end():] for line in lines[i:k])
            return bool(re.match(r"\s*" + title, as_title(joined)))
    return False


def headings(lines, atx, title, name):
    """The indices of the headings in lines that are ATX headings `atx` accepts,
    setext headings whose title, from that line to a `=` or `-` underline
    in the same run of non-blank lines and joined, matches `title` (a title
    may wrap), or headings named `name` in any other form: ATX at any level
    or indent, inside a blockquote or list item, with its title emphasised,
    or as an `<h1>`-`<h6>` tag, read to the next blank line (see
    `other_heading()`); the second list holds the setext ones, the third the
    other forms. Any such line counts,
    whatever precedes it: telling a real setext heading from the last line of
    a paragraph takes a markdown parser, and a false count fails loudly where
    a missed one would pass silently. Lines in code fences count
    too, so a fence misread before a heading never hides it: an example heading
    fails loudly as a second section instead."""
    found, setext, contained = [], [], []
    # YAML frontmatter is no markdown: skip it.
    first = next((k + 1 for k in range(1, len(lines)) if lines[k] == "---"), 0) if lines[:1] == ["---"] else 0
    for i in range(first, len(lines)):
        if atx(lines[i]):
            found.append(i)
        elif lines[i].strip() and not UNDERLINE.fullmatch(lines[i]) and setext_title(lines, i, title):
            found.append(i)
            setext.append(i)
        elif other_heading(lines, i, name):
            found.append(i)
            contained.append(i)
    return found, setext, contained


def other_heading(lines, i, name):
    """Whether lines[i] opens a heading whose title, with HTML tags, `*`, `_`,
    backticks and backslashes dropped, starts with `name`: an ATX heading at any
    level, indent or depth of blockquote and list markers, or an `<h1>`-`<h6>`
    tag read from its `<h` to the next blank line (a tag may wrap)."""
    atx = re.match(CONTAINER.pattern + r"#{1,6}[ \t]+(.*)", lines[i])
    if atx and re.match(r"\s*" + name, as_title(atx.group(1))):
        return True
    tag = re.search(r"<h[1-6](?![0-9A-Za-z-])", lines[i], re.IGNORECASE)
    if not tag:
        return False
    k = next((k for k in range(i + 1, len(lines)) if not lines[k].strip()), len(lines))
    return bool(re.match(r"\s*" + name, as_title(" ".join([lines[i][tag.start():]] + lines[i + 1:k]))))


def prose(text):
    """text with its code spans blanked out."""
    return re.sub(r"`[^`]*`", lambda m: " " * len(m.group()), text)


def needs_blank_before(line):
    """Whether line, right after an item or a closing fence, must have a blank
    line before it: it is no wrapped line (two spaces in) and no next item."""
    return bool(line.strip()) and not line.startswith("  ") and not MARKER.match(line.lstrip(" "))


def shown(text, fill=" "):
    """text as it renders, at its own length: code spans blanked, then each
    one-line comment filled with `fill`, so offsets still map back to text."""
    return COMMENT.sub(lambda m: fill * len(m.group()), prose(text))


def uncommented(line):
    """line without its one-line comments (found outside code spans, as markdown reads them), code kept, and
    its runs of spaces outside code spans closed up, as they render."""
    kept = "".join(char for char, seen in zip(line, shown(line, fill="\0")) if seen != "\0")
    # Spaces close up outside code spans only: inside one they render as written.
    return "".join(part if part.startswith("`") else re.sub(r"\s+", " ", part)
                   for part in re.split(r"(`[^`]*`)", kept)).strip()


def bad_comment(text):
    """Whether text holds a `<!--` that is not a well-formed one-line comment."""
    return "<!--" in shown(text)


def items(path, lines, start, end, flat=False):
    """The items of lines[start:end] as (index, text), each item read with its
    wrapped lines, plus an error for each line off the layout. Flat, nothing
    may be indented at all."""
    found, errors = [], []

    def error(i, message):
        errors.append(f"{path}:{i + 1}: {message}")

    def unfenced(i, text):
        """The rules every line outside a code fence keeps. Its code spans pair
        on the line, so reading them line by line reads them as markdown does."""
        if "\\`" in text or "``" in text or text.count("`") % 2:
            error(i, "backticks outside a code fence must pair on their line, singly and unescaped")
        if bad_comment(text):
            error(i, "HTML comment not closed on its line, or malformed; write `<!-- text -->` on one line")
        rendered = shown(text)
        if "__" in rendered:
            error(i, "`__` outside code; write bold as **…**")
        if "\\" in rendered:
            error(i, "backslash outside code; write the text without escapes")
        if re.search(r"&(?:#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);", rendered):
            error(i, "character reference outside code; write the character itself")
        if TAG.search(rendered):
            error(i, "HTML tag outside code; write formatting as markdown")

    for i in range(start, end):
        if "\t" in lines[i]:
            error(i, "tab character; indent with spaces")
    fenced = conventions = False
    blocks = 0
    i = start
    while i < end:
        line = lines[i]
        stripped = line.lstrip(" ")
        indent = len(line) - len(stripped)
        if line == "<!-- repo-conventions -->" and not flat and not fenced:
            conventions = True
            blocks += 1
            if blocks > 1:
                error(i, "second repo-conventions block; keep the one")
        if conventions:
            conventions = line != "<!-- /repo-conventions -->"
            if conventions and re.match(r">[ >]*(?:[-*+]|\d+[.)])\s+\*\*", line):
                error(i, "bold list item in the repo-conventions block; operations are entries outside it")
            if conventions and line != "<!-- repo-conventions -->" and line.strip() and not line.startswith(">"):
                error(i, "line in the repo-conventions block outside its blockquote; start it with `>`")
            i += 1
            continue
        if not fenced and not stripped.startswith(FENCE_START):
            unfenced(i, line)
        if fenced:
            if line == CLOSE_FENCE:
                fenced = False
                if i + 1 < end and needs_blank_before(lines[i + 1]):
                    error(i + 1, "line right after a code fence; leave a blank line before it")
            elif stripped.startswith(FENCE_START):
                error(i, "fence line inside a code fence; close it with exactly two spaces then ```")
            elif line.strip() and indent < 2:
                error(i, "line inside a code fence indented less than two spaces")
        elif (flat and line.strip() and not indent and not MARKER.match(stripped) and i > start
              # A heading, quote, rule or fence here gets its own message below.
              and not HEADING.match(line) and not RULE.fullmatch(line) and not stripped.startswith(FENCE_START + (">",))
              and lines[i - 1].strip() and not MARKER.match(lines[i - 1]) and not HEADING.match(lines[i - 1])
              and not COMMENT.fullmatch(line.strip()) and not COMMENT.fullmatch(lines[i - 1].strip())):
            error(i, "paragraph wrapped onto a second line here; keep each README paragraph on one line")
        elif flat and indent and line.strip():
            error(i, "indented line in the README Platform overrides section; write every line at the margin")
        elif stripped.startswith(FENCE_START):
            if flat:
                error(i, "code fence in the README list; keep it to one line per skill")
            elif OPEN_FENCE.fullmatch(line):
                fenced = True
            else:
                error(i, "code fence not written as two spaces, ``` and an optional language")
        elif indent and HEADING.match(line):
            error(i, "indented heading here; write headings at the margin")
        elif indent and line.strip() and not MARKER.match(stripped):
            error(i, "indented line that is no list item's wrapped line nor in a code fence; keep an item's "
                     "text in one block")
        elif stripped.startswith(">"):
            error(i, "blockquote here; write it as plain text")
        elif RULE.fullmatch(line):
            error(i, "horizontal rule or setext underline here; use an ATX heading, or plain text")
        elif line.startswith("**") and flat:
            error(i, "line starting with bold in the Platform overrides list; start it with plain text, or write "
                     "an item as - `skill`: operation, operation")
        elif line.startswith("**"):
            error(i, "bold name at the margin here; write an operation as an entry, `- **name** — ...`")
        elif not flat and i > start and not MARKER.match(stripped) and (HEADING.match(line) or "|" in shown(line)
                                         or re.search(r"\*\*[^*]+\*\*\S*\s+—", shown(line))):
            error(i, "sub-heading, table row or entry-shaped line in an Operations section; write an operation "
                     "as an entry, `- **name** — ...`")
        elif MARKER.match(stripped) and indent:
            error(i, f"list item indented {indent} spaces; start every item at the margin, "
                     "since lists here do not nest")
        elif MARKER.match(stripped):
            if not line.startswith("- "):
                error(i, "list item not started with `- `")
            elif line[2:3].isspace():
                error(i, "more than one space after the item's `-`; write `- ` then its text")
            j = i + 1
            while j < end and lines[j].startswith("  ") and lines[j].strip():
                wrapped = lines[j].lstrip(" ")
                if (flat or MARKER.match(wrapped) or wrapped.startswith(FENCE_START + (">",))
                        or RULE.fullmatch(lines[j]) or HEADING.match(lines[j])):
                    break
                if len(lines[j]) - len(wrapped) != 2:
                    error(j, f"wrapped line indented {len(lines[j]) - len(wrapped)} spaces; indent it two")
                unfenced(j, wrapped)
                j += 1
            if j < end and needs_blank_before(lines[j]):
                error(j, "line right under a README list item; keep each item on one line, or leave a blank line "
                         "before anything else" if flat
                      else "line right under a list item; indent a wrapped line two spaces, or leave a blank line "
                           "before anything else")
            found.append((i, " ".join(part.strip() for part in lines[i:j])))
            i = j
            continue
        i += 1
    if fenced:
        error(end - 1, "code fence never closed")
    if conventions:
        error(end - 1, "repo-conventions block never closed")
    return found, errors


failed = False
checked = 0
entries = {}
unread = set()  # skills with no `## Operations` heading but another form of one: reported once, skipped below
for path in sorted(glob.glob("skills/*/SKILL.md")):
    lines = open(path, encoding="utf-8").read().split("\n")
    found, setext, contained = headings(lines, OPERATIONS.match, r"Operations\b", r"Operations\b")
    if not found:
        continue
    checked += 1
    if len(found) > 1:
        print(f"error: {path}: more than one `## Operations` section; keep the one", file=sys.stderr)
        failed = True
    if setext:
        print(f"error: {path}:{setext[0] + 1}: Operations heading underlined; write it as `## Operations`",
              file=sys.stderr)
        failed = True
    if contained:
        print(f"error: {path}:{contained[0] + 1}: Operations heading in another form (level, indent, blockquote, "
              "list item, emphasis or HTML); write it as `## Operations` at the margin", file=sys.stderr)
        failed = True
    atx_found = [i for i in found if i not in setext and i not in contained]
    if not atx_found:
        unread.add(path.split("/")[1])
        continue
    start = atx_found[0]
    end = section_end(lines, start)
    names = entries[path.split("/")[1]] = []
    availability = []
    found, errors = items(path, lines, start, end)
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
        failed = True
    for i, text in found:
        # Matched with code spans blanked, so `**` in code ends no name; read back from the text by offset.
        plain = uncommented(text)
        bullet = BULLET.match(prose(plain))
        if bullet:
            name, rest = plain[bullet.start(1):bullet.end(1)], plain[bullet.start(2):]
            if rest.startswith(" —"):
                if name in names:
                    print(f"error: {path}:{i + 1}: Operations entry `{name}` defined twice", file=sys.stderr)
                    failed = True
                elif "," in name:
                    print(f"error: {path}:{i + 1}: Operations entry name `{name}` holds a comma, which "
                          "separates names in the README", file=sys.stderr)
                    failed = True
                else:
                    names.append(name)
                continue
            if rest[:1] in (":", ","):
                # Bold names found with code spans and comments blanked, so `**` there is no name;
                # each read back from the text, so a name may hold code.
                availability.append((i, [text[m.start(1):m.end(1)]
                                         for m in re.finditer(r"\*\*(.+?)\*\*", shown(text))]))
                continue
        print(f"error: {path}:{i + 1}: Operations list item in an unrecognized shape; write an entry as "
              "`- **name** — ...`, or what happens when operations are unavailable as `- **name**: ...` or "
              "`- **name**, **other**: ...`", file=sys.stderr)
        failed = True
    if not names:
        print(f"error: {path}:{start + 1}: Operations section has no `- **name** — ...` entries", file=sys.stderr)
        failed = True
    for i, named in availability:
        for name in named:
            if name not in names:
                print(f"error: {path}:{i + 1}: `{name}` has no `- **{name}** — ...` entry in the Operations section",
                      file=sys.stderr)
                failed = True
    for i, line in enumerate(lines):
        if start <= i < end:
            continue
        match = COMMAND.search(line)
        if match:
            print(f"error: {path}:{i + 1}: `{match.group(1) or match.group(2)}` command outside the Operations section; "
                  "move it there and refer to it by name", file=sys.stderr)
            failed = True

readme = open("README.md", encoding="utf-8").read().split("\n")
found, setext, contained = headings(readme, OVERRIDES.fullmatch, r"Platform overrides[ \t]*$",
                                   r"Platform overrides\b")
start = next((i for i in found if i not in setext and i not in contained), None)
if contained:
    print(f"error: README.md:{contained[0] + 1}: Platform overrides heading in another form (text after the "
          "title, level, indent, blockquote, list item, emphasis or HTML); write it as exactly "
          "`## Platform overrides` at the margin",
          file=sys.stderr)
    failed = True
if len(found) > 1:
    print("error: README.md: more than one `## Platform overrides` section; keep the one", file=sys.stderr)
    failed = True
if start is None:
    print("error: README.md: no `## Platform overrides` section listing each skill's override operations",
          file=sys.stderr)
    sys.exit(1)
end = section_end(readme, start)
listed = {}
found, errors = items("README.md", readme, start, end, flat=True)
for error in errors:
    print(f"error: {error}", file=sys.stderr)
    failed = True
for i, text in found:
    item = re.match(r"^- `([\w-]+)`: (.+)$", uncommented(text))
    if not item:
        print(f"error: README.md:{i + 1}: Platform overrides list item in an unrecognized shape; write it as "
              "- `skill`: operation, operation", file=sys.stderr)
        failed = True
    elif item.group(1) in listed:
        print(f"error: README.md:{i + 1}: Platform overrides lists {item.group(1)} twice", file=sys.stderr)
        failed = True
    else:
        listed[item.group(1)] = [name.strip() for name in item.group(2).split(",")]


# The sentence is read from what renders: a comment's copy of the phrase, or its names, are no part of it.
rendered = [uncommented(line) for line in readme[start:end]]
sentences = [line for line in rendered if SENTENCE in line]
if sum(line.count(SENTENCE) for line in rendered) > 1:
    print("error: README.md: Platform overrides names the skills with an Operations section more than once; keep "
          "one sentence", file=sys.stderr)
    failed = True
intro = sentences[0] if sentences else ""
if SENTENCE in intro and not intro.split(SENTENCE, 1)[1].startswith("**Operations** section."):
    print("error: README.md: the Platform overrides sentence naming the skills must end right after the names, as "
          f"\"{SENTENCE.strip()} **Operations** section.\"", file=sys.stderr)
    failed = True
# The sentence opens its paragraph with the names alone, each as code: nothing else before the phrase, so no
# earlier sentence, link, emphasis or escape can add or hide a name.
lead = intro.split(SENTENCE)[0]
if SENTENCE in intro and not re.fullmatch(r"`[\w-]+`(?:, `[\w-]+`)*(?: and `[\w-]+`)?", lead):
    print("error: README.md: the Platform overrides sentence must open its paragraph with the skills alone, as "
          "`a`, `b` and `c`", file=sys.stderr)
    failed = True
named = sorted(n for n in re.findall(r"`([^`]+)`", lead) if n not in unread)
if named != sorted(entries):
    print("error: README.md: the Platform overrides sentence naming the skills that \"keep every platform command "
          f"in an Operations section\" should name exactly: {', '.join(sorted(entries))}", file=sys.stderr)
    failed = True
for skill, names in entries.items():
    if not names:
        continue
    expected = f"- `{skill}`: {', '.join(names)}"
    if skill not in listed:
        print(f"error: README.md: Platform overrides has no line for {skill}; add: {expected}", file=sys.stderr)
        failed = True
    elif listed[skill] != names:
        print(f"error: README.md: Platform overrides lists other operations for {skill}; expected: {expected}",
              file=sys.stderr)
        failed = True
for skill in sorted(listed.keys() - entries.keys() - unread):
    print(f"error: README.md: Platform overrides lists {skill}, which has no Operations section", file=sys.stderr)
    failed = True
if not failed:
    print(f"no gh or git commands outside the Operations section in {checked} skills, "
          "and README lists each one's operations")
sys.exit(1 if failed else 0)
PY

# Run-time text in a command template is single-quoted or in a quoted heredoc,
# never in double quotes (.claude/CLAUDE.md, Writing skills).
python3 - <<'PY'
import glob
import re
import sys

# A placeholder such as <title> stands for text the skill fills in at run time.
# Inside double quotes, or in the body of an unquoted heredoc, the shell expands
# its backticks and $. Shell fences are read whole, as the shell would (quotes and
# placeholders spanning lines, backslash escapes, comments, heredoc bodies);
# outside them, every inline code span that holds a gh or git command, read as
# one line even when the prose wraps it.
COMMAND = re.compile(r"(?:^|[\s(])(?:git|gh)\s+[a-z]")
PLACEHOLDER = re.compile(r"<[A-Za-z][^<>]*>")
HEREDOC = re.compile(r"(?<!<)<<(?!<)-?[ \t]*(?:'([^'\n]+)'|\"([^\"\n]+)\"|(\\?[A-Za-z0-9_]+))")
FENCE = re.compile(r"[ \t]*(```+|~~~+)[ \t]*([\w-]*)")
SHELL = {"bash", "sh", "shell", "zsh"}


def scan(text):
    """Yield (offset, placeholder, where) for each placeholder the shell would expand."""
    i, n, pending = 0, len(text), []
    while i < n:
        c = text[i]
        if c == "\n":
            i += 1
            for delimiter, quoted in pending:
                end = i
                while end < n:
                    eol = text.find("\n", end)
                    eol = n if eol < 0 else eol
                    if text[end:eol].strip() == delimiter:
                        break
                    end = eol + 1
                if not quoted:
                    for m in PLACEHOLDER.finditer(text, i, min(end, n)):
                        yield m.start(), m.group(0), "an unquoted heredoc"
                eol = text.find("\n", end)
                i = n if eol < 0 else eol + 1
            pending = []
        elif c == "#" and (i == 0 or text[i - 1].isspace()):
            eol = text.find("\n", i)
            i = n if eol < 0 else eol
        elif c == "\\":
            i += 2
        elif c == "'":
            close = text.find("'", i + 1)
            i = n if close < 0 else close + 1
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            for m in PLACEHOLDER.finditer(text, i + 1, min(j, n)):
                yield m.start(), m.group(0), "double quotes"
            i = j + 1
        elif HEREDOC.match(text, i):
            m = HEREDOC.match(text, i)
            word = m.group(3)
            pending.append(((m.group(1) or m.group(2) or word).lstrip("\\"), word is None or word.startswith("\\")))
            i = m.end()
        else:
            i += 1


failed = False
checked = 0
for path in sorted(glob.glob("skills/*/SKILL.md")):
    checked += 1
    lines = open(path, encoding="utf-8").read().split("\n")
    found = []
    prose = list(lines)
    k = 0
    while k < len(lines):
        fence = FENCE.match(lines[k])
        if fence:
            mark = fence.group(1)
            end = next((j for j in range(k + 1, len(lines))
                        if lines[j].strip().startswith(mark) and set(lines[j].strip()) == {mark[0]}), len(lines))
            if fence.group(2) in SHELL:
                text = "\n".join(lines[k + 1:end])
                found += [(k + 2 + text.count("\n", 0, off), p, w) for off, p, w in scan(text)]
            prose[k:end + 1] = [""] * (min(end, len(lines) - 1) + 1 - k)
            k = end + 1
            continue
        k += 1
    text = "\n".join(prose)
    for span in re.finditer(r"`([^`]+)`", text):
        if "\n\n" not in span.group(1) and COMMAND.search(span.group(1)):
            line = text.count("\n", 0, span.start()) + 1
            found += [(line, p, w) for _, p, w in scan(" ".join(span.group(1).split()))]
    found.sort()
    for line, placeholder, where in found:
        print(f"error: {path}:{line}: run-time text {' '.join(placeholder.split())} in {where}; single-quote it, "
              "or pass it on stdin from a quoted heredoc", file=sys.stderr)
        failed = True
if not failed:
    print(f"no run-time text in double quotes or unquoted heredocs in {checked} skills")
sys.exit(1 if failed else 0)
PY

# evals/ ships alongside the plugin but is never loaded at install time, and CI
# never runs the cases (they bill real sessions and need a sandbox), so a broken
# case.yaml would sit undetected until the next by-hand run. Shape-check them here
# — parse only, never run — the way the output-style frontmatter is checked above.
python3 - <<'PY'
import glob
import os
import sys

import yaml

# The grader types `claude plugin eval` accepts (from its own validation
# message: "type: (regex | tool_order | tool_used | file_exists | llm |
# baseline)"). Reject only a type the framework itself would reject, so a
# valid future case is never failed here; widen this if the CLI gains one.
GRADER_TYPES = {"regex", "tool_order", "tool_used", "file_exists", "llm", "baseline"}

failed = False
for path in sorted(glob.glob("evals/**/case.yaml", recursive=True)):
    case_dir = os.path.dirname(path)
    try:
        case = yaml.safe_load(open(path, encoding="utf-8"))
    except (OSError, UnicodeDecodeError, yaml.YAMLError) as e:
        print(f"error: {path}: failed to parse: {e}", file=sys.stderr)
        failed = True
        continue
    problems = []
    if not isinstance(case, dict):
        problems.append("is not a YAML mapping")
        case = {}
    if not isinstance(case.get("name"), str) or not case["name"].strip():
        problems.append("needs a non-empty 'name'")
    # A prompt may live inline or in a sibling prompt.md — the framework accepts
    # either ("execution.prompt is required: a prompt.md body, or execution.prompt
    # in case.yaml"), so requiring the inline form would fail a valid split case.
    execution = case.get("execution")
    prompt = execution.get("prompt") if isinstance(execution, dict) else None
    if not (isinstance(prompt, str) and prompt.strip()) \
            and not os.path.isfile(os.path.join(case_dir, "prompt.md")):
        problems.append("needs execution.prompt or a sibling prompt.md")
    # Likewise graders may be an inline list or a sibling graders/*.md directory.
    graders = case.get("graders")
    inline = graders if isinstance(graders, list) else []
    graders_dir = os.path.join(case_dir, "graders")
    has_graders_dir = os.path.isdir(graders_dir) and any(
        name.endswith(".md") for name in os.listdir(graders_dir))
    if not inline and not has_graders_dir:
        problems.append("needs a non-empty 'graders' list or sibling graders/*.md files")
    for i, grader in enumerate(inline):
        where = f"graders[{i}]"
        if not isinstance(grader, dict):
            problems.append(f"{where} is not a mapping")
            continue
        if not isinstance(grader.get("name"), str) or not grader["name"].strip():
            problems.append(f"{where} needs a non-empty 'name'")
        gtype = grader.get("type")
        if gtype not in GRADER_TYPES:
            problems.append(f"{where} has type {gtype!r}, not one of {sorted(GRADER_TYPES)}")
    context = case.get("context")
    if isinstance(context, dict) and "scaffold_script" in context:
        script = context["scaffold_script"]
        if not isinstance(script, str) or not script.strip():
            problems.append("context.scaffold_script is empty")
        elif not os.path.isfile(os.path.join(case_dir, script)):
            problems.append(f"context.scaffold_script '{script}' names no existing file")
    for problem in problems:
        print(f"error: {path}: {problem}", file=sys.stderr)
    failed = failed or bool(problems)
    if not problems:
        print(f"{path}: case ok")
sys.exit(1 if failed else 0)
PY

base="${1:-}"
[ -z "$base" ] && exit 0
if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  echo "error: base ref '$base' not found. Fetch it first (git fetch origin main)." >&2
  exit 1
fi

# Claude Code compares plugin.json's version, not the git commit, so a change to
# what the plugin ships without a higher version never reaches existing installs.
# Both sides come from commits, so uncommitted work can't pass here and fail in CI.
# What changed is measured from the fork point; the version to beat is the base
# tip's, which is what CI's merge checkout sees once the base has moved on.
shipped=(skills output-styles .claude-plugin/plugin.json)
fork_point="$(git merge-base "$base" HEAD)"
if git diff --quiet "$fork_point" HEAD -- "${shipped[@]}"; then
  echo "${shipped[*]} unchanged since $base: no version bump needed."
  exit 0
fi
python3 - "$base" <<'PY'
import json
import subprocess
import sys

def version(commit):
    manifest = subprocess.run(["git", "show", f"{commit}:.claude-plugin/plugin.json"],
                              capture_output=True, text=True, check=True).stdout
    raw = json.loads(manifest)["version"]
    try:
        return raw, tuple(int(part) for part in raw.split("."))
    except ValueError:
        sys.exit(f"error: plugin.json version '{raw}' is not dotted numbers")

(old, old_key), (new, new_key) = version(sys.argv[1]), version("HEAD")
if new_key <= old_key:
    sys.exit(f"error: what the plugin ships changed but .claude-plugin/plugin.json version went {old} -> {new}.\n"
             "Raise it: Claude Code compares that field, so a change without a higher version never reaches existing installs.")
print(f"plugin.json version bumped: {old} -> {new}")
PY

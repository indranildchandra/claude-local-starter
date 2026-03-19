# Personal Info — ppt-creator

Fill in your details here. The skill reads this file at GENERATE time to
auto-populate title slides, close slides, and speaker attribution blocks.
Every deck gets these defaults unless overridden at generation time.

---

## Speaker

```yaml
name:        ""           # passed by the user at generation time
title:       ""           # passed by the user at generation time

# Additional titles shown on intro/close slides (pick one per deck context)
other_titles:
  - ""
  - ""
  - ""

website:     ""           # optional — leave blank to omit
email:       ""           # optional — leave blank to omit
linkedin:    ""           # optional — e.g. "linkedin.com/in/yourname"
github:      ""           # optional — e.g. "github.com/yourhandle"
```

---

## QR Codes

```yaml
# Personal website QR — embedded on title and close slides by default, can be passed at generation time as well
# Set via: /create-ppt --repo-qr /path/to/qr.png
website_qr:  ""

# Repo / talk-specific QR — passed at generation time, not stored here
# Set via: /create-ppt --repo-qr /path/to/qr.png
repo_qr:     ""
```

---

## Slide Defaults

```yaml
# Default event/context line shown on title slides
# Overridden at generation time when user specifies the event
default_event:   ""         # e.g. "DevFest Mumbai"
default_year:    "2026"

# Accent pill color on all orange slides (white by default — do not change)
accent_color:    "FFFFFF"

# Whether to auto-embed website_qr on close slides
auto_qr_close:   true

# Whether to add slideNum on every slide
slide_numbers:   true
```

---

## Usage in GENERATE

At the start of GENERATE, Claude reads this file and substitutes values
into every slide function. The boilerplate already includes the read command:

```bash
cat ~/.claude/skills/ppt-creator/personal-info.md
```

**Title slide substitutions:**
- `SPEAKER_NAME` → `name`
- `SPEAKER_TITLE` → `title` (include `other_titles` if user confirms)
- `SPEAKER_WEBSITE` → `website` (include only if provided by the user)
- `QR_PATH` → `website_qr` (absolute path, expand `~`)
- `EVENT_LINE` → `default_event  ·  default_year` (or user-specified)

**Close slide substitutions:**
- Speaker attribution line: `name  ·  website`
- QR code: `website_qr` if `auto_qr_close: true`

**Overriding at generation time:**
The user can say "use Principal Architect as the title for this deck" or
"don't include the QR code on the close slide" — these override the defaults
above without editing this file.

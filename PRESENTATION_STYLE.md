# Presentation Style Guide

Template file: `aaa.pptx` (same directory as this file)
Generator script: `make_pptx.py` (same directory — use as reference implementation)
Tool: `python3` + `python-pptx`  (`pip install python-pptx --break-system-packages`)

---

## Slide Dimensions

| Property | Value |
|---|---|
| Width | 13.33 inches |
| Height | 7.50 inches |
| Aspect ratio | 16:9 widescreen |

---

## Available Layouts

Open `aaa.pptx` as the template. All layouts come from its master.

| Index | Name | Use for |
|---|---|---|
| `[0]` | Title Slide | (not used — use Cover instead) |
| `[6]` | Blank | Blank slide |
| `[11]` | **Cover** | First slide of the presentation |
| `[12]` | **Agenda** | Agenda / table of contents |
| `[13]` | **Section Title_1** | Section divider between topics |
| `[14]` | **Content_A-1** | Main content slide (title + subtitle + body) |
| `[15]` | Final | Last slide |

---

## Layout Placeholders

### Layout [11] — Cover
| Placeholder idx | Type | Position (in) | Size (in) | Use for |
|---|---|---|---|---|
| `0` | CENTER_TITLE | (5.76, 2.77) | 7.12 × 1.94 | Presentation title |
| `13` | BODY | (5.76, 5.12) | 5.80 × 0.46 | Author name |
| `14` | BODY | (5.76, 5.57) | 5.80 × 0.69 | Role / job title |
| `15` | BODY | (5.76, 6.33) | 4.23 × 0.29 | Date |

### Layout [13] — Section Title_1
| Placeholder idx | Type | Position (in) | Size (in) | Use for |
|---|---|---|---|---|
| `0` | TITLE | (0.68, 3.45) | 8.79 × 0.59 | Section title (centered vertically on slide) |

### Layout [14] — Content_A-1
| Placeholder idx | Type | Position (in) | Size (in) | Use for |
|---|---|---|---|---|
| `0` | TITLE | (0.57, 0.14) | 12.47 × 0.57 | Slide title (top bar) |
| `11` | BODY | (0.57, 1.17) | 12.40 × 0.53 | Subtitle / section label |
| `12` | OBJECT | (0.57, 2.39) | 12.19 × 4.14 | Main content: bullets or image |

---

## Python Script Pattern

```python
import os
from pptx import Presentation
from pptx.util import Inches, Pt

DIR      = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(DIR, 'aaa.pptx')
OUTPUT   = os.path.join(DIR, 'MyPresentation.pptx')

prs    = Presentation(TEMPLATE)
N_ORIG = len(prs.slides)          # remember count before adding new slides

COVER   = prs.slide_layouts[11]
SECTION = prs.slide_layouts[13]
CONTENT = prs.slide_layouts[14]
```

---

## Helper Functions (copy these verbatim)

```python
def phs(slide):
    """Return dict of {placeholder_idx: placeholder} for a slide."""
    return {ph.placeholder_format.idx: ph for ph in slide.placeholders}

def set_text(ph, text):
    tf = ph.text_frame
    tf.clear()
    tf.paragraphs[0].text = text

def add_bullets(ph, items):
    """
    items: list of str (level 0) or (str, level) tuples.
    level 0 = main bullet, level 1 = sub-bullet, level 2 = sub-sub-bullet.
    """
    tf = ph.text_frame
    tf.clear()
    tf.word_wrap = True
    first = True
    for item in items:
        text  = item if isinstance(item, str) else item[0]
        level = 0    if isinstance(item, str) else item[1]
        p = tf.paragraphs[0] if first else tf.add_paragraph()
        p.text  = text
        p.level = level
        first   = False
```

---

## Slide Type Functions

### Cover slide
```python
def cover(prs, title, name, role, date):
    s = prs.slides.add_slide(COVER)
    p = phs(s)
    set_text(p[0],  title)   # presentation title
    set_text(p[13], name)    # author name
    set_text(p[14], role)    # job title
    set_text(p[15], date)    # date string

# Example:
cover(prs, "My System\nArchitecture", "Abdullah AlMusalami", "Senior Robotics Engineer", "May 2026")
```

### Section divider
```python
def section(prs, title):
    s = prs.slides.add_slide(SECTION)
    set_text(phs(s)[0], title)

# Example:
section(prs, "Phase 1  ·  Docker Environment")
```

### Content slide — bullets
```python
def content_bullets(prs, title, subtitle, bullets):
    s = prs.slides.add_slide(CONTENT)
    p = phs(s)
    set_text(p[0],  title)
    set_text(p[11], subtitle)
    add_bullets(p[12], bullets)

# Example:
content_bullets(prs,
    "Phase 1  ·  Docker Environment",
    "Environment Setup",
    [
        "Base image: nvidia/cuda:13.2 + Ubuntu 22.04",
        "ROS2 Jazzy Desktop",
        ("GPU passthrough:  --gpus all", 1),    # sub-bullet
    ]
)
```

### Content slide — full-width image (wide diagrams)
```python
def content_image_wide(prs, title, subtitle, image_path):
    """Fits image to the full width of the content area."""
    s = prs.slides.add_slide(CONTENT)
    p = phs(s)
    set_text(p[0],  title)
    set_text(p[11], subtitle)
    s.shapes.add_picture(image_path, Inches(0.57), Inches(2.39), width=Inches(12.19))

# Example:
content_image_wide(prs,
    "GLIM Map Building Automation System",
    "3-Phase System Architecture",
    "/path/to/minimal_diagram.png"
)
```

### Content slide — centered image (tall diagrams)
```python
def content_image_tall(prs, title, subtitle, image_path):
    """Fits image to the full height of the content area, centered horizontally."""
    s  = prs.slides.add_slide(CONTENT)
    p  = phs(s)
    set_text(p[0],  title)
    set_text(p[11], subtitle)
    pic = s.shapes.add_picture(image_path, Inches(0.57), Inches(2.39), height=Inches(4.14))
    pic.left = int((Inches(13.33) - pic.width) / 2)   # centre horizontally

# Example:
content_image_tall(prs,
    "Phase 2  ·  CLI Wizard",
    "Full Pipeline Diagram",
    "/path/to/full_diagram.png"
)
```

---

## Removing Template Slides

After adding all new slides, remove the original template slides:

```python
REL_NS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'

def delete_slide(prs, idx):
    sld_id_lst = prs.slides._sldIdLst
    sId  = sld_id_lst[idx]
    rId  = sId.get(f'{{{REL_NS}}}id')
    sld_id_lst.remove(sId)
    try:
        prs.part.drop_rel(rId)
    except Exception:
        pass

# Delete all original slides in reverse order
for i in range(N_ORIG - 1, -1, -1):
    delete_slide(prs, i)
```

---

## Save

```python
prs.save(OUTPUT)
print(f"Saved: {OUTPUT}  ({len(prs.slides)} slides)")
```

---

## Bullet Level Examples

```python
bullets = [
    "Top-level bullet (level 0)",                        # str → level 0
    ("Sub-bullet (level 1)", 1),                         # tuple → level 1
    ("Sub-sub-bullet (level 2)", 2),                     # tuple → level 2
    "Another top-level bullet",
    ("Another sub-bullet", 1),
]
```

---

## Complete Minimal Example

```python
#!/usr/bin/env python3
import os
from pptx import Presentation
from pptx.util import Inches

DIR      = '/path/to/system_diagram'
prs      = Presentation(os.path.join(DIR, 'aaa.pptx'))
N_ORIG   = len(prs.slides)
COVER    = prs.slide_layouts[11]
SECTION  = prs.slide_layouts[13]
CONTENT  = prs.slide_layouts[14]

def phs(s):   return {ph.placeholder_format.idx: ph for ph in s.placeholders}
def st(ph, t): ph.text_frame.clear(); ph.text_frame.paragraphs[0].text = t

# Cover
s = prs.slides.add_slide(COVER);   p = phs(s)
st(p[0], "My Presentation"); st(p[13], "Name"); st(p[14], "Role"); st(p[15], "Date")

# Section
s = prs.slides.add_slide(SECTION); st(phs(s)[0], "Section Title")

# Content
s = prs.slides.add_slide(CONTENT); p = phs(s)
st(p[0], "Slide Title"); st(p[11], "Subtitle")
tf = p[12].text_frame; tf.clear()
tf.paragraphs[0].text = "Bullet 1"
para = tf.add_paragraph(); para.text = "Sub-bullet"; para.level = 1

# Remove originals
REL = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
def del_slide(prs, i):
    lst = prs.slides._sldIdLst; sId = lst[i]
    rId = sId.get(f'{{{REL}}}id'); lst.remove(sId)
    try: prs.part.drop_rel(rId)
    except: pass

for i in range(N_ORIG - 1, -1, -1): del_slide(prs, i)

prs.save(os.path.join(DIR, 'output.pptx'))
```

// ─────────────────────────────────────────────────────────────────────────────
// PERSONAL DECK BOILERPLATE
// All constants from personal design system (RAG Done Right Production.pptx).
// Do not modify C, shadow factories, or any primitive function.
// Add slide functions after the BUILD SECTION marker.
//
// Rules:
// - fontFace: "Arial" on every addText() call — no exceptions
// - accent(s) called FIRST on every DS() and OS() slide
// - Shadow factories called INLINE: shadow: mks() — never store and reuse
// - Never reuse option objects across addShape/addText calls (pptxgenjs mutates)
// - lineSpacingMultiple: 1.15 on all body text with h > 0.30
// - No C.textMid on dark/orange slides — use C.textBody or C.textMuted
// ─────────────────────────────────────────────────────────────────────────────

"use strict";
const pptxgen = require("pptxgenjs");
const path    = require("path");

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9";   // 10" × 5.625"
pres.title  = "Presentation Title";

// ─── Colour palette ───────────────────────────────────────────────────────────
const C = {
  // Slide backgrounds
  darkBg:      "282828",   // charcoal — dark content slides
  lightBg:     "F2F2F2",   // near-white — framework / evidence slides
  orangeBg:    "E84000",   // vivid orange-red — intro, section, close slides

  // Card surfaces (on dark slides only)
  cardDark:    "3A3A3A",
  cardDeep:    "2A2A2A",

  // Accent / semantic colors
  orange:      "E84000",   // primary brand — tags, accents, nrow stripe
  teal:        "00B4C8",   // technical layer — code banners, callout borders, architecture labels
  amber:       "E8A000",   // neutral/cautionary metric — partial progress, cost context
  green:       "27AE60",
  lightGreen:  "4ADE80",
  blue:        "2980B9",
  lightBlue:   "7DD3FC",
  purple:      "9B59B6",
  yellow:      "FFC000",
  red:         "CC2222",
  lightRed:    "FF6666",

  // Text
  textOnDark:  "FFFFFF",   // primary on dark/orange bg
  textBody:    "AAAAAA",   // secondary on dark bg
  textMuted:   "888888",   // captions/footnotes on dark bg
  textDark:    "1A1A1A",   // primary on light bg
  textMid:     "555555",   // secondary on light bg — LIGHT SLIDES ONLY
  textCaption: "777777",   // captions on light bg
};

// ─── Shadow factories — call inline, NEVER reuse ──────────────────────────────
const mks  = () => ({ type: "outer", blur: 6,  offset: 2, angle: 135, color: "000000", opacity: 0.28 });
const mksl = () => ({ type: "outer", blur: 14, offset: 3, angle: 135, color: "000000", opacity: 0.45 });

// ─── Slide factories ──────────────────────────────────────────────────────────
const DS = () => { const s = pres.addSlide(); s.background = { color: C.darkBg   }; return s; };
const LS = () => { const s = pres.addSlide(); s.background = { color: C.lightBg  }; return s; };
const OS = () => { const s = pres.addSlide(); s.background = { color: C.orangeBg }; return s; };

// ─── Primitives ───────────────────────────────────────────────────────────────

// Horizontal rule — h MUST be 0 (LINE shape)
const hr = (s, y, x = 0.4, w = 9.2, c = C.textOnDark) => {
  s.addShape(pres.shapes.LINE, { x, y, w, h: 0, line: { color: c, width: 0.75 } });
};

// Accent pill — call FIRST on every DS() and OS() slide
function accent(s, c = C.textOnDark) {
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 0.3, w: 0.55, h: 0.08,
    fill: { color: c }, line: { color: c }
  });
}

// Dark-slide title + optional subtitle
function dt(s, title, sub) {
  s.addText(title, {
    x: 0.4, y: 0.22, w: 9.2, h: 0.62,
    fontSize: 26, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  if (sub) s.addText(sub, {
    x: 0.4, y: 0.88, w: 9.2, h: 0.28,
    fontSize: 12, color: C.textBody, fontFace: "Arial", margin: 0
  });
}

// Light-slide title + optional subtitle
function lt(s, title, sub) {
  s.addText(title, {
    x: 0.4, y: 0.65, w: 9.2, h: 0.7,
    fontSize: 34, bold: true, color: C.textDark, fontFace: "Arial", margin: 0
  });
  if (sub) s.addText(sub, {
    x: 0.4, y: 1.38, w: 9.2, h: 0.3,
    fontSize: 13, color: C.textMid, fontFace: "Arial", margin: 0
  });
}

// Numbered technique row — DS() slides
function nrow(s, num, title, body, metric, mc, y, h = 1.15) {
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.3, y, w: 9.4, h,
    fill: { color: C.cardDark }, line: { color: C.cardDark }, shadow: mks()
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.3, y, w: 0.07, h,
    fill: { color: C.orange }, line: { color: C.orange }
  });
  s.addText(num, {
    x: 0.5, y: y+0.12, w: 0.65, h: 0.42,
    fontSize: 24, bold: true, color: C.orange, fontFace: "Arial", margin: 0
  });
  s.addText(title, {
    x: 1.25, y: y+0.08, w: 5.9, h: 0.36,
    fontSize: 15, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText(body, {
    x: 1.25, y: y+0.48, w: 5.9, h: h-0.58,
    fontSize: 11, color: C.textBody, fontFace: "Arial", margin: 0, lineSpacingMultiple: 1.15
  });
  if (metric) s.addText(metric, {
    x: 7.4, y: y+0.15, w: 2.2, h: h-0.3,
    fontSize: 12, bold: true, color: mc || C.lightGreen,
    fontFace: "Arial", align: "right", margin: 0
  });
}

// Two-panel card frame with colored left stripe
function card(s, x, y, w, h, ac) {
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h,
    fill: { color: C.cardDark }, line: { color: ac, width: 1.5 }, shadow: mksl()
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w: 0.07, h,
    fill: { color: ac }, line: { color: ac }
  });
}

// Card title — call immediately after card()
function ctitle(s, x, y, w, txt, c) {
  s.addText(txt, {
    x: x+0.14, y: y+0.13, w: w-0.22, h: 0.34,
    fontSize: 13, bold: true, color: c, fontFace: "Arial", margin: 0
  });
}

// Orange label tag — LS() slides
function tag(s, txt, x = 0.4, y = 0.2, w = 2.0) {
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h: 0.33,
    fill: { color: C.orange }, line: { color: C.orange }
  });
  s.addText(txt, {
    x: x+0.04, y: y+0.03, w: w-0.08, h: 0.27,
    fontSize: 11, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
}

// Slide number — bottom-right
function slideNum(s, n) {
  s.addText(String(n), {
    x: 9.25, y: 5.09, w: 0.60, h: 0.43,
    fontSize: 10, fontFace: "Arial",
    color: C.textOnDark, align: "right", valign: "middle", margin: 0
  });
}

// Source footnote
function sourceFootnote(s, citations, onDark) {
  if (!citations || citations.length === 0) return;
  const col = onDark ? C.textMuted : C.textCaption;
  if (citations.length === 1) {
    s.addText(citations[0], {
      x: 0.4, y: 4.85, w: 9.2, h: 0.22,
      fontSize: 8, fontFace: "Arial", color: col, valign: "middle", margin: 0
    });
  } else {
    s.addText(citations[0], {
      x: 0.4, y: 4.72, w: 9.2, h: 0.16,
      fontSize: 7.5, fontFace: "Arial", color: col, valign: "middle", margin: 0
    });
    s.addText(citations.slice(1).join("   "), {
      x: 0.4, y: 4.89, w: 9.2, h: 0.16,
      fontSize: 7.5, fontFace: "Arial", color: col, valign: "middle", margin: 0
    });
  }
}

// Speaker brand mark — footer of every DS() and LS() body slide (skip OS())
// Pass website from personal-info.md; omit call entirely if website is blank
function speakerMark(s, website) {
  if (!website) return;
  s.addText(website, {
    x: 0.3, y: 5.09, w: 5.0, h: 0.35,
    fontSize: 8, fontFace: "Arial", color: C.textMuted,
    valign: "middle", margin: 0
  });
}

// Light-background card with left accent stripe (LS() slides — RAG deck slide 7 pattern)
function lCardLeft(s, x, y, w, h, ac) {
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h,
    fill: { color: "EBEBEB" }, line: { color: "D0D0D0", width: 0.75 }, shadow: mks()
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x, y, w: 0.05, h,
    fill: { color: ac }, line: { color: ac }
  });
}

// Full orange section slide — returns slide for slideNum + addNotes
function sectionSlide(num, title, subtitle) {
  const s = OS();
  accent(s, C.textOnDark);
  hr(s, 0.55);
  s.addText(num, {
    x: 0.3, y: 1.35, w: 3.9, h: 2.6,
    fontSize: 160, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0, align: "right"
  });
  s.addShape(pres.shapes.LINE, {
    x: 4.65, y: 1.2, w: 0, h: 3.2,
    line: { color: C.textOnDark, width: 1.5 }
  });
  s.addText(title, {
    x: 4.9, y: 1.6, w: 4.8, h: 1.1,
    fontSize: 44, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText(subtitle, {
    x: 4.9, y: 2.85, w: 4.8, h: 0.9,
    fontSize: 20, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  hr(s, 5.15);
  return s;
}

// ─── BUILD SECTION — add slide functions below ────────────────────────────────
// Naming convention: s01_role(), s02_role(), ...
// Each function creates one slide.

function s01_title() {
  const s = OS();
  accent(s, C.textOnDark);
  hr(s, 0.55, 0.4, 5.8);
  s.addText("Talk Title", {
    x: 0.4, y: 0.85, w: 9.0, h: 1.3,
    fontSize: 72, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Subtitle", {
    x: 0.4, y: 2.05, w: 8.5, h: 0.9,
    fontSize: 52, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  hr(s, 3.75, 0.4, 5.6);
  s.addText("Speaker Name", {
    x: 0.4, y: 3.88, w: 5.5, h: 0.45,
    fontSize: 22, bold: true, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Role  ·  website.com", {
    x: 0.4, y: 4.33, w: 5.5, h: 0.3,
    fontSize: 15, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  s.addText("Event  ·  Year", {
    x: 0.4, y: 4.72, w: 5.5, h: 0.28,
    fontSize: 13, color: C.textOnDark, fontFace: "Arial", margin: 0
  });
  slideNum(s, 1);
  s.addNotes("KEY STAT: [Hook number]\n\nTALKING POINTS:\n• ...");
}

// ─── EXECUTE ──────────────────────────────────────────────────────────────────
s01_title();
// s02_..., s03_..., etc.

pres.writeFile({ fileName: "presentation.pptx" })
  .then(() => console.log("Done — presentation.pptx"))
  .catch(e => { console.error(e); process.exit(1); });

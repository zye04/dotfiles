.pragma library

// Markdown -> Qt rich text, laid out like Claude Code: bold-only headings, hanging-indented
// lists whose nested items sit under the parent's text, one blank line between blocks.
// o: { cw: character width, gap: one line height, code, link, dim, rule: colours }

const BULLETS = ["•", "◦", "▪"];
const NB = "&nbsp;";

function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function inline(text, o) {
    const codes = [];
    let s = text.replace(/(`+)([\s\S]*?[^`])\1(?!`)/g, (m, tick, body) => {
        codes.push(`<span style="color:${o.code}">${esc(body.replace(/^ (.*) $/, "$1"))}</span>`);
        return `\u0001${codes.length - 1}\u0001`;
    });
    s = esc(s);
    s = s.replace(/!\[([^\]]*)\]\(([^)\s]+)\)|\[([^\]]+)\]\(([^)\s]+)\)|\*\*(.+?)\*\*|__(.+?)__|(^|[^*\w])\*([^*\s][^*]*?)\*(?![*\w])|~~(.+?)~~|(https?:\/\/[^\s<)]+)/g,
        (m, imgAlt, imgSrc, linkText, linkUrl, b1, b2, itPre, it, st, bare) => {
            if (imgSrc) return `<img src="${imgSrc}">`;
            if (linkUrl) return `<a href="${linkUrl}" style="color:${o.link}; text-decoration:none">${linkText}</a>`;
            if (b1 || b2) return `<b>${b1 || b2}</b>`;
            if (it) return `${itPre}<i>${it}</i>`;
            if (st) return `<s>${st}</s>`;
            return `<a href="${bare}" style="color:${o.link}; text-decoration:none">${bare}</a>`;
        });
    return s.replace(/\u0001(\d+)\u0001/g, (m, i) => codes[+i]);
}

const LIST_RE = /^(\s*)([-*+•]|\d+[.)])(\s+)(.*)$/;
const HR_RE = /^\s*([-*_])(\s*\1){2,}\s*$/;
const TABLE_SEP_RE = /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/;

function splitRow(line) {
    let t = line.trim();
    if (t.startsWith("|")) t = t.slice(1);
    if (t.endsWith("|") && !t.endsWith("\\|")) t = t.slice(0, -1);
    const cells = [];
    let cur = "";
    for (let k = 0; k < t.length; k++) {
        if (t[k] === "\\" && t[k + 1] === "|") { cur += "|"; k++; }
        else if (t[k] === "|") { cells.push(cur.trim()); cur = ""; }
        else cur += t[k];
    }
    cells.push(cur.trim());
    return cells;
}

function indentOf(line) {
    return line.match(/^[ \t]*/)[0].replace(/\t/g, "    ").length;
}

// Returns { html, stack }; stack = open list items [{src, col}] at the end of the text.
function render(text, o, initStack) {
    const lines = (text || "").replace(/\s+$/, "").split("\n");
    const out = [];
    let stack = (initStack || []).slice();
    let prev = ""; // kind of the previous block: "", "item", "other"
    let topOrdered = null; // whether the last top-level list item was numbered
    const gapTop = kind => (prev !== "" && !(kind === "item" && prev === "item")) ? o.gap : 0;
    const p = (html, kind, left, indent) => {
        out.push(`<p style="margin-top:${gapTop(kind)}px; margin-bottom:0; margin-left:${left}px; text-indent:${indent}px">${html}</p>`);
        prev = kind;
    };

    for (let i = 0; i < lines.length; ) {
        const line = lines[i];
        if (!line.trim()) { i++; continue; }

        // Table
        if (line.includes("|") && i + 1 < lines.length && TABLE_SEP_RE.test(lines[i + 1]) && lines[i + 1].includes("-")) {
            const head = splitRow(line);
            const rows = [];
            i += 2;
            while (i < lines.length && lines[i].includes("|") && lines[i].trim()) rows.push(splitRow(lines[i++]));
            const n = head.length;
            const cell = (c, bold) => `<td align="left">${bold ? "<b>" : ""}${inline(c ?? "", o)}${bold ? "</b>" : ""}</td>`;
            let html = `<table border="1" cellspacing="0" cellpadding="4" style="border-collapse:collapse; border-color:${o.rule}; border-brush:${o.rule}; margin-top:${gapTop("other")}px">`;
            html += `<tr>${head.map(c => cell(c, true)).join("")}</tr>`;
            for (const r of rows) html += `<tr>${Array.from({ length: n }, (_, k) => cell(r[k], false)).join("")}</tr>`;
            out.push(html + "</table>");
            prev = "other";
            stack = [];
            continue;
        }

        if (HR_RE.test(line)) {
            out.push(`<p style="margin-top:${gapTop("other")}px; margin-bottom:0; color:${o.dim}">${"─".repeat(24)}</p>`);
            prev = "other"; stack = []; i++; continue;
        }

        const h = line.match(/^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$/);
        if (h) { p(`<b>${inline(h[1], o)}</b>`, "other", 0, 0); stack = []; i++; continue; }

        const q = line.match(/^\s*>\s?(.*)$/);
        if (q) {
            const buf = [];
            while (i < lines.length && /^\s*>/.test(lines[i])) buf.push(lines[i++].replace(/^\s*>\s?/, ""));
            p(`<span style="color:${o.dim}">▎${NB}${inline(buf.join(" "), o)}</span>`, "other", 0, 0);
            stack = [];
            continue;
        }

        const li = line.match(LIST_RE);
        if (li) {
            const src = indentOf(li[1]);
            while (stack.length && stack[stack.length - 1].src >= src) stack.pop();
            const col = stack.length ? stack[stack.length - 1].col : 0;
            const marker = /\d/.test(li[2]) ? li[2] : BULLETS[stack.length % BULLETS.length];
            const hang = marker.length + 1;
            if (!stack.length) {
                const ordered = /\d/.test(li[2]);
                if (prev === "item" && topOrdered !== null && ordered !== topOrdered) prev = "other"; // a different list starts
                topOrdered = ordered;
            }
            stack.push({ src, col: col + hang, sc: src + li[2].length + li[3].length });
            let body = li[4];
            i++;
            // soft-wrapped continuation lines
            while (i < lines.length && lines[i].trim() && !LIST_RE.test(lines[i]) && !/^\s*```/.test(lines[i]) && !HR_RE.test(lines[i]) && indentOf(lines[i]) > src)
                body += " " + lines[i++].trim();
            p(`${marker}${NB}${inline(body, o)}`, "item", (col + hang) * o.cw, -hang * o.cw);
            continue;
        }

        // Paragraph (or continuation block of the open list item when indented)
        const ind = indentOf(line);
        const buf = [];
        while (i < lines.length && lines[i].trim() && !LIST_RE.test(lines[i]) && !HR_RE.test(lines[i]) && !/^\s{0,3}#{1,6}\s/.test(lines[i]) && !/^\s*>/.test(lines[i])
               && !(lines[i].includes("|") && i + 1 < lines.length && TABLE_SEP_RE.test(lines[i + 1]) && lines[i + 1].includes("-")))
            buf.push(lines[i++].trim().replace(/ {2,}$/, ""));
        if (!buf.length) { buf.push(lines[i++].trim()); }
        const inItem = stack.length > 0 && ind > 0;
        if (!inItem) stack = [];
        p(inline(buf.join(" "), o), "other", inItem ? stack[stack.length - 1].col * o.cw : 0, 0);
    }
    return { html: out.join(""), stack };
}

const DUMMY = { cw: 1, gap: 0, code: "", link: "", dim: "", rule: "" };

// Index in `stack` of the list item a fence indented `fenceIndent` belongs to (the deepest
// item whose content column it reaches), or -1 for a top-level fence.
function attachIndex(stack, fenceIndent) {
    let k = -1;
    for (let i = 0; i < stack.length; i++) if (stack[i].sc <= fenceIndent) k = i;
    return k;
}

// For block `i` of splitMarkdownBlocks output: the open list items just before it and, for a
// code block, the column it sits at. The list context carries across fences.
function context(blocks, i) {
    let stack = [];
    for (let j = 0; j < i; j++) {
        const b = blocks[j];
        if (b.type === "text") stack = render(b.content, DUMMY, stack).stack;
        else if (b.type === "code") {
            const k = attachIndex(stack, b.indent || 0);
            stack = k < 0 ? [] : stack.slice(0, k + 1);
        }
    }
    const b = blocks[i];
    const k = b && b.type === "code" ? attachIndex(stack, b.indent || 0) : -1;
    return { stack, col: k < 0 ? 0 : stack[k].col };
}

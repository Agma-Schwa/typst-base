// ============================================================================
//  Dependencies
// ============================================================================
#import "@preview/rowmantic:0.5.0" : rowtable, expandcell

// ============================================================================
//  Overrides of builtin functions.
// ============================================================================
// Smallcaps should ignore italics.
#let __smallcaps = smallcaps
#let smallcaps(..args) = text(style: "normal", __smallcaps(..args))

// ============================================================================
//  Constants and Helper Functions
// ============================================================================
#let small-size = 11pt
#let normalfont-size = 12pt
#let large-size = 18pt
#let Large-size = 22pt
#let huge-size = 30pt
#let subsection-size = 14pt
#let section-size = 16pt
#let __compact-chapter-size = 20pt
#let __chapter-size = 30pt
#let list-sep = $diamond.stroked.small$

// These values were calibrated for the current font by checking how many
// lines LaTeX can fit on a page using the same font and page size and then
// adjusting these until Typst can fit the same number of lines; this is
// because there is no good one-to-one mapping (that I know of) between how
// these values are specified in LaTeX and Typst. These values are probably
// font-dependent (at least the default line height usually is) and may
// require recalibration whenever the font is changed.
#let par-first-line-indent = 1.5em
#let par-spacing = .56em
#let par-leading = .56em

#let small(x) = text(small-size, [#x])
#let nf(x) = text(normalfont-size, weight: "regular", style: "normal", [#x])
#let large(x) = text(large-size, [#x])
#let Large(x) = text(Large-size, [#x])
#let huge(x) = text(huge-size, [#x])
#let cell = table.cell
#let remove-whitespace-before() = h(0pt, weak: true)
#let s = smallcaps
#let b = strong
#let llap(x) = box(width: 0pt, [#h(-100cm)#h(1fr)#x])
#let rlap(x) = box(width: 0pt, [#x#h(1fr)#h(-100cm)])
#let vline = table.vline()
#let hline = table.hline()
#let vlineat(x, ..rest) = table.vline(x: x, ..rest)
#let hlineat(y, ..rest) = table.hline(y: y, ..rest)
#let vlinesat(..x) = x.pos().map(vlineat)
#let hlinesat(..y) = y.pos().map(hlineat)
#let cc(x) = align(center + horizon)[#x]
#let fill = h(1fr)
#let smallskip = v(.5em)
#let medskip = v(1em)
#let en = hide[x] // en space.
#let quad = h(1em)
#let join() = [\u{200D}]
#let hy() = [\u{2011}] // Non-breaking hyphen.
#let thinsp() = [\u{2009}] // Thin space.
#let col2(x) = table.cell(colspan: 2)[#x]
#let col3(x) = table.cell(colspan: 3)[#x]
#let row2(x) = table.cell(rowspan: 2)[#x]
#let row3(x) = table.cell(rowspan: 3)[#x]
#let Bar(x) = overline(x, offset: -.8em)
#let italic = text.with(style: "italic") // emph() that can be toggled off by nesting text(style: "normal")
#let normal = text.with(style: "normal")


// ============================================================================
//  State
// ============================================================================
#let __mainmatter = state("is_mainmatter", false)
#let __gloss-show-numbers = state("gloss_show_numbers", true)
#let __show-header = state("show-header", false)
#let __gloss-counter = counter("gloss")
#let __gloss_quotes = state("gloss-quotes", ([‘], [’]))
#let __draft-mode = state("draft-mode", true)
#let __compact = state("compact", false)

// ============================================================================
//  State Helpers
// ============================================================================
#let in-mainmatter() = __mainmatter.get()
#let chapter-size() = if __compact.get() { __compact-chapter-size } else { __chapter-size }

#let cleardoublepage() = {
    context if __compact.get() {
        pagebreak(weak: true)
    } else {
        __show-header.update(false)
        pagebreak(weak: true, to: "odd")
        __show-header.update(true)
    }
}

#let mainmatter(content) = {
    // Do this *before* updating the page number.
    cleardoublepage()

    // Set up mainmatter formatting.
    __mainmatter.update(true)
    counter(page).update(1)
    set page(numbering: "1")
    set heading(numbering: (first, ..nums) => {
        // Always include numbers in the frontmatter so chapter numbers
        // show up properly in the table of contents.
        context if nums.pos().len() != 0 or not in-mainmatter() {
            return [#first.#nums.pos().map(it => str(it)).join(".")]
        }
    })

    content
}

#let backmatter(content) = {
    __mainmatter.update(false)
    set page(columns: 1)

    // Reset the counter to prevent it from showing up in the TOC.
    counter(heading).update(0)

    // Show the LOF/LOT in the TOC.
    show outline: set heading(outlined: true)
    content
}

#let gloss-show-numbers(new-value) = __gloss-show-numbers.update(new-value)
#let gloss-set-quotes(lquote, rquote) = __gloss_quotes.update((lquote, rquote))

// ============================================================================
//  Page and Text Setup
// ============================================================================
#let page-num() = counter(page).display()
#let mark-even(header) = grid(columns: (auto, 1fr), [#page-num()], align(right, header))
#let mark-odd(header) = grid(columns: (1fr, auto), align(left, header), [#page-num()])
#let make-header(even, odd) = {
    let this-page = here().page()
    if calc.even(this-page) {
        mark-even(even)
    } else {
        mark-odd(odd)
    }
}

#let mark-both(both) = make-header(both, both)
#let format-header() = {
    let sel-chapters = selector(heading.where(level: 1))
    context {
        // Header is disabled in some sections.
        if not __show-header.get() { return none }

        // Don’t show a header if this is the start of a chapter.
        //
        // We can’t just use the chapters *before* this position since the heading
        // precedes the chapter head, so query *all* headings for this.
        let this-page = here().page()
        if query(sel-chapters).any(it => it.location().page() == this-page) {
             return none
        }

        // This page is not the start of a chapter; get the most recent chapter.
        let chapters = query(sel-chapters.before(here()))
        let has-chapter = chapters != none and chapters.len() != 0
        let chaptername() = {
            let num = counter(heading).at(here()).first()
            if num != 0 [#num#quad]
            chapters.last().body
        }

        make-header({
            // Even Page
            if has-chapter { chaptername() }
        }, {
            // Odd Page
            //
            // Outside the mainmatter, the chapter number is unset (and defaults to 0);
            // only use the chapter title in that case.
            if has-chapter and not in-mainmatter() {
                chapters.last().body
            }

            // In the rest of the document, use the most recent section heading.
            else {
                let sections = query(selector(heading.where(level: 2)).before(here()))
                if (
                    sections != none and
                    sections.len() != 0 and
                    // Take care not to reuse a heading from a previous chapter.
                    query(selector(heading).before(here())).last().level != 1
                ) [
                    #counter(heading).at(here()).slice(0, count: 2).map(str).join(".") #quad
                    #sections.last().body
                ]

                // If the are multiple pages before the first section of a chapter, just
                // reuse the chapter name for odd pages as well.
                else { chaptername() }
            }
        })
    }
}

// ============================================================================
//  Glosses
// ============================================================================
#let gloss-default-replacements = ("~": " ")
#let __gloss_replacements = state("gloss-functions", gloss-default-replacements)

// Merge whitespace.
#let __gloss-merge-ws(x) = x.replace(regex("[ ]+"), " ")

// Apply replacement sequences.
#let __gloss-apply-replacements(s_in) = context {
    let s = s_in
    let parts = ()
    while s.len() != 0 {
        for (val, repl) in __gloss_replacements.get() {
            let pos = s.position(val)
            if pos == none { continue }
            parts.push(s.slice(0, pos))
            s = s.slice(pos + val.len())
            parts.push(repl)
        }

        // No more replacements.
        parts.push(s)
        break
    }
    parts.join()
}

#let __gloss-handle-braces-brackets(s) = {
    let parts = ()
    while true {
        let lbrace = s.position(regex("[\[{]"))
        if lbrace == none {
            parts.push(__gloss-apply-replacements(s))
            break
        }

        parts.push(s.slice(0, lbrace))
        let char = s.at(lbrace)
        s = s.slice(lbrace + 1)

        let rbrace = s.position(regex("[\]}]"))
        assert(rbrace != none, message: "Unterminated } in gloss!")
        let text = s.slice(0, rbrace)
        parts.push([#if char == "{" { smallcaps(__gloss-apply-replacements(text)) } else { emph(__gloss-apply-replacements(text)) }])
        s = s.slice(rbrace + 1)
    }

    parts.join()
}

#let gloss-set-replacements(dict) = {
    __gloss_replacements.update(dict)
}

#let gloss_impl(separator: " ", loc: none, x) = {
    let lines = (if type(x) == content { x.text } else { x })
        .split("\n")
        .map(x => x.trim())
        .filter(x => x.len() != 0)

    let (lquote, rquote) = __gloss_quotes.get()
    let the-gloss = for (text, l2, l3, translation) in lines.chunks(4, exact: true) {
        let text_split = __gloss-merge-ws(l2).split(separator)
        let gloss = __gloss-merge-ws(l3).split(separator)
        stack(dir: ttb, spacing: .5em,
            strong(__gloss-apply-replacements(text)),
            [#for (t, g) in text_split.zip(gloss) {
                box(stack(
                    dir: ttb,
                    spacing: .5em,
                    [#italic(__gloss-apply-replacements(t))#h(4pt)],
                    [#__gloss-handle-braces-brackets(g) #h(4pt)],
                ))
            }],
            [#lquote#__gloss-apply-replacements(translation)#rquote]
        )
    }

    context if __gloss-show-numbers.get() {
        grid(columns:2, [(#__gloss-counter.at(loc).first())#en], the-gloss)
    } else {
        the-gloss
    }
}

#let gloss(separator: " ", lbl: none, x) = {
    context if __gloss-show-numbers.get() {
        counter.step(__gloss-counter)
    }

    context {
        let f = figure(
            kind: "gloss",
            supplement: none,
            gloss_impl(separator: separator, loc: here(), x)
        )

        if lbl != none {
            [
                #f
                #label("gloss:" + lbl)
            ]
        } else {
            f
        }
    }
}

#let multigloss(separator: " ", line-spacing: 1.25em, x) = {
    set par(
        first-line-indent: 0pt,
        justify: false,
        linebreaks: "simple",
        leading: line-spacing
    )


    let lines = (if type(x) == content { x.text } else { x })
        .split("\n")
        .map(x => x.trim())
        .filter(x => x.len() != 0)

    block(
        breakable: true,
        above: 1em,
        below: 1em,
        for (l1, l2) in lines.chunks(2, exact: true) {
            let text = __gloss-merge-ws(l1).split(separator)
            let gloss = __gloss-merge-ws(l2).split(separator)
            let skip = .675em
            for (t, g) in text.zip(gloss) {
                box(stack(
                    dir: ttb,
                    [#emph(__gloss-apply-replacements(t)) #h(skip)],
                    [#__gloss-handle-braces-brackets(__gloss-apply-replacements(g)) #h(skip)], spacing: .5em)
                )
            }
        }
    )
}

#let refgloss(x) = (context query(label("gloss:" + x)).first())

// ============================================================================
//  Page and Section Helpers
// ============================================================================
#let chapter(english-title, chapter-label, outlined: true) = {
    panic("#chapter() has been removed; use '= heading' instead.")
}

#let __make-chapter-head(it) = {
    context if __compact.get() {
        v(20pt)
    } else {
        cleardoublepage()
        v(50pt)
    }

    counter(footnote).update(0)
    __gloss-counter.update(0)

    set par(first-line-indent: 0pt)
    let format = {
        context text(
            weight: "regular",
            size: chapter-size(),
            it
        ) + v(chapter-size())
    }

    context if not in-mainmatter() {
        format
    } else {
        // box() is needed to make sure the number and chapter name are on the
        // same line; block() is needed to suppress indentation of the first line
        // after the chapter head.
        block(box(stack(dir: ltr, [
            #if in-mainmatter() {
                counter(selector(heading).before(here())).display((it, ..) =>
                    text(
                        chapter-size(),
                        weight: "regular",
                        number-type: "lining"
                    )[#it]
                )
            }
        ], move(
            dx: if in-mainmatter() {
                if __compact.get() { 1em } else { 1.5em }
            } else {
                0pt
            },
            [#format]
        ))))
    }
}

#let partitle(x) = {
    v(1.5em, weak: true)
    block(text(weight: "semibold", x), sticky: true)
}

// ============================================================================
//  Index
// ============================================================================
#let indexentry(..x) = [#metadata((..x.pos()))<__index-entry__>]
#let index(..x) = [#x.pos().map(str).join(" ")#indexentry(..x.pos())]
#let makeindex() = {
    set page(columns: 1)
    cleardoublepage()
    place(top + left, scope: "parent", float: true, heading(numbering: none)[Index])
    let sel = selector(<__index-entry__>)
    context {
        let pages_key = str("\u{1}")
        let query_res = query(sel)
        let entries = query_res.fold((:), (dict, entry) => {
            let append(dict, first, ..rest) = { // God I hate pure functional programming...
                if (rest.pos().len() == 0) {
                    let node = dict.at(first, default: (:))
                    let arr = node.at(pages_key, default: ())
                    arr.push(entry.location().page())
                    node.insert(pages_key, arr)
                    dict.insert(first, node)
                    dict
                } else {
                    let node = dict.at(first, default: (:))
                    dict.insert(first, append(node, rest.pos().at(0), ..rest.pos().slice(1)))
                    dict
                }
            }

            append(dict, entry.value.at(0), ..entry.value.slice(1))
        })

        let format-int-ranges(ints) = {
            let format-range(start, end) = {
                if start == end [#start]
                else [#start–#end]
            }

            let entries = ()
            let start = ints.at(0)
            let end = ints.at(0)
            for i in ints.slice(1).dedup() {
                if end == i - 1 { end = i }
                else {
                    entries.push(format-range(start, end))
                    start = i
                    end = i
                }
            }

            entries.push(format-range(start, end))
            entries.join(", ")
        }

        let format-tree(tree, level) = {
            set list(marker: none, body-indent: 0pt, indent: 2em * level)
            for (k, v) in tree {
                let pages = v.remove(pages_key)
                list.item([
                    #k
                    #if pages != none [#en #format-int-ranges(pages)]
                    #format-tree(v, level + 1)
                ])
            }
        }

        set par(first-line-indent: 0pt, hanging-indent: 2em)
        format-tree(entries, 0)
    }
}

// ============================================================================
//  Glossary
// ============================================================================
#let glossary(cols: 3, ..entries) = {

    // Split into 3 equal partitions, chopping off excess elements.
    let partitions = entries.pos().chunks(int(entries.pos().len() / cols), exact: true)

    // If there are trailing elements, append them to the individual partitions in turn.
    let partitioned_elements = partitions.map(it => it.len()).fold(0, (acc, n) => acc + n)
    let next_part = 0
    for entry in entries.pos().slice(partitioned_elements) {
        partitions.at(next_part).push(entry)
        next_part += 1
    }

    // Lay out the partitioned elements.
    grid(columns: cols, ..partitions.map(partition => table(
        columns: 2,
        ..partition.map(((term, def)) => (table.cell[#term], table.cell[#def])).join(),
    ) + h(1fr)))
}

// ============================================================================
//  Figures, Tables, etc.
// ============================================================================
#let italic-table-body(cols: (0,), rows: (0,), it) = {
    show table.cell: it => if (it.x in cols or it.y in rows) { it } else { emph(it) }
    it
}

#let center-table(..content, size: normalfont-size, caption: [Caption], stroke: none) = figure(
    caption: caption,
    text(size: size, rowtable(stroke: stroke, ..content))
)

#let table-of-contents() = {
    set outline.entry(fill: repeat([.], gap: .44em))

    show outline.entry.where(level: 1): it => link(
        it.element.location(),
        it.indented([
            #let num = counter(heading).at(it.element.location()).first()
            #if num != 0 [ #num ] else { hide[#num] } // Add a hidden '0' for indentation.
        ], [
            #it.body() #h(1fr) #it.page()
        ])
    )

    show outline.entry.where(level: 1): set block(above: 1.5em)

    cleardoublepage()
    outline()
}

#let outline = table-of-contents

#let verse(lines, parsep: 2em) = {
    set par(first-line-indent: 0pt, spacing: parsep)
    block(align(left, lines))
}

// Show the first and last word of each page.
// Disabled in draft mode because it is *very* slow (takes ~4 seconds for 3000); only enable
// this when building the final document for printing!!!
#let __dictionary-mark(content) = context {
    set page(
        header: context mark-both({
            let this-page = here().page()
            let sel = selector(<dict-entry>)
            let marks = query(sel).filter(it => it.location().page() == this-page)
            if marks.len() != 0 [
                *#marks.first().value | #marks.last().value*
            ]
        })
    ) if not __draft-mode.get()

    content
}

#let render-dictionary-node(
    node,
    current-word : "<no current word>",
    lemma-format: it => text(weight: "semibold", it),
) = {
    let render-all(nodes) = {
        nodes.map(it => render-dictionary-node(
            it,
            current-word: current-word,
            lemma-format: lemma-format,
        )).join()
    }

    if "text" in node {
        node.text
    } else if "math" in node {
        node.math
    } else if "group" in node {
        render-all(node.group)
    } else if "macro" in node {
            if node.macro.name == "bold" [*#render-all(node.macro.args)*]
        else if node.macro.name == "ellipsis" [...]
        else if node.macro.name == "italic" { italic(render-all(node.macro.args)) }
        else if node.macro.name == "lemma" { lemma-format(render-all(node.macro.args)) }
        else if node.macro.name == "normal" { text(style: "normal", render-all(node.macro.args)) }
        else if node.macro.name == "paragraph_break" { parbreak() }
        else if node.macro.name == "sense" [sense~#render-all(node.macro.args)]
        else if node.macro.name == "small_caps" { s(render-all(node.macro.args)) }
        else if node.macro.name == "subscript" { sub(render-all(node.macro.args)) }
        else if node.macro.name == "superscript" { super(render-all(node.macro.args)) }
        else if node.macro.name == "soft_hyphen" [-?]
        else if node.macro.name == "this" { lemma-format(render(current-word)) }
        else if node.macro.name == "reference" {
            assert(node.macro.args.len() == 1, message: "\\ref has exactly 1 argument")
            assert("text" in node.macro.args.at(0), message: "Argument of \\ref must be a text node")
            ref(label(node.macro.args.at(0).text))
        } else {
            panic("Unknown macro: ", node.macro.name)
        }
    } else {
        panic("Unsupported node: ", node)
    }
}

#let __typeset-entry(entry, lemma-format) = {
    let is-empty(node) = { "text" in node and node.text == "" }
    let render(node) = render-dictionary-node(
        node,
        current-word: entry.word,
        lemma-format: lemma-format,
    )

    if "ref" in entry {
        par(first-line-indent: 0pt)[
            #metadata(render(entry.word)) <dict-entry>
            #text(size:13pt, weight: "semibold", render(entry.word)) $arrow$ #render(entry.ref)
        ]
    } else { block[
        #let examples(exs) = if "examples" in exs and exs.examples.len() != 0 [
            #set block(below: .65em, above: .65em)
            #list(
                indent: .7em,
                body-indent: .3em,
                marker: $diamond.small$,
                spacing: .5em,
                ..exs.examples.map(e => [
                    #render(e.text)
                    #if "comment" in e { italic(render(e.comment)) }
                ])
            )
        ]

        #set par(hanging-indent: .5em, first-line-indent: 0pt)
        #set list(tight: true)
        #set enum(tight: true)
        #metadata(render(entry.word)) <dict-entry>

        #text(size:13pt, weight: "semibold")[#render(entry.word)]
        #if "ipa" in entry { box[/#render(entry.ipa)/] }
        #italic(render(entry.pos))
        #if not is-empty(entry.etym) [[#render(entry.etym)]]
        #if "forms" in entry [#italic(render(entry.forms)).]
        #if "primary_definition" in entry [
            #render(entry.primary_definition.def)
            #if "comment" in entry.primary_definition { italic(render(entry.primary_definition.comment)) }
            #examples(entry.primary_definition)
        ]#parbreak()

        #if "senses" in entry and entry.senses.len() != 0 {
            for (i, s) in entry.senses.enumerate() [
                #set par(first-line-indent: (amount: .2em, all: true))
                #text(weight: "semibold")[#(i+1).] #render(s.def)
                #if "comment" in s { italic(render(s.comment)) }
                #parbreak()
                #examples(s)
            ]
        }

        #v(.1em)
    ] }
}

/// Generate a dictionary using a dictionary file and generator plugin.
///
/// Example:
/// ```typst
/// #dictionary(
///     read("my_language.dict.txt"),
///     plugin("plugin/target/wasm32-unknown-unknown/release/plugin.wasm"),
///     it => text(weight: "semibold", it)
/// )
/// ```
#let dictionary(
    dictionary-contents,
    dictionary-plugin,
    lemma-format: it => text(weight: "semibold", it),
) = {
    let dictionary-obj = json(dictionary-plugin.generate_dictionary(bytes(dictionary-contents)))
    pagebreak()
    set page(columns: 2)
    set columns(gutter: 1em)
    show : __dictionary-mark
    dictionary-obj.entries.map(it => __typeset-entry(it, lemma-format)).join()
}

// ============================================================================
//  Show and set rules.
// ============================================================================
#let setup(
    content,

    // [REDACTED] needs to set a custom chapter size.
    chapter-size: chapter-size,

    // Enables compact layout if true:
    //
    //   - Do not insert a page break before a chapter.
    //   - Do not require a chapter to start on an odd page.
    //
    compact: false,
) = {
    // Page etc.
    set page(
        "a4",
        margin: 2cm,
        header: format-header(),
        numbering: "i",
        footer: none
    )

    set par(
        justify: true,
        linebreaks: "optimized",
        first-line-indent: par-first-line-indent,
        spacing: par-spacing,
        leading: par-leading
    )

    set text(
        size: normalfont-size,
        fill: black,
        number-type: "old-style",
        font: "Minion 3",
        hyphenate: true
    )

    if compact {
        __compact.update(true)
    }

    show heading.where(depth: 1): it => __make-chapter-head(it)
    show heading.where(depth: 1): set par(hanging-indent: 0pt)

    show heading.where(depth: 2): it => text(weight: "regular", size: section-size, it) + v(10pt)
    show heading.where(depth: 3): it => text(weight: "regular", size: subsection-size, it)

    set strong(delta: 200)
    set list(indent: 1em, marker: (list-sep,))
    set enum(indent: 1em)
    show enum: set block(spacing: 1em)
    show enum.where(tight: false): set par(spacing: 1em)
    show list: set par(spacing: 1em)
    set table(stroke: none)
    set table.hline(stroke: .5pt)
    set table.vline(stroke: .5pt)
    set figure(gap: 1em)
    show figure: set block(below: 1em)

    show footnote.entry: it => {
        let val = counter(footnote).at(it.note.location()).first()
        let link = link.with(it.note.location())
        move(dx: -.2em, enum(
            numbering: it => llap(link(super([#it]))),
            body-indent: .2em,
            enum.item(val)[#it.note.body]
        ))
    }

    // Glosses.
    show figure.where(kind: "gloss"): set align(left)
    show figure.where(kind: "gloss"): set block(above: 1em)

    // Headings.
    show ref.where(form: "normal"): it => {
        let el = it.element
        if el != none and el.func() == heading {
            let num = counter(heading).at(el.location()).map(str).join(".")
            link(el.location(), if el.depth == 1 {
                [Chapter~#num]
            } else {
                [§~#num]
            })
        } else if el != none and el.func() == figure and el.kind == "gloss" {
            link(el.location(), [(#(__gloss-counter.at(el.location()).first()))])
        } else {
            it
        }
    }

    content
}
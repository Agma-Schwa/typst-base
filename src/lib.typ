// ============================================================================
//  Dependencies
// ============================================================================
#import "@preview/rowmantic:0.5.0" : rowtable, expandcell

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
#let chapter-size = 30pt
#let list-sep = $diamond.stroked.small$

#let small(x) = text(small-size, [#x])
#let nf(x) = text(normalfont-size, weight: "regular", style: "normal", [#x])
#let large(x) = text(large-size, [#x])
#let Large(x) = text(Large-size, [#x])
#let huge(x) = text(huge-size, [#x])
#let cell = table.cell
#let remove-whitespace-before() = h(0pt, weak: true)
#let s = smallcaps
#let llap(x) = box(width: 0pt, [#h(-100cm)#h(1fr)#x])
#let rlap(x) = box(width: 0pt, [#x#h(1fr)#h(-100cm)])
#let vline = table.vline()
#let hline = table.hline()
#let vlineat(x) = table.vline(x: x)
#let hlineat(y) = table.hline(y: y)
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
#let row2(x) = table.cell(rowspan: 2)[#x]
#let row3(x) = table.cell(rowspan: 3)[#x]


// ============================================================================
//  State
// ============================================================================
#let __mainmatter = state("is_mainmatter", false)
#let __gloss-show-numbers = state("gloss_show_numbers", true)
#let __show-header = state("show-header", false)
#let __gloss-counter = counter("gloss")


// ============================================================================
//  State Helpers
// ============================================================================
#let in-mainmatter() = __mainmatter.get()

#let cleardoublepage() = {
    __show-header.update(false)
    pagebreak(weak: true, to: "odd")
    __show-header.update(true)
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
#let braces-to-smallcaps(s) = {
    let parts = ()
    while true {
        let lbrace = s.position("{")
        if lbrace == none {
            parts.push([#s])
            break
        }

        parts.push(s.slice(0, lbrace))
        s = s.slice(lbrace + 1)

        let rbrace = s.position("}")
        assert(rbrace != none, message: "Unterminated } in gloss!")
        let text = s.slice(0, rbrace)
        parts.push([#smallcaps(text)])
        s = s.slice(rbrace + 1)
    }

    parts.join()
}

#let gloss_impl(separator: " ", loc: none, x) = {
    let lines = x
        .split("\n")
        .map(x => x.trim())
        .filter(x => x.len() != 0)

    let the-gloss = for (text, l2, l3, translation) in lines.chunks(4, exact: true) {
        let text_split = l2.split(separator)
        let gloss = l3.split(separator)
        stack(dir: ttb, spacing: .5em,
            strong(text),
            [#for (t, g) in text_split.zip(gloss) {
                box[#stack(dir: ttb, [#emph(t)#h(4pt)], [#braces-to-smallcaps(g) #h(4pt)], spacing: .5em)]
            }],
            [“#translation”]
        )
    }

    context if gloss-show-numbers.get() {
        grid(columns:2, [(#__gloss-counter.at(loc).first())#en], the-gloss)
    } else {
        the-gloss
    }
}

#let gloss(separator: " ", lbl: none, x) = {
    context if gloss-show-numbers.get() {
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

#let refgloss(x) = (context query(label("gloss:" + x)).first())

// ============================================================================
//  Page and Section Helpers
// ============================================================================
#let chapter(english-title, chapter-label) = {
    cleardoublepage()
    v(50pt)
    counter(footnote).update(0)
    __gloss-counter.update(0)

    set par(first-line-indent: 0pt)
    let format = {
        [
            #heading(depth: 1, english-title, hanging-indent: 0pt)
            #label("ch:" + chapter-label)
        ]
    }

    context if not in-mainmatter() {
        format
    } else {
        stack(dir: ltr, [
            #if in-mainmatter() {
                counter(selector(heading).before(here())).display((it, ..) =>
                    text(chapter-size, number-type: "lining")[#(it + 1)]
                )
            }
        ], move(dx: if in-mainmatter() { 1.5em } else { 0pt }, [
            #format
        ]))
    }
}

#let partitle(x) = {
    v(1.5em, weak: true)
    block(text(weight: "semibold", x), sticky: true)
}

// ============================================================================
//  Index Entries
// ============================================================================
#let indexentry(..x) = [#metadata((..x.pos()))<__index-entry>]
#let index(..x) = [#x.pos().map(str).join(" ")#indexentry(..x.pos())]

// ============================================================================
//  Figures, Tables, etc.
// ============================================================================
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

// ============================================================================
//  Show and set rules.
// ============================================================================
#let setup(content) = {
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

        // These values were calibrated for the current font by checking how many
        // lines LaTeX can fit on a page using the same font and page size and then
        // adjusting these until Typst can fit the same number of lines; this is
        // because there is no good one-to-one mapping (that I know of) between how
        // these values are specified in LaTeX and Typst. These values are probably
        // font-dependent (at least the default line height usually is) and may
        // require recalibration whenever the font is changed.
        first-line-indent: 1.5em,
        spacing: .56em,
        leading: .56em
    )

    set text(
        size: normalfont-size,
        fill: black,
        number-type: "old-style",
        font: "Minion 3",
        hyphenate: true
    )

    show heading.where(depth: 1): it => text(weight: "regular", size: chapter-size, it) + v(30pt)
    show heading.where(depth: 2): it => text(weight: "regular", size: section-size, it) + v(10pt)
    show heading.where(depth: 3): it => text(weight: "regular", size: subsection-size, it)

    set list(marker: ([–], list-sep), indent: 1em)
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
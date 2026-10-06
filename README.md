# view_component_d

ViewComponent-style components for D. A component is a class plus a sidecar
template in the same directory, compiled together at CTFE.

```d
// app/components/button_component/component.d
module components.button_component.component;

import view_component;

final class ButtonComponent : ViewComponent
{
    string label;
    string tone;

    this(string label, string tone)
    {
        this.label = label;
        this.tone = tone;
    }

    string cssClass() { return "btn btn--" ~ tone; }

    mixin Template;
}
```

```erb
<%# app/components/button_component/component.html.erb %>
<a class="<%= cssClass %>" href="#"><%= label %></a>
```

```d
new ButtonComponent("Save", "primary").render();
// <a class="btn btn--primary" href="#">Save</a>
```

## Install

```sdl
dependency "view_component_d" version="~>0.1"

stringImportPaths "app/components"
```

**`stringImportPaths` is required.** Templates are read with D's `import("…")`
string import, which only searches the paths given to `-J`. Without it every
component fails to compile with a message naming every path it looked for.

## How it works

`mixin Template;` reads the sidecar at compile time, compiles the ERB to D
statements, and mixes them into the component's `renderInto` method. Because
the generated code lands *inside* a method of your class, `<%= label %>` is
literally `this.label` — type-checked at compile time, with no context object,
no name lookup and no runtime parsing. A malformed template or a typo'd field
is a compile error, not a 500.

The flip side: **editing a template requires a rebuild.** There is no runtime
template engine, deliberately — D cannot evaluate D at runtime, so a runtime
backend could only ever support a crippled subset of the expressions the
compile-time one accepts. Run `bin/watch` for the dev loop instead.

## Sidecar directories

**Every component lives in a directory named after itself.** There is no layout
where a template sits loose beside its class — that is the one supported shape,
and the resolver enforces it.

The directory name comes from the class name, snake_cased (`ButtonComponent` →
`button_component`, `HTMLBlockComponent` → `html_block_component`). Everything
belonging to the component goes in it, named `component.*`: the class, the
template, and any colocated stylesheet or script.

```
app/components/
  button_component/
    component.d                      # module components.button_component.component
    component.html.erb
  card_component/
    component.d
    component.html.erb
    component.css
  sidebar_component/
    component.d
    component.html.erb
    component.css
    component.js
    sidebar_link_component/          # sub-component, same rule
      component.d
      component.html.erb
```

Files named after the directory are supported too, and the two layouts can be
mixed across components:

```
app/components/
  button_component/
    button_component.d               # module components.button_component.button_component
    button_component.html.erb
```

Within one component, name every file the same way: colocated assets are found
by the template's basename, so a `sidebar_component.css` next to a
`component.html.erb` is not picked up.

Sub-components nest the same way — each in its own directory inside its
parent's, which keeps the rule identical at every depth. A component is found
through its module path, which already mirrors the directory tree, so nesting
needs no configuration.

Resolution order, first match wins:

1. `<stem>/component.html.erb`
2. `<package path>/component.html.erb`, from the module's packages, longest
   first — only paths whose last directory is `<stem>`
3. `<stem>/<stem>.html.erb`
4. `<package path>/<stem>.html.erb`, from the module's packages, longest first
5. the same four with `.dt`

The `<stem>` restriction in step 2 matters because a `component.*` name no
longer identifies its class: a second class declared in
`sidebar_component/component.d` fails to compile instead of rendering the
sidebar's template.

There is no explicit-path escape hatch: `mixin Template;` takes no argument.
Every component exposes the path it resolved to as `Component.templatePath`,
which is what the example's `assetManifest` uses to find colocated assets.

## Template syntax

| Tag | Meaning |
| --- | --- |
| `<% code %>` | D statement, emitted verbatim |
| `<%= expr %>` | D expression, stringified and HTML-escaped |
| `<%== expr %>` | D expression, emitted **unescaped** |
| `<%# text %>` | comment, discarded |
| `<%%` | a literal `<%` |
| `<%-` … `-%>` | explicitly trim the preceding indentation / the following newline |

**A statement or comment tag alone on its line takes the whole line with it**,
so control flow costs no blank lines in the output and `<%-` / `-%>` are only
needed for a tag sharing its line with markup. Output tags (`<%= %>`) never
auto-trim — their surrounding whitespace is real content.

```erb
<ul>
  <% foreach (entry; entries) { %>
    <li><%= entry %></li>
  <% } %>
</ul>
```
```html
<ul>
    <li>one</li>
    <li>two</li>
</ul>
```

Expressions are full D — anything in scope in a method of your component,
including its private members. In scope on top of that:

- `render(value)` — renders a component, or an array of them, into the sink
- `content` — the caller-supplied content block
- `raw(value)` — marks a value as trusted markup

Escaping is automatic and covers `& < > " '`. `<%= component %>` renders a
nested component; `<%= someArray %>` of components renders each in order.

The one limitation: a tag body may not contain the literal `%>`, including
inside a D string. Move such an expression into a method on the component.

## Rendering components inside a template

Two equivalent forms — `render(...)` as a statement, or `<%= ... %>` as an
expression. Both write into the *same* sink as the enclosing component, so a
whole tree costs one buffer, not one string per node.

```erb
<%# a single child component held in a field %>
<% render(footer); %>
<%= footer %>

<%# an array of children — rendered in order, nulls skipped %>
<% render(links); %>
<%= links %>

<%# constructed inline %>
<% render(new ButtonComponent("Save", "primary")); %>

<%# a child with slots and content, built inline %>
<% render(new CardComponent().withHeading("Revenue").withContent("18,240")); %>

<%# conditionally, and in a loop %>
<% if (hasFooter) { %>
  <% render(footer); %>
<% } %>

<% foreach (section; sections) { %>
  <% render(section); %>
<% } %>
```

`render(x)` and `<%= x %>` are the same call. Pick `render(...)` when the child
is the whole point of the line, and `<%= ... %>` when it sits inline among
markup. Neither escapes a component's markup; `<%= someString %>` still does.

The child's class must be visible to the parent's *module*, so import it in the
`.d` file as usual — templates have no import mechanism of their own:

```d
module components.sidebar_component.component;

import view_component;
import components.sidebar_component.sidebar_link_component.component : SidebarLinkComponent;
```

### Inline child, or slot?

A child does not have to come from a slot. When it is an implementation detail
of its parent, construct it in the parent's template from the parent's own
data — the caller never learns it exists:

```erb
<%= new SidebarStatusComponent(sectionCount, totalLinkCount, currentPath) %>
```

An inline child can have slots of its own, filled right there — every `withX`
returns the component, and an output tag may span lines:

```erb
<%= new SidebarStatusComponent(sectionCount, totalLinkCount, currentPath)
      .withHint(raw("<em>live</em>"))
      .withChips("nav")
      .withChips("beta & new") %>
```

Text handed to a slot is escaped, so pass `raw(...)` for markup and plain text
otherwise — `"beta & new"` renders as `beta &amp; new`, and writing the entity
yourself would escape it twice.

Use a slot instead when the caller should be able to supply, replace or omit
the child. The rule of thumb: a slot is part of the component's public API, an
inline child is part of its implementation. `example/app/components/sidebar_component`
shows both — the footer arrives through `RendersOne`, the status line is built
inline.

Children reached through a slot need no field at all — `mixin
RendersMany!("links", SidebarLinkComponent);` gives the template `links`
directly. A parent can push state down in `beforeRender`, which runs before
every child renders:

```d
protected override void beforeRender()
{
    foreach (section; sections)
        section.currentPath = currentPath;
}
```

## Slots

```d
final class CardComponent : ViewComponent
{
    mixin RendersOneContent!("heading");          // markup slot
    mixin RendersMany!("actions", ButtonComponent); // component slot

    mixin Template;
}

new CardComponent()
    .withHeading("Revenue")
    .withActions(new ButtonComponent("Export", "primary"))
    .withContent("body text")
    .render();
```

Each slot generates `withX` for the caller and `x` / `hasX` for the template.
`RendersOne` / `RendersMany` take a component class; `RendersOneContent` /
`RendersManyContent` take text, `raw(...)` markup, or a
`void delegate(ref Sink)` builder. The `withX` setter for a many-slot keeps the
plural name — no inflection is guessed — and is variadic:
`.withActions(a, b, c)`.

`withContent` on the base class works the same way and feeds `<%= content %>`.

## Rendering hooks

Declare `beforeRender()` to derive state, and `shouldRender()` to suppress the
component entirely (the equivalent of ViewComponent's `render?`). Neither needs
`override` or `protected` — they are found by name on the concrete class when
the template is compiled:

```d
void beforeRender()
{
    foreach (section; sections)
        section.currentPath = currentPath;
}

bool shouldRender()
{
    return links.length != 0;
}
```

Dropping `override` would normally mean a misspelled hook silently never runs,
so the mixin rejects near misses: any member within one edit of a hook name, or
differing only in case, is a compile error naming the hook it resembles. A hook
with the wrong signature is rejected too. Hooks are dispatched from the
generated `renderInto`, so a component that writes `renderInto` by hand instead
of using `mixin Template` does not get them.

## Validating templates

The compile-time parser checks that ERB tags are well-formed and that the D
inside them compiles. It does **not** understand HTML — it sees `<%` and `%>`
as byte pairs, so an unclosed `<div>` or an ERB tag straddling an attribute
boundary compiles happily and breaks in the browser.

`bin/validate-templates` closes that gap using [Herb](https://github.com/marcoroth/herb),
an HTML-aware ERB parser. Wire it into your own recipe:

```sdl
preBuildCommands "if command -v ruby >/dev/null 2>&1; then ./bin/validate-templates app/components; fi"
```

```
$ bin/validate-templates app/components
app/components/card_component/component.html.erb:4:2
  MissingOpeningTagError: Found closing tag `</div>` at (4:2) without a matching
  opening tag in the same scope.
```

It is **entirely optional**: the script exits 0 with a notice when the `herb`
gem is absent, and the `command -v ruby` guard skips it when Ruby is not
installed at all. The library itself keeps its zero-dependency, Ruby-free build.

Herb parses ERB tag bodies as Ruby, and ours hold D — `<% if (x) { %>` is valid
D but broken Ruby, and Ruby's `if` wants an `end` where we write `}`. The script
therefore blanks every tag body first, preserving its length so line and column
numbers stay accurate, and lets Herb validate only the HTML skeleton around
opaque tags. Nothing about your D is inspected or constrained.


## Previews and tests

```d
final class ButtonComponentPreview : ComponentPreview
{
    ViewComponent primary() { return new ButtonComponent("Save", "primary"); }
}

registerPreviews!(components.button_component.component)();
PreviewRegistry.render("ButtonComponentPreview", "primary");
```

Every zero-argument method returning a `ViewComponent` is registered as one
preview. `view_component.testing` provides `assertIncludes`, `assertExcludes`,
`assertRendersEqual`, `assertRendersEqualNormalized`, `assertHasElement` and
`hasElement`. CSS selector matching is not implemented — `assertHasElement`
matches a tag name plus attribute substrings.

## Diet templates

`.dt` sidecars are compiled by [diet-ng](https://code.dlang.org/packages/diet-ng)
instead, also at CTFE. Enable it explicitly:

```sdl
dependency "diet-ng" version="~>1.8"
versions "ViewComponentDiet"
```

Diet templates reach the component through an alias named `component`
(`#{component.label}`), because Diet resolves names against the aliases it is
handed rather than against enclosing scope. Without the version flag, a `.dt`
sidecar fails the build with instructions rather than a missing-module error.

## Benchmark

`../benchmark/` — shared with the other ports in the surrounding
`view_component_implementations` checkout — renders a dashboard of **15
component types nested five levels deep**: every slot kind, per-level
conditionals, attribute-dense markup, at 2006, 10006 and 20006 components.
Each runtime is measured twice: the view layer on its own, and inside a
complete application with models, SQLite and an HTTP server. Every runtime
must emit byte-identical markup before any timing is reported.

```sh
../benchmark/run
```

```
2006 components, parity OK (398932 bytes everywhere)

view_component_d (LDC, release)              0.665 ms   1503 renders/s    1.0x
view_component_d (vibe.d + SQLite, HTTP)     4.261 ms    235 renders/s    6.4x
view_component gem (standalone)              9.412 ms    106 renders/s   14.1x
view_component gem (Rails + SQLite, HTTP)   10.505 ms     95 renders/s   15.8x
```

The full-application rows break each request into database, component
construction and render time. See `../benchmark/README.md`.

## Development

```sh
dub test                             # core suite
dub test --config=unittest-diet      # core suite plus the Diet backend
cd example && dub run                # runnable examples
bin/watch                            # rebuild on source or template change
```

`example/` is the reference for anything this README only sketches. The sidebar
is the largest piece: a three-level tree (`SidebarComponent` →
`SidebarSectionComponent` → `SidebarLinkComponent`) in one sidecar directory
with colocated CSS and JS, using all four slot kinds plus the content block,
`beforeRender` to push the current path down the tree, `shouldRender` to drop an
empty section, and a compile-time asset manifest.

Requires a D compiler with the DMD 2.112 frontend or newer; developed against
LDC 1.42.

## Licence

MIT.

# view_component_d

ViewComponent-style components for D. A component is a class plus a sidecar
template in the same directory, compiled together at CTFE.

```d
// app/components/button_component.d
module components.button_component;

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
<%# app/components/button_component.html.erb %>
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
component fails to compile with a message naming the four paths it looked for.

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

## Sidecar layouts

Both are found by convention from the class name, which is snake_cased
(`ButtonComponent` → `button_component`, `HTMLBlockComponent` →
`html_block_component`):

```
app/components/
  button_component.d              # flat
  button_component.html.erb
  card_component/                 # sidecar directory
    card_component.d
    card_component.html.erb
    card_component.css
  sidebar_component/              # sidecar directory with sub-components
    sidebar_component.d
    sidebar_component.html.erb
    sidebar_component.css
    sidebar_component.js
    sidebar_section_component.d
    sidebar_section_component.html.erb
    sidebar_link_component.d
    sidebar_link_component.html.erb
```

A component that lives inside *another* component's sidecar directory is found
through its own module path, which mirrors the directory tree.
`SidebarLinkComponent` is module `components.sidebar_component.
sidebar_link_component`, so `sidebar_component/` is tried as a directory.
Sub-components therefore need no configuration and no explicit path.

Resolution order, first match wins:

1. `<stem>.html.erb`
2. `<stem>/<stem>.html.erb`
3. `<package path>/<stem>.html.erb`, from the module's packages, longest first
4. the same three with `.dt`

Override it entirely with `mixin Template!("some/other.html.erb");`. Every
component exposes the path it resolved to as `Component.templatePath`, which is
what the example's `assetManifest` uses to find colocated `.css` / `.js`.

## Template syntax

| Tag | Meaning |
| --- | --- |
| `<% code %>` | D statement, emitted verbatim |
| `<%= expr %>` | D expression, stringified and HTML-escaped |
| `<%== expr %>` | D expression, emitted **unescaped** |
| `<%# text %>` | comment, discarded |
| `<%%` | a literal `<%` |
| `<%-` … `-%>` | trim the preceding indentation / the following newline |

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
<%- if (hasFooter) { -%>
  <% render(footer); %>
<%- } -%>

<%- foreach (section; sections) { -%>
  <% render(section); %>
<%- } -%>
```

`render(x)` and `<%= x %>` are the same call. Pick `render(...)` when the child
is the whole point of the line, and `<%= ... %>` when it sits inline among
markup. Neither escapes a component's markup; `<%= someString %>` still does.

The child's class must be visible to the parent's *module*, so import it in the
`.d` file as usual — templates have no import mechanism of their own:

```d
module components.sidebar_component.sidebar_component;

import view_component;
import components.sidebar_component.sidebar_link_component : SidebarLinkComponent;
```

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

Override `beforeRender()` to derive state, and `shouldRender()` to suppress the
component entirely (the equivalent of ViewComponent's `render?`).

## Previews and tests

```d
final class ButtonComponentPreview : ComponentPreview
{
    ViewComponent primary() { return new ButtonComponent("Save", "primary"); }
}

registerPreviews!(components.button_component)();
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

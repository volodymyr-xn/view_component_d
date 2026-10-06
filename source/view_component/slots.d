module view_component.slots;

static import view_component.base;
static import view_component.escape;

import view_component.base : ViewComponent;

/**
 * Gives mixed-in slot code access to library symbols.
 *
 * A template mixin resolves identifiers in the scope it is mixed into, not the
 * one it was declared in, so generated code cannot name library symbols
 * directly. Passing this namespace as a defaulted template parameter works
 * because parameter defaults *are* resolved in the declaration scope — the slot
 * mixins therefore need nothing imported on the consumer's side.
 */
struct SlotSupport {
    alias Content = view_component.base.Content;
    alias SafeString = view_component.escape.SafeString;
    alias Sink = view_component.base.Sink;
}

/**
 * Declares a single-component slot, the equivalent of `renders_one`.
 *
 *   mixin RendersOne!("header", HeaderComponent);
 *
 * generates `withHeader(component)` for the caller, plus `header` and
 * `hasHeader` for the template.
 */
mixin template RendersOne(string slotName, SlotType, string generatedCode = rendersOneCode(slotName))
if (is(SlotType : ViewComponent)) {
    mixin(generatedCode);
}

/**
 * Declares a multi-component slot, the equivalent of `renders_many`.
 *
 *   mixin RendersMany!("items", ItemComponent);
 *
 * generates a variadic `withItems(a, b, ...)` that appends, plus `items` and
 * `hasItems`. The setter keeps the plural name so no inflection is guessed.
 */
mixin template RendersMany(string slotName, SlotType,
    string generatedCode = rendersManyCode(slotName))
if (is(SlotType : ViewComponent)) {
    mixin(generatedCode);
}

/**
 * Declares a markup slot with no component class behind it — the caller passes
 * text, trusted markup, or a builder delegate.
 *
 *   mixin RendersOneContent!("title");
 */
mixin template RendersOneContent(string slotName, alias Support = SlotSupport,
    string generatedCode = rendersOneContentCode(slotName)) {
    mixin(generatedCode);
}

/**
 * Declares a repeatable markup slot — `RendersOneContent` for many entries.
 *
 *   mixin RendersManyContent!("rows");
 */
mixin template RendersManyContent(string slotName, alias Support = SlotSupport,
    string generatedCode = rendersManyContentCode(slotName)) {
    mixin(generatedCode);
}

private string rendersOneCode(string slotName) pure nothrow @safe {
    immutable suffix = capitalizeSlotName(slotName);
    immutable field = slotName ~ "Slot_";

    return "private SlotType " ~ field ~ ";"
        ~ "final typeof(this) with" ~ suffix ~ "(SlotType component)"
        ~ "{ " ~ field ~ " = component; return this; }"
        ~ "final SlotType " ~ slotName ~ "() { return " ~ field ~ "; }"
        ~ "final bool has" ~ suffix ~ "() const { return " ~ field ~ " !is null; }";
}

private string rendersManyCode(string slotName) pure nothrow @safe {
    immutable suffix = capitalizeSlotName(slotName);
    immutable field = slotName ~ "Slot_";

    return "private SlotType[] " ~ field ~ ";"
        ~ "final typeof(this) with" ~ suffix ~ "(SlotType[] components...)"
        ~ "{ " ~ field ~ " ~= components; return this; }"
        ~ "final SlotType[] " ~ slotName ~ "() { return " ~ field ~ "; }"
        ~ "final bool has" ~ suffix ~ "() const { return " ~ field ~ ".length != 0; }";
}

private string rendersOneContentCode(string slotName) pure nothrow @safe {
    immutable suffix = capitalizeSlotName(slotName);
    immutable field = slotName ~ "Slot_";

    return "private Support.Content " ~ field ~ ";"
        ~ "final typeof(this) with" ~ suffix ~ "(string text)"
        ~ "{ " ~ field ~ " = Support.Content.ofText(text); return this; }"
        ~ "final typeof(this) with" ~ suffix ~ "(Support.SafeString markup)"
        ~ "{ " ~ field ~ " = Support.Content.ofMarkup(markup); return this; }"
        ~ "final typeof(this) with" ~ suffix ~ "(void delegate(ref Support.Sink) builder)"
        ~ "{ " ~ field ~ " = Support.Content.ofBuilder(builder); return this; }"
        ~ "final ref Support.Content " ~ slotName ~ "() return { return " ~ field ~ "; }"
        ~ "final bool has" ~ suffix ~ "() const { return " ~ field ~ ".isEmpty == false; }";
}

private string rendersManyContentCode(string slotName) pure nothrow @safe {
    immutable suffix = capitalizeSlotName(slotName);
    immutable field = slotName ~ "Slot_";

    return "private Support.Content[] " ~ field ~ ";"
        ~ "final typeof(this) with" ~ suffix ~ "(string text)"
        ~ "{ " ~ field ~ " ~= Support.Content.ofText(text); return this; }"
        ~ "final typeof(this) with" ~ suffix ~ "(Support.SafeString markup)"
        ~ "{ " ~ field ~ " ~= Support.Content.ofMarkup(markup); return this; }"
        ~ "final typeof(this) with" ~ suffix ~ "(void delegate(ref Support.Sink) builder)"
        ~ "{ " ~ field ~ " ~= Support.Content.ofBuilder(builder); return this; }"
        ~ "final Support.Content[] " ~ slotName ~ "() { return " ~ field ~ "; }"
        ~ "final bool has" ~ suffix ~ "() const { return " ~ field ~ ".length != 0; }";
}

/// Builds the `withX` / `hasX` suffix from a slot name.
string capitalizeSlotName(string slotName) pure nothrow @safe {
    if (slotName.length == 0)
        return slotName;

    if (slotName[0] < 'a' || slotName[0] > 'z')
        return slotName;

    return cast(char)(slotName[0] - ('a' - 'A')) ~ slotName[1 .. $];
}

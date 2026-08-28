module view_component.base;

import std.exception : assumeUnique;

static import view_component.sink;

import view_component.escape : SafeString, escapeHtmlInto;

/**
 * The output buffer every component renders into. Nesting, slots and content
 * blocks all append to the caller's sink, so a whole component tree costs one
 * buffer rather than one string per node.
 */
alias Sink = view_component.sink.Sink;

/**
 * Caller-supplied markup: the content block, and the payload of content slots.
 *
 * Text is escaped on write, markup is trusted, and a builder writes straight
 * into the sink without an intermediate string.
 */
struct Content {
    private enum Kind {
        empty,
        text,
        markup,
        builder
    }

    private Kind kind = Kind.empty;
    private string payload;
    private void delegate(ref Sink) builder;

    /// Content built from plain text; escaped when written.
    static Content ofText(string text) pure nothrow @safe {
        Content content;
        content.kind = Kind.text;
        content.payload = text;

        return content;
    }

    /// Content built from trusted markup; written verbatim.
    static Content ofMarkup(SafeString markup) pure nothrow @safe {
        Content content;
        content.kind = Kind.markup;
        content.payload = markup.value;

        return content;
    }

    /// Content built lazily by a delegate writing into the sink.
    static Content ofBuilder(void delegate(ref Sink) builder) pure nothrow @safe {
        Content content;
        content.kind = Kind.builder;
        content.builder = builder;

        return content;
    }

    bool isEmpty() const pure nothrow @safe @nogc {
        return kind == Kind.empty;
    }

    void writeInto(ref Sink sink) {
        final switch (kind) {
            case Kind.empty:
                return;
            case Kind.text:
                escapeHtmlInto(sink, payload);
                return;
            case Kind.markup:
                sink.put(payload);
                return;
            case Kind.builder:
                if (builder !is null)
                    builder(sink);
                return;
        }
    }
}

/**
 * Base class for all components.
 *
 * Subclasses supply `renderInto` by mixing in `Template`, and expose their data
 * as ordinary public fields — template expressions resolve against them by
 * lexical scope, because the compiled template body is mixed into this method.
 */
abstract class ViewComponent {
    private Content contentSlot;

    protected abstract void renderInto(ref Sink sink);

    /// Renders into an existing sink.
    final void renderInSink(ref Sink sink) {
        renderInto(sink);
    }

    /// Renders standalone and returns the markup.
    final string render() {
        Sink sink;
        renderInSink(sink);

        // The sink dies with this call, so nothing else can observe the buffer.
        return assumeUnique(sink.data);
    }

    /// Sets the content block from plain text, escaped on render.
    final Self withContent(this Self)(string text) {
        contentSlot = Content.ofText(text);

        return cast(Self) this;
    }

    /// Sets the content block from trusted markup.
    final Self withContent(this Self)(SafeString markup) {
        contentSlot = Content.ofMarkup(markup);

        return cast(Self) this;
    }

    /// Sets the content block from a delegate writing into the sink.
    final Self withContent(this Self)(void delegate(ref Sink) builder) {
        contentSlot = Content.ofBuilder(builder);

        return cast(Self) this;
    }

    /// The caller-supplied content block, for use as `<%= content %>`.
    protected final ref Content content() return {
        return contentSlot;
    }

    /// Whether a content block was supplied.
    protected final bool hasContent() const {
        return !contentSlot.isEmpty;
    }
}

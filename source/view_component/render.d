module view_component.render;

import std.range : ElementType;
import std.traits : isArray, isSomeChar;

import view_component.base : Content, Sink, ViewComponent;
import view_component.escape : SafeString, escapeHtmlInto;

/**
 * Writes one `<%= %>` expression into the sink.
 *
 * Dispatch is resolved at compile time: components render in place, safe markup
 * and content go through verbatim, and everything else is stringified and
 * escaped. This is what makes `<%= card %>`, `<%= content %>` and
 * `<%= title %>` all mean the obvious thing.
 */
void emit(Value)(ref Sink sink, auto ref Value value) {
    static if (is(Value : SafeString)) {
        sink.put(value.value);
    }
    else static if (is(Value == Content)) {
        value.writeInto(sink);
    }
    else static if (is(Value : ViewComponent)) {
        if (value !is null)
            value.renderInSink(sink);
    }
    else static if (isArray!Value && is(ElementType!Value : ViewComponent)) {
        foreach (component; value)
            if (component !is null)
                component.renderInSink(sink);
    }
    else static if (isArray!Value && is(ElementType!Value == Content)) {
        foreach (ref item; value)
            item.writeInto(sink);
    }
    else static if (is(Value : const(char)[])) {
        escapeHtmlInto(sink, value);
    }
    else static if (isSomeChar!Value) {
        import std.utf : encode;

        char[4] buffer;
        immutable used = encode(buffer, value);

        escapeHtmlInto(sink, buffer[0 .. used]);
    }
    else {
        import std.conv : to;

        escapeHtmlInto(sink, value.to!string);
    }
}

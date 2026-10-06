module view_component.render;

import std.range : ElementType;
import std.traits : isArray, isIntegral, isSigned, isSomeChar;

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
    else static if (isIntegral!Value && !is(Value == enum)) {
        putDecimalInto(sink, value);
    }
    else {
        import std.conv : to;

        escapeHtmlInto(sink, value.to!string);
    }
}

/**
 * Writes an integer's decimal form into the sink.
 *
 * The generic branch above reaches `to!string`, which allocates a GC string per
 * value and then walks it looking for `&<>"'` that a digit can never be. Digits
 * are built backwards into a stack buffer instead and handed over in one `put`.
 * Twenty bytes covers both extremes: `18446744073709551615` and
 * `-9223372036854775808`.
 */
private void putDecimalInto(Value)(ref Sink sink, Value value) {
    char[20] digits = void;
    size_t cursor = digits.length;

    static if (isSigned!Value) {
        immutable negative = value < 0;
        // Negating in `ulong` keeps `Value.min` in range, where negating in the
        // signed type would overflow.
        ulong magnitude = negative ? -cast(ulong) value : cast(ulong) value;
    }
    else {
        enum negative = false;
        ulong magnitude = value;
    }

    do {
        digits[--cursor] = cast(char)('0' + magnitude % 10);
        magnitude /= 10;
    }
    while (magnitude != 0);

    if (negative)
        digits[--cursor] = '-';

    sink.put(digits[cursor .. $]);
}

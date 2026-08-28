module view_component.escape;

/**
 * Markup that has already been escaped, or that is trusted verbatim.
 *
 * `emit` writes a `SafeString` straight into the sink, so this is the single
 * opt-out from automatic escaping.
 */
struct SafeString {
    string value;
}

/// Marks `markup` as trusted so it is emitted without escaping.
SafeString raw(string markup) pure nothrow @safe @nogc {
    return SafeString(markup);
}

/// ditto
SafeString raw(Value)(Value value)
if (!is(Value : const(char)[])) {
    import std.conv : to;

    return SafeString(value.to!string);
}

/**
 * HTML-escapes `input` straight into `sink`, one unescaped run at a time.
 *
 * The allocating form below has to size a buffer before it can fill one, so it
 * walks the input twice and leaves a throwaway array behind for every value
 * that needs escaping. Writing runs into the caller's buffer costs one pass and
 * nothing on the heap, which is what `emit` uses for every `<%= %>`.
 */
void escapeHtmlInto(Sink)(ref Sink sink, const(char)[] input) {
    size_t runStart = 0;

    foreach (index, character; input) {
        immutable replacement = replacementFor(character);

        if (replacement.length == 0)
            continue;

        if (index > runStart)
            sink.put(input[runStart .. index]);

        sink.put(replacement);
        runStart = index + 1;
    }

    if (runStart == 0)
        sink.put(input);
    else if (runStart < input.length)
        sink.put(input[runStart .. $]);
}

/**
 * HTML-escapes `input`, returning the input slice untouched when nothing needs
 * escaping. Allocates at most once: the replacement length is measured first,
 * then written into an exactly sized buffer.
 */
const(char)[] escapeHtml(const(char)[] input) pure nothrow @safe {
    size_t extraBytes = 0;

    foreach (character; input) {
        immutable replacement = replacementFor(character);

        if (replacement.length != 0)
            extraBytes += replacement.length - 1;
    }

    if (extraBytes == 0)
        return input;

    auto escaped = new char[input.length + extraBytes];
    size_t cursor = 0;

    foreach (character; input) {
        immutable replacement = replacementFor(character);

        if (replacement.length == 0) {
            escaped[cursor] = character;
            cursor++;
            continue;
        }

        escaped[cursor .. cursor + replacement.length] = replacement[];
        cursor += replacement.length;
    }

    return escaped;
}

private string replacementFor(char character) pure nothrow @safe @nogc {
    switch (character) {
        case '&': return "&amp;";
        case '<': return "&lt;";
        case '>': return "&gt;";
        case '"': return "&quot;";
        case '\'': return "&#39;";
        default: return null;
    }
}

/**
 * Escapes `text` so it can be embedded in a generated D string literal. Used by
 * the template compilers when emitting literal markup.
 */
string escapeDStringLiteral(const(char)[] text) pure nothrow @safe {
    string escaped;

    foreach (character; text) {
        switch (character) {
            case '\\': escaped ~= `\\`; break;
            case '"': escaped ~= `\"`; break;
            case '\n': escaped ~= `\n`; break;
            case '\r': escaped ~= `\r`; break;
            case '\t': escaped ~= `\t`; break;
            case '\0': escaped ~= `\x00`; break;
            default:
                if (character < 0x20)
                    escaped ~= `\x` ~ hexDigits(character);
                else
                    escaped ~= character;
        }
    }

    return escaped;
}

private string hexDigits(char character) pure nothrow @safe {
    static immutable string digits = "0123456789abcdef";

    return [digits[(character >> 4) & 0x0F], digits[character & 0x0F]].idup;
}

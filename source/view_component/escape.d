module view_component.escape;

/**
 * Markup that has already been escaped, or that is trusted verbatim.
 *
 * `emit` writes a `SafeString` straight into the sink, so this is the single
 * opt-out from automatic escaping.
 */
struct SafeString
{
    string value;
}

/// Marks `markup` as trusted so it is emitted without escaping.
SafeString raw(string markup) pure nothrow @safe @nogc
{
    return SafeString(markup);
}

/// ditto
SafeString raw(Value)(Value value)
if (!is(Value : const(char)[]))
{
    import std.conv : to;

    return SafeString(value.to!string);
}

/**
 * HTML-escapes `input`, returning the input slice untouched when nothing needs
 * escaping. Allocates at most once: the replacement length is measured first,
 * then written into an exactly sized buffer.
 */
const(char)[] escapeHtml(const(char)[] input) pure nothrow @safe
{
    size_t extraBytes = 0;

    foreach (character; input)
    {
        immutable replacement = replacementFor(character);

        if (replacement.length != 0)
            extraBytes += replacement.length - 1;
    }

    if (extraBytes == 0)
        return input;

    auto escaped = new char[input.length + extraBytes];
    size_t cursor = 0;

    foreach (character; input)
    {
        immutable replacement = replacementFor(character);

        if (replacement.length == 0)
        {
            escaped[cursor] = character;
            cursor++;
            continue;
        }

        escaped[cursor .. cursor + replacement.length] = replacement[];
        cursor += replacement.length;
    }

    return escaped;
}

private string replacementFor(char character) pure nothrow @safe @nogc
{
    switch (character)
    {
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
string escapeDStringLiteral(const(char)[] text) pure nothrow @safe
{
    string escaped;

    foreach (character; text)
    {
        switch (character)
        {
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

private string hexDigits(char character) pure nothrow @safe
{
    static immutable string digits = "0123456789abcdef";

    return [digits[(character >> 4) & 0x0F], digits[character & 0x0F]].idup;
}

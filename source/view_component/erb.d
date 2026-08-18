module view_component.erb;

import view_component.escape : escapeDStringLiteral;

/**
 * Compiles ERB source into D statements.
 *
 * Runs at CTFE: the result is fed to a string mixin inside the component's
 * `renderInto`, so template expressions resolve against the component's own
 * members and a malformed template is a compile error rather than a 500.
 *
 * Recognised tags:
 *   `<% code %>`    statement, emitted verbatim
 *   `<%= expr %>`   expression, stringified and HTML-escaped
 *   `<%== expr %>`  expression, emitted verbatim
 *   `<%# text %>`   comment, discarded
 *   `<%%`           a literal `<%`
 *   `<%-` / `-%>`   trim preceding indentation / the following newline
 */
string compileErb(string source, string templateName, string sinkIdent)
{
    string code;
    string literal;
    size_t cursor = 0;

    void flushLiteral()
    {
        if (literal.length == 0)
            return;

        code ~= sinkIdent ~ `.put("` ~ escapeDStringLiteral(literal) ~ "\");\n";
        literal = null;
    }

    while (cursor < source.length)
    {
        immutable tagOpen = indexOfTagOpen(source, cursor);

        if (tagOpen == size_t.max)
        {
            literal ~= source[cursor .. $];
            break;
        }

        literal ~= source[cursor .. tagOpen];

        if (tagOpen + 2 < source.length && source[tagOpen + 2] == '%')
        {
            literal ~= "<%";
            cursor = tagOpen + 3;
            continue;
        }

        size_t bodyStart = tagOpen + 2;
        bool trimLeft = false;

        if (bodyStart < source.length && source[bodyStart] == '-')
        {
            trimLeft = true;
            bodyStart++;
        }

        auto kind = TagKind.statement;

        if (bodyStart < source.length && source[bodyStart] == '=')
        {
            bodyStart++;
            kind = TagKind.escapedOutput;

            if (bodyStart < source.length && source[bodyStart] == '=')
            {
                bodyStart++;
                kind = TagKind.rawOutput;
            }
        }
        else if (bodyStart < source.length && source[bodyStart] == '#')
        {
            bodyStart++;
            kind = TagKind.comment;
        }

        immutable tagClose = indexOfTagClose(source, bodyStart);

        if (tagClose == size_t.max)
            assert(false, templateName ~ ":" ~ lineNumberAt(source, tagOpen)
                ~ ": unterminated template tag, expected a closing `%>`");

        size_t bodyEnd = tagClose;
        bool trimRight = false;

        if (bodyEnd > bodyStart && source[bodyEnd - 1] == '-')
        {
            trimRight = true;
            bodyEnd--;
        }

        if (trimLeft)
            literal = stripTrailingInlineSpace(literal);

        flushLiteral();

        immutable tagBody = source[bodyStart .. bodyEnd];

        final switch (kind)
        {
            case TagKind.statement:
                if (hasNonSpace(tagBody))
                    code ~= tagBody ~ "\n";
                break;

            case TagKind.escapedOutput:
                requireExpression(tagBody, templateName, source, tagOpen, "<%=");
                code ~= "__vcEmit(" ~ tagBody ~ ");\n";
                break;

            case TagKind.rawOutput:
                requireExpression(tagBody, templateName, source, tagOpen, "<%==");
                code ~= "__vcEmitRaw(" ~ tagBody ~ ");\n";
                break;

            case TagKind.comment:
                break;
        }

        cursor = tagClose + 2;

        if (trimRight)
            cursor = skipOneNewline(source, cursor);
    }

    flushLiteral();

    return code;
}

private enum TagKind
{
    statement,
    escapedOutput,
    rawOutput,
    comment
}

private void requireExpression(string tagBody, string templateName, string source, size_t tagOpen,
    string opener)
{
    if (!hasNonSpace(tagBody))
        assert(false, templateName ~ ":" ~ lineNumberAt(source, tagOpen)
            ~ ": empty `" ~ opener ~ "` tag, expected an expression");
}

private size_t indexOfTagOpen(string source, size_t from) pure nothrow @safe
{
    if (source.length < 2)
        return size_t.max;

    foreach (index; from .. source.length - 1)
        if (source[index] == '<' && source[index + 1] == '%')
            return index;

    return size_t.max;
}

private size_t indexOfTagClose(string source, size_t from) pure nothrow @safe
{
    if (source.length < 2)
        return size_t.max;

    foreach (index; from .. source.length - 1)
        if (source[index] == '%' && source[index + 1] == '>')
            return index;

    return size_t.max;
}

private string stripTrailingInlineSpace(string literal) pure nothrow @safe
{
    size_t end = literal.length;

    while (end > 0 && (literal[end - 1] == ' ' || literal[end - 1] == '\t'))
        end--;

    return literal[0 .. end];
}

private size_t skipOneNewline(string source, size_t cursor) pure nothrow @safe
{
    if (cursor < source.length && source[cursor] == '\r')
        cursor++;

    if (cursor < source.length && source[cursor] == '\n')
        cursor++;

    return cursor;
}

private bool hasNonSpace(string text) pure nothrow @safe
{
    foreach (character; text)
        if (character != ' ' && character != '\t' && character != '\n' && character != '\r')
            return true;

    return false;
}

private string lineNumberAt(string source, size_t offset) pure @safe
{
    import std.conv : to;

    size_t line = 1;

    foreach (index; 0 .. offset)
        if (source[index] == '\n')
            line++;

    return line.to!string;
}

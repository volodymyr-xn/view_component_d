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
 *   `<%-` / `-%>`   explicitly trim indentation / the following newline
 *
 * A statement or comment tag alone on its line takes the whole line with it,
 * so control flow costs no blank lines in the output. `<%-` and `-%>` are only
 * needed for a tag that shares its line with markup.
 */
string compileErb(string source, string templateName, string sinkIdent) {
    string code;
    string literal;
    size_t cursor = 0;
    size_t literalBytes = 0;

    void flushLiteral() {
        if (literal.length == 0)
            return;

        literalBytes += literal.length;
        code ~= sinkIdent ~ `.put("` ~ escapeDStringLiteral(literal) ~ "\");\n";
        literal = null;
    }

    while (cursor < source.length) {
        immutable tagOpen = indexOfTagOpen(source, cursor);

        if (tagOpen == size_t.max) {
            literal ~= source[cursor .. $];
            break;
        }

        literal ~= source[cursor .. tagOpen];

        if (tagOpen + 2 < source.length && source[tagOpen + 2] == '%') {
            literal ~= "<%";
            cursor = tagOpen + 3;
            continue;
        }

        size_t bodyStart = tagOpen + 2;
        bool trimLeft = false;

        if (bodyStart < source.length && source[bodyStart] == '-') {
            trimLeft = true;
            bodyStart++;
        }

        auto kind = TagKind.statement;

        if (bodyStart < source.length && source[bodyStart] == '=') {
            bodyStart++;
            kind = TagKind.escapedOutput;

            if (bodyStart < source.length && source[bodyStart] == '=') {
                bodyStart++;
                kind = TagKind.rawOutput;
            }
        }
        else if (bodyStart < source.length && source[bodyStart] == '#') {
            bodyStart++;
            kind = TagKind.comment;
        }

        immutable tagClose = indexOfTagClose(source, bodyStart);

        if (tagClose == size_t.max)
            assert(false, templateName ~ ":" ~ lineNumberAt(source, tagOpen)
                ~ ": unterminated template tag, expected a closing `%>`");

        size_t bodyEnd = tagClose;
        bool trimRight = false;

        if (bodyEnd > bodyStart && source[bodyEnd - 1] == '-') {
            trimRight = true;
            bodyEnd--;
        }

        // A block tag alone on its line takes the whole line with it, so
        // control flow costs no blank lines in the output and `<%-` / `-%>` are
        // only needed to trim a tag sharing its line with markup.
        immutable isBlockTag = kind == TagKind.statement || kind == TagKind.comment;
        immutable standsAlone = isBlockTag && startsLine(literal)
            && endsLine(source, tagClose + 2);

        if (trimLeft || standsAlone)
            literal = stripTrailingInlineSpace(literal);

        flushLiteral();

        immutable tagBody = source[bodyStart .. bodyEnd];

        final switch (kind) {
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

        if (trimRight || standsAlone)
            cursor = skipToNextLine(source, cursor);
    }

    flushLiteral();

    // Every literal chunk's length is known here, so the markup this template
    // contributes can be claimed in one call rather than discovered by the
    // sink doubling its way up from 512 bytes. Interpolated values are not
    // counted; the reserve is a floor, not a prediction.
    if (literalBytes != 0) {
        import std.conv : to;

        code = sinkIdent ~ ".reserve(" ~ sinkIdent ~ ".length + "
            ~ literalBytes.to!string ~ ");\n" ~ code;
    }

    return code;
}

private enum TagKind {
    statement,
    escapedOutput,
    rawOutput,
    comment
}

private void requireExpression(string tagBody, string templateName, string source, size_t tagOpen,
    string opener) {
    if (!hasNonSpace(tagBody))
        assert(false, templateName ~ ":" ~ lineNumberAt(source, tagOpen)
            ~ ": empty `" ~ opener ~ "` tag, expected an expression");
}

private size_t indexOfTagOpen(string source, size_t from) pure nothrow @safe {
    if (source.length < 2)
        return size_t.max;

    foreach (index; from .. source.length - 1)
        if (source[index] == '<' && source[index + 1] == '%')
            return index;

    return size_t.max;
}

private size_t indexOfTagClose(string source, size_t from) pure nothrow @safe {
    if (source.length < 2)
        return size_t.max;

    foreach (index; from .. source.length - 1)
        if (source[index] == '%' && source[index + 1] == '>')
            return index;

    return size_t.max;
}

private string stripTrailingInlineSpace(string literal) pure nothrow @safe {
    size_t end = literal.length;

    while (end > 0 && (literal[end - 1] == ' ' || literal[end - 1] == '\t'))
        end--;

    return literal[0 .. end];
}

/// Whether only blank space separates the tag from the start of its line.
private bool startsLine(string literal) pure nothrow @safe {
    foreach_reverse (character; literal) {
        if (character == '\n')
            return true;

        if (character != ' ' && character != '\t' && character != '\r')
            return false;
    }

    return true;
}

/// Whether only blank space separates `from` from the end of its line.
private bool endsLine(string source, size_t from) pure nothrow @safe {
    foreach (index; from .. source.length) {
        if (source[index] == '\n')
            return true;

        if (source[index] != ' ' && source[index] != '\t' && source[index] != '\r')
            return false;
    }

    return true;
}

private size_t skipToNextLine(string source, size_t cursor) pure nothrow @safe {
    while (cursor < source.length && (source[cursor] == ' ' || source[cursor] == '\t'))
        cursor++;

    if (cursor < source.length && source[cursor] == '\r')
        cursor++;

    if (cursor < source.length && source[cursor] == '\n')
        cursor++;

    return cursor;
}

private bool hasNonSpace(string text) pure nothrow @safe {
    foreach (character; text)
        if (character != ' ' && character != '\t' && character != '\n' && character != '\r')
            return true;

    return false;
}

private string lineNumberAt(string source, size_t offset) pure @safe {
    import std.conv : to;

    size_t line = 1;

    foreach (index; 0 .. offset)
        if (source[index] == '\n')
            line++;

    return line.to!string;
}

module view_component.testing;

import core.exception : AssertError;

import view_component.base : ViewComponent;

/// Renders a component to markup for assertions.
string renderToString(ViewComponent component) {
    return component.render();
}

/// Asserts the rendered markup contains `needle`.
void assertIncludes(string haystack, string needle, string file = __FILE__,
    size_t line = __LINE__) {
    if (indexOfSubstring(haystack, needle) != size_t.max)
        return;

    throw new AssertError("expected rendered markup to include `" ~ needle ~ "`, got:\n"
        ~ haystack, file, line);
}

/// Asserts the rendered markup does not contain `needle`.
void assertExcludes(string haystack, string needle, string file = __FILE__,
    size_t line = __LINE__) {
    if (indexOfSubstring(haystack, needle) == size_t.max)
        return;

    throw new AssertError("expected rendered markup not to include `" ~ needle ~ "`, got:\n"
        ~ haystack, file, line);
}

/// Asserts the component renders exactly `expected`.
void assertRendersEqual(ViewComponent component, string expected, string file = __FILE__,
    size_t line = __LINE__) {
    immutable actual = component.render();

    if (actual == expected)
        return;

    throw new AssertError("expected:\n" ~ expected ~ "\nactual:\n" ~ actual, file, line);
}

/**
 * Asserts the component renders `expected` ignoring differences in runs of
 * whitespace, so template indentation does not make tests brittle.
 */
void assertRendersEqualNormalized(ViewComponent component, string expected,
    string file = __FILE__, size_t line = __LINE__) {
    immutable actual = component.render();

    if (normalizeWhitespace(actual) == normalizeWhitespace(expected))
        return;

    throw new AssertError("expected (normalized):\n" ~ normalizeWhitespace(expected)
        ~ "\nactual (normalized):\n" ~ normalizeWhitespace(actual), file, line);
}

/**
 * Asserts the markup contains an opening `tagName` tag carrying every given
 * attribute. Attribute values match on substring, so a single class in a long
 * class list is enough.
 */
void assertHasElement(string haystack, string tagName, string[string] attributes,
    string file = __FILE__, size_t line = __LINE__) {
    if (hasElement(haystack, tagName, attributes))
        return;

    throw new AssertError("expected a `<" ~ tagName ~ ">` with " ~ describe(attributes)
        ~ ", got:\n" ~ haystack, file, line);
}

/// Whether `haystack` holds an opening `tagName` tag carrying every attribute.
bool hasElement(string haystack, string tagName, string[string] attributes) {
    size_t cursor = 0;

    while (cursor < haystack.length) {
        immutable tagStart = indexOfSubstring(haystack[cursor .. $], "<" ~ tagName);

        if (tagStart == size_t.max)
            return false;

        immutable absoluteStart = cursor + tagStart;
        immutable afterName = absoluteStart + 1 + tagName.length;

        if (afterName >= haystack.length || !isTagNameBoundary(haystack[afterName])) {
            cursor = afterName;
            continue;
        }

        immutable tagEnd = indexOfSubstring(haystack[afterName .. $], ">");

        if (tagEnd == size_t.max)
            return false;

        immutable attributeText = haystack[afterName .. afterName + tagEnd];

        if (containsAllAttributes(attributeText, attributes))
            return true;

        cursor = afterName + tagEnd + 1;
    }

    return false;
}

private bool containsAllAttributes(string attributeText, string[string] attributes) {
    foreach (name, value; attributes) {
        immutable namePosition = indexOfSubstring(attributeText, name ~ "=");

        if (namePosition == size_t.max)
            return false;

        immutable remainder = attributeText[namePosition + name.length + 1 .. $];

        if (indexOfSubstring(remainder, value) == size_t.max)
            return false;
    }

    return true;
}

private bool isTagNameBoundary(char character) pure nothrow @safe @nogc {
    return character == ' ' || character == '>' || character == '\t' || character == '\n'
        || character == '\r' || character == '/';
}

private string describe(string[string] attributes) {
    string described;

    foreach (name, value; attributes) {
        if (described.length != 0)
            described ~= ", ";

        described ~= name ~ "=\"" ~ value ~ "\"";
    }

    return described.length == 0 ? "no attributes" : described;
}

private size_t indexOfSubstring(const(char)[] haystack, const(char)[] needle) pure nothrow @safe {
    if (needle.length == 0)
        return 0;

    if (needle.length > haystack.length)
        return size_t.max;

    foreach (start; 0 .. haystack.length - needle.length + 1)
        if (haystack[start .. start + needle.length] == needle)
            return start;

    return size_t.max;
}

private string normalizeWhitespace(string text) pure nothrow @safe {
    string normalized;
    bool inWhitespace = false;

    foreach (character; text) {
        immutable isSpace = character == ' ' || character == '\t' || character == '\n'
            || character == '\r';

        if (isSpace) {
            inWhitespace = true;
            continue;
        }

        if (inWhitespace && normalized.length != 0)
            normalized ~= ' ';

        inWhitespace = false;
        normalized ~= character;
    }

    return normalized;
}

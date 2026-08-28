module view_component.discovery;

/**
 * Converts a class name to the snake_case stem used to locate its sidecar
 * template: `ButtonComponent` -> `button_component`, `HTMLBlockComponent` ->
 * `html_block_component`.
 */
string toSnakeCase(string identifier) pure nothrow @safe {
    string snake;

    foreach (index, character; identifier) {
        if (!isUpper(character)) {
            snake ~= character;
            continue;
        }

        immutable followsLowerOrDigit = index > 0 && !isUpper(identifier[index - 1]);
        immutable startsWord = index > 0 && index + 1 < identifier.length
            && isUpper(identifier[index - 1]) && isLower(identifier[index + 1]);

        if (followsLowerOrDigit || startsWord)
            snake ~= '_';

        snake ~= cast(char)(character + ('a' - 'A'));
    }

    return snake;
}

private bool isUpper(char character) pure nothrow @safe @nogc {
    return character >= 'A' && character <= 'Z';
}

private bool isLower(char character) pure nothrow @safe @nogc {
    return character >= 'a' && character <= 'z';
}

/**
 * Every path a sidecar template may live at, in resolution order.
 *
 * A component always lives in a directory named after itself — there is no
 * layout where a template sits loose beside its class:
 *
 *   app/components/button_component/button_component.html.erb
 *
 * Sub-components nest the same way, each in its own directory inside its
 * parent's, which the module's package path already mirrors:
 *
 *   app/components/sidebar_component/sidebar_link_component/sidebar_link_component.html.erb
 */
string[] templateCandidates(string stem, string modulePath) pure nothrow @safe {
    string[] candidates = [stem ~ "/" ~ stem ~ ".html.erb"];

    foreach (directory; packageDirectories(modulePath))
        candidates ~= directory ~ "/" ~ stem ~ ".html.erb";

    candidates ~= stem ~ "/" ~ stem ~ ".dt";

    foreach (directory; packageDirectories(modulePath))
        candidates ~= directory ~ "/" ~ stem ~ ".dt";

    return candidates;
}

/// Directory paths from a module's package path, most specific first.
private string[] packageDirectories(string modulePath) pure nothrow @safe {
    string[] segments;
    size_t segmentStart = 0;

    foreach (index, character; modulePath) {
        if (character != '.')
            continue;

        segments ~= modulePath[segmentStart .. index];
        segmentStart = index + 1;
    }

    string[] directories;

    foreach (from; 0 .. segments.length) {
        string joined;

        foreach (segment; segments[from .. $])
            joined = joined.length == 0 ? segment : joined ~ "/" ~ segment;

        directories ~= joined;
    }

    return directories;
}

/**
 * Resolves the sidecar template for a component whose snake_case stem is
 * `stem` and whose module is `modulePath`.
 *
 * Existence is probed with `__traits(compiles, import(...))`, so an unresolved
 * template fails at compile time naming every candidate it looked for.
 */
template templatePathFor(string stem, string modulePath = null) {
    enum candidatePaths = templateCandidates(stem, modulePath);

    template firstResolvable(size_t index) {
        static if (index >= candidatePaths.length)
            enum firstResolvable = null;
        else static if (__traits(compiles, import(candidatePaths[index])))
            enum firstResolvable = candidatePaths[index];
        else
            enum firstResolvable = firstResolvable!(index + 1);
    }

    static if (firstResolvable!0 !is null)
        enum templatePathFor = firstResolvable!0;
    else
        static assert(false, missingTemplateMessage(stem, candidatePaths));
}

private string missingTemplateMessage(string stem, string[] candidatePaths) pure nothrow @safe {
    string message = "view_component: no sidecar template found for `" ~ stem ~ "`.\n"
        ~ "  Every component lives in a directory named after itself; a template\n"
        ~ "  loose beside its class is not a supported layout.\n"
        ~ "  Looked for, relative to every string import path:\n";

    foreach (candidate; candidatePaths)
        message ~= "    " ~ candidate ~ "\n";

    return message
        ~ "  Add the component directory to `stringImportPaths` in your dub recipe"
        ~ " (or pass -J to the compiler).";
}

/// Whether `path` should be compiled by the Diet backend rather than the ERB one.
bool isDietPath(string path) pure nothrow @safe @nogc {
    return path.length >= 3 && path[$ - 3 .. $] == ".dt";
}

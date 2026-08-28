module view_component.hooks;

/**
 * Render hooks are found by name on the concrete component rather than by
 * overriding a base method, so declaring one costs no `override` and no
 * `protected`:
 *
 *   void beforeRender() { ... }
 *   bool shouldRender() { ... }
 *
 * The cost of dropping `override` is that the compiler no longer catches a
 * misspelled hook — it would simply never run. `guardHookNames` puts that check
 * back: any member whose name is a near miss for a hook is a compile error.
 */
enum hookNames = ["beforeRender", "shouldRender"];

/// Fails the build when a component declares something that looks like a typo'd hook.
template guardHookNames(Component) {
    static foreach (member; __traits(allMembers, Component))
        static foreach (hook; hookNames)
            static assert(!isNearMiss(member, hook),
                "view_component: `" ~ Component.stringof ~ "." ~ member
                ~ "` looks like a misspelling of the `" ~ hook ~ "` render hook,"
                ~ " which would leave it silently uncalled. Rename it to `" ~ hook
                ~ "`, or to something less similar if it is unrelated.");

    enum guardHookNames = true;
}

/// Whether `candidate` is close enough to `hook` to be a likely typo.
bool isNearMiss(string candidate, string hook) pure nothrow @safe {
    if (candidate == hook)
        return false;

    if (candidate.length == 0)
        return false;

    if (equalIgnoringAsciiCase(candidate, hook))
        return true;

    return withinOneEdit(candidate, hook);
}

private bool equalIgnoringAsciiCase(string left, string right) pure nothrow @safe {
    if (left.length != right.length)
        return false;

    foreach (index; 0 .. left.length)
        if (toLowerAscii(left[index]) != toLowerAscii(right[index]))
            return false;

    return true;
}

private char toLowerAscii(char character) pure nothrow @safe @nogc {
    return character >= 'A' && character <= 'Z'
        ? cast(char)(character + ('a' - 'A'))
        : character;
}

/// One insertion, deletion or substitution apart.
private bool withinOneEdit(string left, string right) pure nothrow @safe {
    immutable lengthDelta = cast(long) left.length - cast(long) right.length;

    if (lengthDelta > 1 || lengthDelta < -1)
        return false;

    size_t leftIndex = 0;
    size_t rightIndex = 0;
    bool spentEdit = false;

    while (leftIndex < left.length && rightIndex < right.length) {
        if (left[leftIndex] == right[rightIndex]) {
            leftIndex++;
            rightIndex++;
            continue;
        }

        if (spentEdit)
            return false;

        spentEdit = true;

        if (lengthDelta > 0)
            leftIndex++;
        else if (lengthDelta < 0)
            rightIndex++;
        else {
            leftIndex++;
            rightIndex++;
        }
    }

    return true;
}

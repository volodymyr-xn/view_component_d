module tests.main;

/**
 * druntime runs every `unittest` block before `main`, so reaching this point
 * means the whole suite passed.
 */
void main() {
    import std.stdio : writeln;

    writeln("view_component_d: all unit tests passed");
}

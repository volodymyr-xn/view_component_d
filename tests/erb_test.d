module tests.erb_test;

import view_component.erb : compileErb;

private string compile(string source)
{
    return compileErb(source, "fixture.html.erb", "sink");
}

unittest
{
    assert(compile("<p>hi</p>") == "sink.put(\"<p>hi</p>\");\n");
}

unittest
{
    assert(compile("<%= label %>") == "__vcEmit( label );\n");
}

unittest
{
    assert(compile("<%== markup %>") == "__vcEmitRaw( markup );\n");
}

unittest
{
    assert(compile("<% doThing(); %>") == " doThing(); \n");
}

unittest
{
    assert(compile("a<%# note %>b") == "sink.put(\"a\");\nsink.put(\"b\");\n");
}

unittest
{
    assert(compile("<%%= literal %>") == "sink.put(\"<%= literal %>\");\n");
}

unittest
{
    immutable trimmed = compile("  <%- x(); -%>\nnext");
    assert(trimmed == " x(); \nsink.put(\"next\");\n", trimmed);
}

unittest
{
    immutable escaped = compile("a\"b\\c\nd\te");
    assert(escaped == "sink.put(\"a\\\"b\\\\c\\nd\\te\");\n", escaped);
}

unittest
{
    enum compiledAtCompileTime = compileErb("<p><%= x %></p>", "ctfe.html.erb", "sink");
    static assert(compiledAtCompileTime.length != 0);
}

unittest
{
    static assert(!__traits(compiles, {
        enum broken = compileErb("<%= unterminated", "bad.html.erb", "sink");
    }));
}

unittest
{
    static assert(!__traits(compiles, {
        enum empty = compileErb("<%=   %>", "bad.html.erb", "sink");
    }));
}

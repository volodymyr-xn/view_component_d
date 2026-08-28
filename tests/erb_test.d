module tests.erb_test;

import view_component.erb : compileErb;

private string compile(string source) {
    return compileErb(source, "fixture.html.erb", "sink");
}

unittest {
    assert(compile("<p>hi</p>") == "sink.put(\"<p>hi</p>\");\n");
}

unittest {
    assert(compile("<%= label %>") == "__vcEmit( label );\n");
}

unittest {
    assert(compile("<%== markup %>") == "__vcEmitRaw( markup );\n");
}

unittest {
    assert(compile("<% doThing(); %>") == " doThing(); \n");
}

unittest {
    assert(compile("a<%# note %>b") == "sink.put(\"a\");\nsink.put(\"b\");\n");
}

unittest {
    assert(compile("<%%= literal %>") == "sink.put(\"<%= literal %>\");\n");
}

unittest {
    immutable trimmed = compile("  <%- x(); -%>\nnext");
    assert(trimmed == " x(); \nsink.put(\"next\");\n", trimmed);
}

unittest {
    immutable escaped = compile("a\"b\\c\nd\te");
    assert(escaped == "sink.put(\"a\\\"b\\\\c\\nd\\te\");\n", escaped);
}

unittest {
    enum compiledAtCompileTime = compileErb("<p><%= x %></p>", "ctfe.html.erb", "sink");
    static assert(compiledAtCompileTime.length != 0);
}

unittest {
    static assert(!__traits(compiles, {
        enum broken = compileErb("<%= unterminated", "bad.html.erb", "sink");
    }));
}

unittest {
    static assert(!__traits(compiles, {
        enum empty = compileErb("<%=   %>", "bad.html.erb", "sink");
    }));
}

unittest {
    // A block tag alone on its line takes the whole line, no `-` needed.
    immutable auto_ = compile("  <% x(); %>\nnext");
    assert(auto_ == " x(); \nsink.put(\"next\");\n", auto_);
}

unittest {
    // Explicit markers stay equivalent to the automatic behaviour.
    assert(compile("  <% x(); %>\nnext") == compile("  <%- x(); -%>\nnext"));
}

unittest {
    // A comment alone on its line disappears completely.
    immutable comment = compile("a\n  <%# note %>\nb");
    assert(comment == "sink.put(\"a\\n\");\nsink.put(\"b\");\n", comment);
}

unittest {
    // An output tag keeps its line: its whitespace is real content.
    immutable output = compile("  <%= x %>\nnext");
    assert(output == "sink.put(\"  \");\n__vcEmit( x );\nsink.put(\"\\nnext\");\n", output);
}

unittest {
    // A block tag sharing its line with markup keeps the surrounding text.
    immutable inline = compile("a<% x(); %>b");
    assert(inline == "sink.put(\"a\");\n x(); \nsink.put(\"b\");\n", inline);
}

unittest {
    // An output tag may span lines, so a fluent chain can be written inline.
    immutable chained = compile("<%= build()\n    .withOne(1)\n    .withTwo(2) %>");
    assert(chained == "__vcEmit( build()\n    .withOne(1)\n    .withTwo(2) );\n", chained);
}

unittest {
    // A multi-line tag does not disturb the literals around it.
    immutable surrounded = compile("a<%= x\n  .y %>b");
    assert(surrounded == "sink.put(\"a\");\n__vcEmit( x\n  .y );\nsink.put(\"b\");\n",
        surrounded);
}

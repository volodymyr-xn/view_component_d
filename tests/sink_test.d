module tests.sink_test;

import view_component.escape : escapeHtml, escapeHtmlInto;
import view_component.sink : Sink;

private string escaped(const(char)[] input) {
    Sink sink;
    escapeHtmlInto(sink, input);

    return sink.data.idup;
}

unittest {
    Sink sink;
    sink.put("<p>");
    sink.put('x');
    sink.put("</p>");

    assert(sink.data == "<p>x</p>");
    assert(sink.length == 8);
}

unittest {
    Sink sink;
    sink.put("kept");
    sink.clear();
    sink.put("fresh");

    assert(sink.data == "fresh");
}

unittest {
    Sink sink;

    assert(sink.data.length == 0);
}

/// Growth has to survive many reallocations without losing earlier bytes.
unittest {
    Sink sink;

    foreach (index; 0 .. 20_000)
        sink.put("0123456789");

    assert(sink.length == 200_000);
    assert(sink.data[0 .. 10] == "0123456789");
    assert(sink.data[$ - 10 .. $] == "0123456789");
}

unittest {
    Sink sink;
    sink.reserve(64 * 1024);
    sink.put("small");

    assert(sink.data == "small");
}

unittest {
    assert(escaped("plain text") == "plain text");
    assert(escaped("") == "");
}

/// Every replacement, at the start, in the middle and at the end.
unittest {
    assert(escaped("&") == "&amp;");
    assert(escaped("<em>") == "&lt;em&gt;");
    assert(escaped(`"q"`) == "&quot;q&quot;");
    assert(escaped("it's") == "it&#39;s");
    assert(escaped("a&b<c>d") == "a&amp;b&lt;c&gt;d");
    assert(escaped("&lead") == "&amp;lead");
    assert(escaped("trail&") == "trail&amp;");
    assert(escaped("&&") == "&amp;&amp;");
}

/// The streaming and allocating forms must not disagree.
unittest {
    static immutable samples = [
        "", "plain", "&", "<>", `R&D "x" it's`, "no markup at all", "<<&&>>",
    ];

    foreach (sample; samples)
        assert(escaped(sample) == escapeHtml(sample));
}

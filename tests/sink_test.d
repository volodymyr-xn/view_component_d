module tests.sink_test;

import std.array : replicate;

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

/**
 * The eight-byte scan has to agree with the allocating form wherever an
 * escapable byte lands — first of a word, last of one, in the tail past the
 * final whole word, or nowhere at all.
 */
unittest {
    foreach (length; 0 .. 40) {
        immutable plain = new char[length];
        (cast(char[]) plain)[] = 'x';

        assert(escaped(plain) == escapeHtml(plain), plain);

        foreach (position; 0 .. length) {
            foreach (escapable; "&<>\"'") {
                auto sample = plain.dup;
                sample[position] = escapable;

                assert(escaped(sample) == escapeHtml(sample), sample.idup);
            }
        }
    }
}

/// Two escapable bytes in the same word, and one in each of two words.
unittest {
    assert(escaped("ab&cd<ef") == "ab&amp;cd&lt;ef");
    assert(escaped("abcdefg&hijklmno<p") == "abcdefg&amp;hijklmno&lt;p");
    assert(escaped("&&&&&&&&&&&&&&&&") == "&amp;".replicate(16));
}

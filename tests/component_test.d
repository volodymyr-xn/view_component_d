module tests.component_test;

import view_component;
import view_component.testing;

final class ButtonComponent : ViewComponent {
    string label;
    string cssClass;

    this(string label, string cssClass) {
        this.label = label;
        this.cssClass = cssClass;
    }

    mixin Template;
}

final class ActionComponent : ViewComponent {
    string name;

    this(string name) {
        this.name = name;
    }

    mixin Template;
}

final class CardComponent : ViewComponent {
    mixin RendersOneContent!("heading");
    mixin RendersMany!("actions", ActionComponent);

    mixin Template;
}

final class ListComponent : ViewComponent {
    string[] entries;

    this(string[] entries) {
        this.entries = entries;
    }

    mixin Template;
}

final class RawComponent : ViewComponent {
    string markup;

    this(string markup) {
        this.markup = markup;
    }

    mixin Template;
}

final class HiddenComponent : ViewComponent {
    bool visible;

    this(bool visible) {
        this.visible = visible;
    }

    bool shouldRender() {
        return visible;
    }

    mixin Template;

    string label = "hidden";
    string cssClass = "x";
}

unittest {
    assertRendersEqual(new ButtonComponent("Save", "btn btn--primary"),
        "<button class=\"btn btn--primary\">Save</button>\n");
}

unittest {
    immutable markup = new ButtonComponent("Click <me> & \"quote\"", "btn").render();
    assertIncludes(markup, "Click &lt;me&gt; &amp; &quot;quote&quot;");
    assertExcludes(markup, "<me>");
}

unittest {
    immutable markup = new ListComponent(["one", "two"]).render();
    assertIncludes(markup, "<li>one</li>");
    assertIncludes(markup, "<li>two</li>");
}

unittest {
    immutable markup = new RawComponent("<em>hi</em>").render();
    assertIncludes(markup, "<p>&lt;em&gt;hi&lt;/em&gt;</p>");
    assertIncludes(markup, "<p><em>hi</em></p>");
    assertIncludes(markup, "<p><%= literal %></p>");
}

unittest {
    assert(new HiddenComponent(false).render() == "");
    assert(new HiddenComponent(true).render().length != 0);
}

unittest {
    auto card = new CardComponent()
        .withHeading("Report")
        .withActions(new ActionComponent("edit"), new ActionComponent("delete"))
        .withContent("body text");

    immutable markup = card.render();
    assertIncludes(markup, "<h2 class=\"card__heading\">Report</h2>");
    assertIncludes(markup, "body text");
    assertIncludes(markup, "edit");
    assertIncludes(markup, "delete");
    assertExcludes(markup, "this comment never reaches");
    assertHasElement(markup, "div", ["class": "card__body"]);
}

unittest {
    auto card = new CardComponent().withContent(raw("<b>bold</b>"));
    assertIncludes(card.render(), "<b>bold</b>");
}

unittest {
    auto card = new CardComponent().withContent((ref Sink sink) { sink.put("<i>lazy</i>"); });
    assertIncludes(card.render(), "<i>lazy</i>");
}

unittest {
    auto card = new CardComponent();
    immutable markup = card.render();
    assertExcludes(markup, "card__heading");
    assertExcludes(markup, "card__actions");
}

unittest {
    assert(toSnakeCase("ButtonComponent") == "button_component");
    assert(toSnakeCase("HTMLBlockComponent") == "html_block_component");
    assert(toSnakeCase("Card") == "card");
}

unittest {
    static assert(templatePathFor!"button_component"
        == "button_component/button_component.html.erb");
    static assert(templatePathFor!"card_component" == "card_component/card_component.html.erb");
}

unittest {
    static assert(!__traits(compiles, templatePathFor!"no_such_component"));
}

final class ButtonComponentPreview : ComponentPreview {
    ViewComponent primary() {
        return new ButtonComponent("Save", "btn btn--primary");
    }

    ViewComponent danger() {
        return new ButtonComponent("Delete", "btn btn--danger");
    }
}

unittest {
    PreviewRegistry.clear();
    registerPreviews!(tests.component_test)();

    assert(PreviewRegistry.inGroup("ButtonComponentPreview").length == 2);
    assertIncludes(PreviewRegistry.render("ButtonComponentPreview", "danger"), "btn--danger");

    PreviewRegistry.clear();
}

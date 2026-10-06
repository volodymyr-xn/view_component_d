module tests.diet_test;

version (ViewComponentDiet):

import view_component;
import view_component.testing;

final class BadgeComponent : ViewComponent {
    string label;
    string tone;

    this(string label, string tone) {
        this.label = label;
        this.tone = tone;
    }

    mixin Template;
}

unittest {
    static assert(templatePathFor!"badge_component" == "badge_component/badge_component.dt");
}

unittest {
    immutable markup = new BadgeComponent("New", "badge--info").render();
    assertIncludes(markup, "badge--info");
    assertIncludes(markup, "New");
}

final class PillComponent : ViewComponent {
    string label;

    this(string label) {
        this.label = label;
    }

    mixin Template;
}

unittest {
    static assert(templatePathFor!"pill_component" == "pill_component/component.dt");
}

unittest {
    assertRendersEqual(new PillComponent("Beta"), "<span class=\"pill\">Beta</span>");
}

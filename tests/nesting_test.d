module tests.nesting_test;

import std.algorithm.searching : canFind;

import view_component;
import view_component.testing;

import tests.outer_component.inner_widget_component.inner_widget_component : InnerWidgetComponent;
import tests.outer_component.outer_component.outer_component : OuterComponent;
import tests.panel_component.component : PanelComponent;
import tests.panel_component.panel_item_component.component : PanelItemComponent;

unittest {
    static assert(OuterComponent.templatePath
        == "outer_component/outer_component/outer_component.html.erb");
}

unittest {
    static assert(InnerWidgetComponent.templatePath
        == "outer_component/inner_widget_component/inner_widget_component.html.erb");
}

unittest {
    immutable markup = new OuterComponent(new InnerWidgetComponent("nested")).render();
    assertIncludes(markup, "<div class=\"outer\">");
    assertIncludes(markup, "<span class=\"inner\">nested</span>");
}

unittest {
    assert(templateCandidates("inner_widget_component",
        "tests.outer_component.inner_widget_component.inner_widget_component")
        == [
            "inner_widget_component/component.html.erb",
            "tests/outer_component/inner_widget_component/component.html.erb",
            "outer_component/inner_widget_component/component.html.erb",
            "inner_widget_component/component.html.erb",
            "inner_widget_component/inner_widget_component.html.erb",
            "tests/outer_component/inner_widget_component/inner_widget_component.html.erb",
            "outer_component/inner_widget_component/inner_widget_component.html.erb",
            "inner_widget_component/inner_widget_component.html.erb",
            "inner_widget_component/component.dt",
            "tests/outer_component/inner_widget_component/component.dt",
            "outer_component/inner_widget_component/component.dt",
            "inner_widget_component/component.dt",
            "inner_widget_component/inner_widget_component.dt",
            "tests/outer_component/inner_widget_component/inner_widget_component.dt",
            "outer_component/inner_widget_component/inner_widget_component.dt",
            "inner_widget_component/inner_widget_component.dt",
        ]);
}

unittest {
    static assert(PanelComponent.templatePath == "panel_component/component.html.erb");
}

unittest {
    static assert(PanelItemComponent.templatePath
        == "panel_component/panel_item_component/component.html.erb");
}

unittest {
    immutable markup = new PanelComponent(new PanelItemComponent("nested")).render();
    assertIncludes(markup, "<section class=\"panel\">");
    assertIncludes(markup, "<p class=\"panel__item\">nested</p>");
}

unittest {
    immutable candidates = templateCandidates("stray_component", "tests.panel_component.component");
    assert(!candidates.canFind("panel_component/component.html.erb"));
    assert(!candidates.canFind("tests/panel_component/component.html.erb"));
}

unittest {
    immutable candidates = templateCandidates("panel_component",
        "tests.my_panel_component.component");
    assert(!candidates.canFind("my_panel_component/component.html.erb"));
}

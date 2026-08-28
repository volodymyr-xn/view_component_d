module tests.nesting_test;

import view_component;
import view_component.testing;

import tests.outer_component.inner_widget_component.inner_widget_component : InnerWidgetComponent;
import tests.outer_component.outer_component.outer_component : OuterComponent;

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
            "inner_widget_component/inner_widget_component.html.erb",
            "tests/outer_component/inner_widget_component/inner_widget_component.html.erb",
            "outer_component/inner_widget_component/inner_widget_component.html.erb",
            "inner_widget_component/inner_widget_component.html.erb",
            "inner_widget_component/inner_widget_component.dt",
            "tests/outer_component/inner_widget_component/inner_widget_component.dt",
            "outer_component/inner_widget_component/inner_widget_component.dt",
            "inner_widget_component/inner_widget_component.dt",
        ]);
}

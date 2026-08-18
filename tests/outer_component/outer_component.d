module tests.outer_component.outer_component;

import view_component;

import tests.outer_component.inner_widget_component : InnerWidgetComponent;

/// Renders a nested component from inside its own template.
final class OuterComponent : ViewComponent
{
    InnerWidgetComponent inner;

    this(InnerWidgetComponent inner)
    {
        this.inner = inner;
    }

    mixin Template;
}

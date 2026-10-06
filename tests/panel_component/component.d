module tests.panel_component.component;

import view_component;

import tests.panel_component.panel_item_component.component : PanelItemComponent;

/// Same tree as `OuterComponent`, laid out with `component.*` file names.
final class PanelComponent : ViewComponent {
    PanelItemComponent item;

    this(PanelItemComponent item) {
        this.item = item;
    }

    mixin Template;
}

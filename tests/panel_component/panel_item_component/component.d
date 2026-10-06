module tests.panel_component.panel_item_component.component;

import view_component;

/**
 * Found via the module's package path, whose last segment names the class —
 * the file name itself no longer does.
 */
final class PanelItemComponent : ViewComponent {
    string caption;

    this(string caption) {
        this.caption = caption;
    }

    mixin Template;
}

module tests.outer_component.inner_widget_component.inner_widget_component;

import view_component;

/**
 * Lives inside its parent's sidecar directory, so its template is found via the
 * module's package path rather than by a directory named after itself.
 */
final class InnerWidgetComponent : ViewComponent {
    string caption;

    this(string caption) {
        this.caption = caption;
    }

    mixin Template;
}

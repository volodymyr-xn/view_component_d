module components.button_component.button_component;

import view_component;

/// Flat layout: this file and `button_component.html.erb` sit side by side.
final class ButtonComponent : ViewComponent {
    string label;
    string tone;
    string href;

    this(string label, string tone, string href = "#") {
        this.label = label;
        this.tone = tone;
        this.href = href;
    }

    string cssClass() {
        return "btn btn--" ~ tone;
    }

    mixin Template;
}

/// Previews are discovered by `registerPreviews` and rendered standalone.
final class ButtonComponentPreview : ComponentPreview {
    ViewComponent primary() {
        return new ButtonComponent("Save changes", "primary");
    }

    ViewComponent danger() {
        return new ButtonComponent("Delete account", "danger", "/account");
    }
}

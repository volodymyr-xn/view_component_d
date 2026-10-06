module components.dashboard_component.component;

import view_component;

import components.card_component.component : CardComponent;

/// Composes other components; nesting renders straight into the shared sink.
final class DashboardComponent : ViewComponent {
    string title;
    CardComponent[] cards;

    this(string title, CardComponent[] cards) {
        this.title = title;
        this.cards = cards;
    }

    mixin Template;
}

module components.card_component.card_component;

import view_component;

import components.button_component.button_component : ButtonComponent;

/**
 * Sidecar-directory layout: the class, its template and its stylesheet all live
 * in `card_component/`.
 */
final class CardComponent : ViewComponent {
    mixin RendersOneContent!("heading");
    mixin RendersMany!("actions", ButtonComponent);

    mixin Template;
}

module components.sidebar_component.sidebar_link_component.sidebar_link_component;

import view_component;

/// A single navigation entry. Lives in its parent's sidecar directory.
final class SidebarLinkComponent : ViewComponent {
    string label;
    string href;
    string icon;
    int badgeCount;

    /// Pushed down by the parent section in its `beforeRender`.
    string currentPath;

    private bool isActive;

    this(string label, string href, string icon) {
        this.label = label;
        this.href = href;
        this.icon = icon;
    }

    typeof(this) withBadgeCount(int badgeCount) {
        this.badgeCount = badgeCount;

        return this;
    }

    void beforeRender() {
        isActive = currentPath.length != 0 && currentPath == href;
    }

    string cssClass() {
        return isActive ? "sidebar__link sidebar__link--active" : "sidebar__link";
    }

    string ariaCurrent() {
        return isActive ? "page" : "false";
    }

    bool hasBadge() {
        return badgeCount > 0;
    }

    mixin Template;
}

module components.sidebar_component.sidebar_section_component.component;

import view_component;

import components.sidebar_component.sidebar_link_component.component : SidebarLinkComponent;

/// A titled group of links. Suppresses itself entirely when it holds none.
final class SidebarSectionComponent : ViewComponent {
    string title;

    /// Pushed down by the sidebar in its `beforeRender`.
    string currentPath;

    private bool isCollapsed;

    mixin RendersMany!("links", SidebarLinkComponent);

    this(string title) {
        this.title = title;
    }

    typeof(this) startCollapsed() {
        isCollapsed = true;

        return this;
    }

    void beforeRender() {
        foreach (link; links)
            link.currentPath = currentPath;
    }

    bool shouldRender() {
        return links.length != 0;
    }

    bool showsLinks() {
        return !isCollapsed;
    }

    string cssClass() {
        return isCollapsed ? "sidebar__section sidebar__section--collapsed" : "sidebar__section";
    }

    int totalBadgeCount() {
        int total = 0;

        foreach (link; links)
            total += link.badgeCount;

        return total;
    }

    mixin Template;
}

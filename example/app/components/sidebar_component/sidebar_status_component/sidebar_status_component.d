module components.sidebar_component.sidebar_status_component.sidebar_status_component;

import std.conv : to;

import view_component;

/**
 * Rendered inline by the sidebar's own template rather than handed in through a
 * slot, so the caller never knows it exists. Use this shape when the child is
 * an implementation detail of its parent; use a slot when the caller should be
 * able to supply, replace or omit it.
 */
final class SidebarStatusComponent : ViewComponent {
    mixin RendersOneContent!("hint");
    mixin RendersManyContent!("chips");

    int sectionCount;
    int linkCount;
    string currentPath;

    this(int sectionCount, int linkCount, string currentPath) {
        this.sectionCount = sectionCount;
        this.linkCount = linkCount;
        this.currentPath = currentPath;
    }

    bool shouldRender() {
        return sectionCount > 0;
    }

    string summary() {
        return sectionCount.to!string ~ " sections, " ~ linkCount.to!string ~ " links";
    }

    bool hasPath() {
        return currentPath.length != 0;
    }

    mixin Template;
}

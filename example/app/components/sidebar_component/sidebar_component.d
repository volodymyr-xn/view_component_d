module components.sidebar_component.sidebar_component;

import view_component;

import components.sidebar_component.sidebar_footer_component.sidebar_footer_component : SidebarFooterComponent;
import components.sidebar_component.sidebar_status_component.sidebar_status_component : SidebarStatusComponent;
import components.sidebar_component.sidebar_section_component.sidebar_section_component : SidebarSectionComponent;

/**
 * Root of the sidebar tree, and the example that exercises every slot kind at
 * once:
 *
 *   brand    RendersOneContent   markup, one
 *   notices  RendersManyContent  markup, many
 *   sections RendersMany         component, many
 *   footer   RendersOne          component, one
 *   content  the base content block
 */
final class SidebarComponent : ViewComponent {
    string currentPath;

    mixin RendersOneContent!("brand");
    mixin RendersManyContent!("notices");
    mixin RendersMany!("sections", SidebarSectionComponent);
    mixin RendersOne!("footer", SidebarFooterComponent);

    this(string currentPath) {
        this.currentPath = currentPath;
    }

    void beforeRender() {
        foreach (section; sections)
            section.currentPath = currentPath;
    }

    /// Counted here so the template can build the status component inline.
    int totalLinkCount() {
        int total = 0;

        foreach (section; sections)
            total += cast(int) section.links.length;

        return total;
    }

    /// Only sections that will actually render, matching what the reader sees.
    int sectionCount() {
        int total = 0;

        foreach (section; sections)
            if (section.links.length != 0)
                total++;

        return total;
    }

    bool hasNavigation() {
        foreach (section; sections)
            if (section.links.length != 0)
                return true;

        return false;
    }

    mixin Template;
}

module example_app;

import std.stdio : writeln;

import view_component;

import components.asset_manifest : assetManifest;
import components.button_component.button_component;
import components.card_component.card_component : CardComponent;
import components.dashboard_component.dashboard_component : DashboardComponent;
import components.sidebar_component.sidebar_component : SidebarComponent;
import components.sidebar_component.sidebar_footer_component.sidebar_footer_component : SidebarFooterComponent;
import components.sidebar_component.sidebar_link_component.sidebar_link_component : SidebarLinkComponent;
import components.sidebar_component.sidebar_section_component.sidebar_section_component : SidebarSectionComponent;

private SidebarComponent buildSidebar(string currentPath) {
    auto workspace = new SidebarSectionComponent("Workspace")
        .withLinks(
            new SidebarLinkComponent("Overview", "/", "◱"),
            new SidebarLinkComponent("Projects", "/projects", "▤").withBadgeCount(3),
            new SidebarLinkComponent("Q&A <beta>", "/qa", "?"));

    auto reports = new SidebarSectionComponent("Reports")
        .startCollapsed()
        .withLinks(
            new SidebarLinkComponent("Revenue", "/reports/revenue", "€"),
            new SidebarLinkComponent("Retention", "/reports/retention", "↻").withBadgeCount(12));

    // Renders nothing at all: `shouldRender` returns false for an empty section.
    auto archived = new SidebarSectionComponent("Archived");

    return new SidebarComponent(currentPath)
        .withBrand(raw("<strong>Acme</strong>&nbsp;Console"))
        .withNotices("Billing details expire in 4 days")
        .withNotices(raw("<a href=\"/status\">Degraded performance</a>"))
        .withSections(workspace, reports, archived)
        .withFooter(new SidebarFooterComponent("Ada Lovelace", "Owner"))
        .withContent(raw("<a class=\"sidebar__help\" href=\"/help\">Help &amp; docs</a>"));
}

void main() {
    writeln("=== sidebar: /projects is the current page ===");
    writeln(buildSidebar("/projects").render());

    writeln("=== sidebar: no sections at all ===");
    writeln(new SidebarComponent("/").render());

    writeln("=== colocated assets, resolved at compile time ===");

    foreach (asset; assetManifest!(SidebarComponent, SidebarSectionComponent,
            SidebarLinkComponent, SidebarFooterComponent, CardComponent, ButtonComponent)())
        writeln("  ", asset);

    auto revenueCard = new CardComponent()
        .withHeading("Revenue")
        .withContent(raw("<p>&euro;18,240 this month</p>"))
        .withActions(new ButtonComponent("Export", "primary", "/export"));

    auto usersCard = new CardComponent()
        .withHeading("Users")
        .withContent("1,204 active — up 6% week over week")
        .withActions(
            new ButtonComponent("Invite", "primary", "/invite"),
            new ButtonComponent("Suspend", "danger", "/suspend"));

    writeln("=== dashboard ===");
    writeln(new DashboardComponent("August", [revenueCard, usersCard]).render());

    writeln("=== dashboard: empty state ===");
    writeln(new DashboardComponent("September", []).render());

    writeln("=== previews ===");
    registerPreviews!(components.button_component.button_component)();

    foreach (preview; PreviewRegistry.all())
        writeln(preview.group, "#", preview.name, ": ", preview.build().render());
}

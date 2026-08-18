// Colocated behaviour for SidebarComponent: collapse a section on click.
// The library does no asset pipeline work — this file simply lives beside the
// component, and `assetManifest` reports it so a build step can pick it up.

function toggleSection(section) {
  section.classList.toggle("sidebar__section--collapsed");

  const links = section.querySelector(".sidebar__links");

  if (links) {
    links.hidden = section.classList.contains("sidebar__section--collapsed");
  }
}

export function connectSidebar(root = document) {
  root.querySelectorAll("[data-sidebar] [data-sidebar-toggle]").forEach((toggle) => {
    toggle.addEventListener("click", () => {
      const section = toggle.closest("[data-sidebar-section]");

      if (section) {
        toggleSection(section);
      }
    });
  });
}

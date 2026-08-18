module components.sidebar_component.sidebar_footer_component;

import view_component;

/// Fills the sidebar's single-component `footer` slot.
final class SidebarFooterComponent : ViewComponent
{
    string userName;
    string role;

    this(string userName, string role)
    {
        this.userName = userName;
        this.role = role;
    }

    string initials()
    {
        string letters;
        bool atWordStart = true;

        foreach (character; userName)
        {
            if (character == ' ')
            {
                atWordStart = true;
                continue;
            }

            if (atWordStart)
                letters ~= character;

            atWordStart = false;
        }

        return letters;
    }

    mixin Template;
}

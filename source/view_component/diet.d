module view_component.diet;

import view_component.base : Sink;

version (ViewComponentDiet) {
    import diet.html : compileHTMLDietFile;

    /**
     * Renders a `.dt` sidecar through diet-ng into the caller's sink.
     *
     * The component instance is exposed to the template under the name
     * `component`, so a Diet sidecar reads `#{component.label}` where the ERB
     * one reads `<%= label %>`. Diet compiles its own templates at CTFE, so
     * this backend keeps the library's no-runtime-parsing guarantee.
     */
    void renderDietInto(string templatePath, Component)(Component component, ref Sink sink) {
        compileHTMLDietFile!(templatePath, component)(sink);
    }
}
else {
    /// Fails the build with an actionable message when the backend is disabled.
    void renderDietInto(string templatePath, Component)(Component component, ref Sink sink) {
        static assert(false,
            "view_component: `" ~ templatePath ~ "` is a Diet template, but the Diet backend"
            ~ " is not enabled.\n"
            ~ "  Add to your dub recipe:\n"
            ~ "    dependency \"diet-ng\" version=\"~>1.8\"\n"
            ~ "    versions \"ViewComponentDiet\"\n"
            ~ "  Or rename the sidecar to `.html.erb` to use the built-in backend.");
    }
}

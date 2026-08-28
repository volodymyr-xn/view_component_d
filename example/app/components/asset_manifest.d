module components.asset_manifest;

/**
 * Collects the stylesheets and scripts sitting next to each component's
 * template.
 *
 * This lives in the example, not the library: `view_component_d` deliberately
 * does no asset pipeline work. It only needs the `templatePath` every component
 * exposes, plus `__traits(compiles, import(...))` to check what actually exists
 * — so the whole manifest is built at compile time and costs nothing at run
 * time.
 */
string[] assetManifest(Components...)() {
    string[] assets;

    static foreach (Component; Components)
        static foreach (asset; colocatedAssets!Component)
            if (!contains(assets, asset))
                assets ~= asset;

    return assets;
}

/// Existing `.css` and `.js` files named after a single component's template.
template colocatedAssets(Component) {
    enum stem = withoutTemplateExtension(Component.templatePath);

    template resolved(string[] extensions) {
        static if (extensions.length == 0)
            enum resolved = cast(string[]) null;
        else static if (__traits(compiles, import(stem ~ extensions[0])))
            enum resolved = [stem ~ extensions[0]] ~ resolved!(extensions[1 .. $]);
        else
            enum resolved = resolved!(extensions[1 .. $]);
    }

    enum colocatedAssets = resolved!([".css", ".js"]);
}

private string withoutTemplateExtension(string templatePath) pure nothrow @safe {
    static immutable string[] extensions = [".html.erb", ".dt"];

    foreach (extension; extensions)
        if (templatePath.length > extension.length
            && templatePath[$ - extension.length .. $] == extension)
            return templatePath[0 .. $ - extension.length];

    return templatePath;
}

private bool contains(string[] haystack, string needle) pure nothrow @safe {
    foreach (entry; haystack)
        if (entry == needle)
            return true;

    return false;
}

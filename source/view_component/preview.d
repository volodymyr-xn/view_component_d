module view_component.preview;

import std.traits : Parameters, ReturnType;

import view_component.base : ViewComponent;

/**
 * Base class for preview classes. Every zero-argument method returning a
 * `ViewComponent` is registered as one preview, the way
 * `ViewComponent::Preview` works in Rails.
 *
 *   final class ButtonComponentPreview : ComponentPreview
 *   {
 *       ViewComponent primary() { return new ButtonComponent("Save", "primary"); }
 *       ViewComponent danger() { return new ButtonComponent("Delete", "danger"); }
 *   }
 */
abstract class ComponentPreview
{
}

/// One registered preview: a named factory under a preview class.
struct PreviewEntry
{
    string group;
    string name;
    ViewComponent delegate() build;
}

/// Process-wide registry of previews discovered at compile time.
final class PreviewRegistry
{
    private static PreviewEntry[] entries;

    static void add(PreviewEntry entry)
    {
        entries ~= entry;
    }

    static const(PreviewEntry)[] all()
    {
        return entries;
    }

    static const(PreviewEntry)[] inGroup(string group)
    {
        const(PreviewEntry)[] matches;

        foreach (ref entry; entries)
            if (entry.group == group)
                matches ~= entry;

        return matches;
    }

    /// Renders one preview by group and name; throws if it is not registered.
    static string render(string group, string name)
    {
        foreach (ref entry; entries)
            if (entry.group == group && entry.name == name)
                return entry.build().render();

        throw new Exception("view_component: no preview `" ~ group ~ "#" ~ name ~ "` registered");
    }

    static void clear()
    {
        entries = null;
    }
}

/**
 * Scans the given modules for `ComponentPreview` subclasses and registers every
 * preview method on them. Call once at startup:
 *
 *   registerPreviews!(app.components.button_component_preview)();
 */
void registerPreviews(Modules...)()
{
    static foreach (Module; Modules)
        static foreach (memberName; __traits(allMembers, Module))
        {{
            static if (__traits(compiles, __traits(getMember, Module, memberName)))
            {
                alias Member = __traits(getMember, Module, memberName);

                static if (is(Member == class) && is(Member : ComponentPreview)
                    && !is(Member == ComponentPreview))
                {
                    registerPreviewClass!Member();
                }
            }
        }}
}

/// Registers every preview method on a single preview class.
void registerPreviewClass(PreviewType)()
if (is(PreviewType : ComponentPreview))
{
    auto instance = new PreviewType();

    static foreach (methodName; __traits(allMembers, PreviewType))
    {{
        static if (__traits(compiles, __traits(getMember, instance, methodName)()))
        {
            alias Method = typeof(&__traits(getMember, instance, methodName));

            static if (Parameters!Method.length == 0
                && is(ReturnType!Method : ViewComponent)
                && !is(ReturnType!Method == void))
            {
                PreviewRegistry.add(PreviewEntry(PreviewType.stringof, methodName,
                    () => cast(ViewComponent) __traits(getMember, instance, methodName)()));
            }
        }
    }}
}

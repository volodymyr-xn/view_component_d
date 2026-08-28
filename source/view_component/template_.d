module view_component.template_;

static import view_component.base;
static import view_component.discovery;
static import view_component.erb;
static import view_component.escape;
static import view_component.hooks;
static import view_component.render;

import view_component.base : ViewComponent;

/**
 * Gives the mixed-in `renderInto` body access to library symbols.
 *
 * A template mixin resolves identifiers in the scope it is mixed into, so the
 * generated body cannot name library symbols directly. Passing this namespace
 * as a defaulted template parameter works because parameter defaults *are*
 * resolved in the declaration scope — `mixin Template;` therefore needs nothing
 * beyond `ViewComponent` itself on the consumer's side.
 */
struct TemplateSupport {
    import std.traits : moduleName;

    alias Sink = view_component.base.Sink;
    alias ViewComponent = view_component.base.ViewComponent;
    alias emit = view_component.render.emit;
    alias raw = view_component.escape.raw;
    alias compileErb = view_component.erb.compileErb;
    alias templatePathFor = view_component.discovery.templatePathFor;
    alias toSnakeCase = view_component.discovery.toSnakeCase;
    alias isDietPath = view_component.discovery.isDietPath;
    alias guardHookNames = view_component.hooks.guardHookNames;
    alias moduleOf = moduleName;
}

/**
 * Compiles a sidecar template into this component's `renderInto`.
 *
 * The template is found by convention from the class name and module: every
 * component lives in a directory named after itself. The body is compiled at
 * CTFE and mixed into a method of this class, so `<%= label %>` is literally
 * `this.label` — type-checked, with no context map and no runtime lookup.
 *
 * Inside a template the following are in scope, alongside every member of the
 * component itself:
 *   `render(value)`  renders a component, or an array of them, into the sink
 *   `content`        the caller-supplied content block
 *   `raw(value)`     marks a value as trusted markup
 */
mixin template Template(alias Support = TemplateSupport) {
    enum templatePath = Support.templatePathFor!(
        Support.toSnakeCase(__traits(identifier, typeof(this))),
        Support.moduleOf!(typeof(this)));

    override protected void renderInto(ref Support.Sink __vcSink) {
        static assert(Support.guardHookNames!(typeof(this)));

        static if (__traits(hasMember, typeof(this), "beforeRender")) {
            static assert(is(typeof(this.beforeRender()) == void),
                "view_component: `beforeRender` must take no arguments and return void.");

            beforeRender();
        }

        static if (__traits(hasMember, typeof(this), "shouldRender")) {
            static assert(is(typeof(this.shouldRender()) == bool),
                "view_component: `shouldRender` must take no arguments and return bool.");

            if (!shouldRender())
                return;
        }

        alias raw = Support.raw;

        void __vcEmit(Value)(auto ref Value value) {
            Support.emit(__vcSink, value);
        }

        void __vcEmitRaw(Value)(auto ref Value value) {
            Support.emit(__vcSink, Support.raw(value));
        }

        void render(Value)(auto ref Value value) {
            Support.emit(__vcSink, value);
        }

        static if (Support.isDietPath(templatePath)) {
            import view_component.diet : renderDietInto;

            renderDietInto!(templatePath)(this, __vcSink);
        }
        else {
            mixin(Support.compileErb(import(templatePath), templatePath, "__vcSink"));
        }
    }
}

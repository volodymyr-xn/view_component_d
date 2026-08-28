module tests.hooks_test;

import view_component;
import view_component.testing;

final class HookedComponent : ViewComponent {
    string label = "before";
    string cssClass = "x";

    void beforeRender() {
        label = "after";
    }

    mixin Template;
}

unittest {
    // Declared without `override` or `protected`, and still called.
    assertIncludes(new HookedComponent().render(), "after");
}

unittest {
    assert(isNearMiss("beforeRenderr", "beforeRender"));
    assert(isNearMiss("beforRender", "beforeRender"));
    assert(isNearMiss("BeforeRender", "beforeRender"));
    assert(isNearMiss("beforeRenden", "beforeRender"));
    assert(isNearMiss("shouldRenders", "shouldRender"));
}

unittest {
    assert(!isNearMiss("beforeRender", "beforeRender"));
    assert(!isNearMiss("cssClass", "beforeRender"));
    assert(!isNearMiss("render", "beforeRender"));
    assert(!isNearMiss("renderInSink", "shouldRender"));
    assert(!isNearMiss("", "beforeRender"));
}

unittest {
    // Every member the base class and the slot mixins generate must stay clear
    // of the guard, or ordinary components would stop compiling.
    static assert(guardHookNames!HookedComponent);
    static assert(guardHookNames!ViewComponent);
}

version (unittest) {
    /// Not a component: exercises the guard without instantiating `Template`.
    final class TypoCarrier {
        void beforRender() {
        }
    }

    final class CleanCarrier {
        void beforeRender() {
        }

        void unrelatedHelper() {
        }
    }
}

unittest {
    // A misspelled hook is a compile error rather than silently dead code.
    static assert(!__traits(compiles, guardHookNames!TypoCarrier));
    static assert(guardHookNames!CleanCarrier);
}

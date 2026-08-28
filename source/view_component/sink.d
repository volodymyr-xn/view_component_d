module view_component.sink;

import core.memory : GC;
import core.stdc.string : memcpy;

/**
 * The output buffer every component renders into.
 *
 * A hand-grown block rather than an `Appender!string`: literal chunks arrive
 * one `put` at a time and there are thousands of them per page, so the
 * per-call cost dominates. Copying through `memcpy` skips druntime's
 * slice-assignment conformability checks, and the block is allocated
 * `NO_SCAN` and uninitialised because it holds no pointers and every byte is
 * overwritten before it is read.
 *
 * Growth asks the GC to extend the block in place first, so a page that ends
 * up megabytes long still costs one allocation rather than one per doubling.
 */
struct Sink {
    private enum initialCapacity = 512;

    private char* block;
    private size_t capacity;
    private size_t used;

    /// Grows the buffer so `wanted` bytes can be written without reallocating.
    void reserve(size_t wanted) {
        if (wanted > capacity)
            grow(wanted);
    }

    /// Appends `chunk` verbatim.
    void put(const(char)[] chunk) {
        if (chunk.length == 0)
            return;

        if (used + chunk.length > capacity)
            grow(used + chunk.length);

        memcpy(block + used, chunk.ptr, chunk.length);
        used += chunk.length;
    }

    /// ditto
    void put(char character) {
        if (used == capacity)
            grow(used + 1);

        block[used] = character;
        used++;
    }

    /// Appends `character` encoded as UTF-8.
    void put(dchar character) {
        import std.utf : encode;

        char[4] encoded;
        immutable length = encode(encoded, character);

        put(encoded[0 .. length]);
    }

    /// The markup written so far. Valid until the next `put`.
    const(char)[] data() const return {
        return block is null ? null : block[0 .. used];
    }

    /// Bytes written so far.
    size_t length() const {
        return used;
    }

    /// Drops the contents, keeping the buffer for the next render.
    void clear() {
        used = 0;
    }

    private void grow(size_t required) {
        size_t wanted = capacity == 0 ? initialCapacity : capacity;

        while (wanted < required)
            wanted *= 2;

        if (block !is null) {
            // Ask for the doubling but settle for what is needed now: a partial
            // extension still beats copying the whole block somewhere else.
            immutable extended = GC.extend(block, required - capacity, wanted - capacity);

            if (extended != 0) {
                capacity = extended;

                return;
            }
        }

        // `qalloc` reports the block the GC actually handed out, which is
        // rounded up to its bin size — taking that as the capacity saves a
        // doubling the pool has already paid for. The block is deliberately
        // not `APPENDABLE`: druntime would reserve part of it for the array
        // length it keeps for `~=`, and every byte here is written directly.
        auto grown = GC.qalloc(wanted, GC.BlkAttr.NO_SCAN);

        if (used != 0)
            memcpy(grown.base, block, used);

        block = cast(char*) grown.base;
        capacity = grown.size;
    }
}

// The footer script answers events, and between two of them each behaviour has to remember a little: which
// popover it opened, which timer is pending. The original script kept that in variables of its closures. Here
// each behaviour keeps one readonly record per document or element it serves, and replaces the record whole
// whenever something changes, so no state is edited in place and two documents never share any.

/** One record of state for each owner, replaced whole on every change. */
export interface Memory<Owner extends object, State> {
  readonly read: (owner: Owner) => State
  readonly write: (owner: Owner, state: State) => void
}

/**
 * Creates the memory of one behaviour.
 * @param initial the state of an owner the behaviour has not written yet
 * @returns the memory, empty for every owner
 */
export const memoryOf = <Owner extends object, State>(initial: State): Memory<Owner, State> => {
  const states: WeakMap<Owner, State> = new WeakMap<Owner, State>()
  return {
    read: (owner: Owner): State => states.get(owner) ?? initial,
    write: (owner: Owner, state: State): void => {
      states.set(owner, state)
    },
  }
}

# Logic Prototype

Use this branch when the uncertainty is in business rules, state transitions, data shape, or API ergonomics.

## Shape

Build a small interactive terminal program or similarly lightweight runner that lets the user apply meaningful actions and inspect the resulting state.

- Use the host project's language and existing tooling.
- Keep state in memory unless persistence is the question.
- Separate the logic under evaluation from terminal input and rendering when that makes the result easier to reason about or reuse.
- Prefer plain data and a small surface: reducer, state machine, focused functions, or a stateful module as appropriate.
- Do not introduce a framework or package for terminal styling or input when native facilities are sufficient.

## Interaction

- State the exact question in a top-of-file comment or the prototype's visible opening screen.
- Show the current relevant state before input and after each action.
- Offer only actions needed to exercise the uncertain behavior.
- Make invalid or unsafe actions visible instead of silently accepting them.
- Keep the interface small enough to understand in one session.
- Provide a quit action and one direct run command.

## Data and safety

- Never connect to the real production database or live service by default.
- Use fixtures, in-memory state, stubs, a temporary directory, or a clearly disposable local database.
- If persistence or an integration is the experiment, isolate it and state exactly what can be changed.
- Avoid destructive fixtures and irreversible migrations.

## Verification

Run the prototype and exercise the main transition plus the most important edge case. A focused automated check is allowed when it is the cheapest way to keep the experiment repeatable; do not build a production test suite around throwaway code.

Hand over the command and the scenarios worth trying. Do not automatically move the experimental logic into production or delete the prototype.

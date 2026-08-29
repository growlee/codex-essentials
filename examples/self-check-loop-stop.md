# Self-check loop-stop example

> Example only. `$self-check` is explicit-only and read-only.

## Situation

An agent has attempted the same failing installation command twice. The user already chose a different installation path, but the agent starts reconstructing the abandoned approach.

## Check

- Repeated action: retrying the old installation command.
- Material change since the previous attempt: none.
- New evidence: none.
- Newest user instruction: use the marketplace installation path.
- Settled decision: the old direct-copy approach was explicitly rejected.

## Result

Stop the repeated command. Continue from the marketplace installation path already selected by the user. Do not create attempt counters, retry state, another self-check, or a repair loop.

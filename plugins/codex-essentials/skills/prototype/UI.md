# UI Prototype

Use this branch when the uncertainty is layout, information hierarchy, interaction, density, or visual direction.

## Shape

Build a small set of meaningfully different variants that the user can compare in one local surface.

- Reuse the project's existing framework, component library, styling system, and representative read-only data where practical.
- Prefer an isolated prototype route or clearly gated local surface.
- Modify an existing page only when evaluating the design in its real context is important and the prototype remains safely gated from production users.
- Variants must differ in structure, hierarchy, or primary interaction—not only color or copy.
- Create only enough variants to expose the real tradeoff; three is a useful default, not a requirement.

## Switching

Make variants easy to compare from one URL or screen.

- Use a query parameter, local control, or another simple project-native mechanism.
- Keep the selected variant reload-stable when practical.
- Label variants by the idea they test rather than only by letter.
- Keep prototype controls visually distinct from the proposed design.
- Do not require a shared abstraction that forces the variants into the same layout.

## Data and safety

- Use existing read-only data, fixtures, or stubs.
- Stub create, update, delete, payment, notification, and other consequential actions.
- Do not expose a prototype route or switcher in a production build unless the user explicitly requests and approves that delivery boundary.
- Preserve accessibility basics needed to evaluate the interaction, including keyboard reachability and visible focus where relevant.

## Verification

Run the local surface and confirm that every variant renders and switching works. Check the viewport or interaction that materially affects the decision; do not turn the prototype into a full production QA cycle.

Hand over the URL, variant names, question being tested, and known shortcuts. Choosing a winner, cleaning up variants, or integrating production code is separate work.

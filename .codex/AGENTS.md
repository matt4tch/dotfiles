# Mandatory Typst source review

For every task in which you create or modify any `.typ` file:

1. The global SessionStart/Stop hook
   `~/.codex/hooks/typst_indexed_spacing.py` records changed
   Typst paths using a session-scoped filesystem watcher and blocks completion
   when a changed file contains an indexed identifier immediately followed by
   `(` or padded quoted text inside math. Do not disable, bypass, or weaken
   this check.
2. If the hook reports candidates such as `f_a(x)`, `f_j(z)`, `phi_n(t)`, or
   `Phi_(A)(z)`, inspect each one individually in its mathematical context.
   Never use
   a blind regex replacement.
3. When the notation is evaluation of an indexed function, map, curve, sequence
   member, or similar object, insert a space before its argument:

   ```typst
   f_a (x)
   f_j (z)
   phi_n (t)
   Phi_(A) (z)
   ```

   Without the space, Typst can visually associate the parenthesized argument
   with the subscript.
4. Do not apply this rule to unindexed calls such as `clos(x)` or `abs(x)`, to
   Typst code-level function calls, or to indexed expressions where the
   following parentheses are intentionally part of the subscript or another
   mathematical construction.
5. Quoted text inside Typst math must not contain padding immediately inside
   the quotation marks. Write `f "is continuous"`, not
   `f " is continuous "`. Put semantic spaces outside the text literal or let
   Typst's math spacing handle them.
6. The hook is a mandatory completion gate. Do not claim the task is finished
   while it reports a candidate. Correct each reported occurrence before
   completing the task.

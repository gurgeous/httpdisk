# AGENTS

## Workflow

- Prefer `just` recipes vs raw cli
- After code changes, run `just check`
- Do not run rubocop or prettier directly; use `just fmt` or `just lint`
- Don't be overly defensive, fail fast
- Keep commit messages under 80 chars

## Layout

- Executables in `bin/`
- Support code and domain logic in `lib/`

## Coding Style

- Be concise, we value that highly
- Favor early returns, functional/immutable helpers, minimal, golden path
- Keep code small, direct, and easy to scan
- Prefer symbol-keyed hashes
- Prefer `hash[:key]` over `fetch`; use `fetch` when a missing key should fail fast
- Avoid `to_s` / `to_sym` churn unless it solves a real boundary problem
- Methods with >=3 args are a code smell, esp. when forwarded; prefer context:, options:, or refactor
- When using a shell, use argv arrays to avoid escaping issues
- Avoid compatibility class aliases

## Formatting

- Trivial methods can be one-liners, only if <100 chars
- If a file has several one-liners, group them under `# one-liners` at bottom and alphabetize
- Use `_1` / `_2` for simple blocks when clear
- Add a short top-level comment to each source file
- A single line comment above complex code sections can be helpful

## Bin Scripts

- `Main` is a fine class name for things in bin/
- Scripts in bin/ always use BinMain, Sloppier and TableTennis
- Nice output with `ap` or writing CSVs to /tmp
- Use `delegate:` for `options` with sloppier

## Tests

- New behavior should usually come with tests
- Bug fixes should usually add or update a test
- Keep tests small and deterministic
- Avoid dependency injection, Ruby doesn't use that. Mock/stub

## Defaults

- Match the repo's existing test style
- Prefer existing repo patterns over new abstractions
- Prefer straightforward over clever
- Keep comments light and useful
- Be conservative about adding deps, core ext, or globals

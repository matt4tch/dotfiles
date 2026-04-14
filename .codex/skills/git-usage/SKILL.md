---
name: git-usage
description: Use when the user asks Codex to commit changes, push changes, or follow repository-aware git workflow after making edits. Covers choosing the correct repo for touched files, staging only relevant changes, writing clear conventional commit messages, and pushing only when explicitly requested.
---

# Git Usage

Use this skill when the user explicitly asks for any of the following:
- commit the changes
- make a commit
- push the changes
- commit and push
- use the appropriate repo

Do not commit or push by default. Only do so when the user explicitly instructs you.

## Repo Selection

- Determine which git repository owns the files you changed before staging anything.
- If all touched files belong to one repo, commit in that repo.
- If touched files span multiple repos, keep commits separate by repo.
- If repo ownership is genuinely ambiguous, ask a concise question before committing.
- Never commit unrelated dirty changes you did not make unless the user explicitly asks for that.

## Staging Rules

- Stage only the files relevant to the requested change.
- Review `git status --short` before committing.
- Pay special attention to newly added files (`A` / `??`). If a staged new file represents a broader feature or scaffold than the commit message suggests, split it into a separate commit.
- Explicitly check for related lock/config/generated files before committing. Common examples: `lazy-lock.json`, `package-lock.json`, `pnpm-lock.yaml`, `Cargo.lock`, `poetry.lock`, generated plugin lockfiles, and dependency snapshot files.
- If a code or config change caused a lock file to change, stage and commit that lock file in the same commit unless the user explicitly wants it split out.
- Before finalizing a commit, review `git diff --stat` or path-specific diffs to confirm no relevant lock file was missed.
- Before committing, compare the staged file set against the proposed commit message. If the message is narrower than the staged scope, either split the commit or broaden the message so the history stays truthful.
- Avoid broad staging commands when a narrower path-based stage is available.
- Do not use interactive git flows.

## Commit Rules

- Use a clear conventional-style commit message.
- Prefer the format `<type>: <short imperative summary>`.
- Common types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`.
- Keep the subject concise and specific to the actual change.
- If a body is useful, keep it short and focused on why the change was needed.
- Do not amend existing commits unless the user explicitly asks.

Examples:
- `fix: update zsh startup symlinks in dotfiles repo`
- `chore: add tmux config to dotfiles`
- `docs: document local bootstrap steps`

## Push Rules

- Push only when the user explicitly asks to push.
- Before pushing, check the current branch and whether it has an upstream.
- If an upstream exists, push to it.
- If no upstream exists, tell the user and offer to create the upstream with a standard push command.
- Do not create or change upstream tracking unless the user explicitly wants that push to happen.

## Verification

Before reporting completion for a requested commit or push:
- confirm the target repo
- summarize the staged/committed scope
- mention any lock files that were intentionally included or intentionally left out
- provide the commit hash after committing
- if pushed, provide the branch and remote used

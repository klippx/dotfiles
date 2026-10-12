#!/usr/bin/env bash
# Integration tests simulating the Copilot sessionStart JSON payload.
set -eu

repo_root=$(cd -- "$(dirname -- "$0")/.." && pwd -P)

setup() {
  root=$(mktemp -d "${TMPDIR:-/tmp}/worktree tests.XXXXXX")
  root=$(cd -- "$root" && pwd -P)
  trap 'rm -rf -- "$root"' EXIT
  export HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config"
  export GIT_CONFIG_GLOBAL="$root/gitconfig" GIT_CONFIG_NOSYSTEM=1
  export GIT_CEILING_DIRECTORIES="$root"
  unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
  unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_CONFIG GIT_TEMPLATE_DIR
  unset COPILOT_ROOT_PATH COPILOT_WORKSPACE_PATH
  mkdir -p "$HOME/.local/bin" "$HOME/.copilot/hooks" "$root/template"
  printf '{"version":1,"hooks":{}}\n' > "$HOME/.copilot/hooks/personal.json"
  cp "$HOME/.copilot/hooks/personal.json" "$root/expected-personal.json"
  stow --dir "$repo_root" --target "$HOME" worktree
  [[ ! -L "$HOME/.copilot/hooks" ]] || fail 'personal hook directory was folded'
  [[ -L "$HOME/.copilot/hooks/init-worktree.json" ]] || fail 'hook not installed'
  jq -e '
    .version == 1 and (.hooks | keys) == ["sessionStart"] and
    (.hooks.sessionStart | length) == 1 and
    .hooks.sessionStart[0].type == "command" and
    .hooks.sessionStart[0].bash == "\"$HOME/.local/bin/init-worktree\""
  ' "$HOME/.copilot/hooks/init-worktree.json" > /dev/null || fail 'invalid hook configuration'
}

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_same() {
  cmp -s -- "$1" "$2" || fail "files differ: $1 and $2"
}

assert_missing() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "unexpected destination: $1"
}

create_repo() {
  git init --quiet --initial-branch=main --template="$root/template" "$1"
  printf 'dummy tracked file\n' > "$1/tracked"
  git -C "$1" add tracked
  git -C "$1" -c user.name='Worktree test' -c user.email='test@example.invalid' commit --quiet -m initial
}

add_worktree() {
  git -C "$1" worktree add --quiet --detach "$2"
}

run_session_hook() {
  jq -nc --arg cwd "$1" '{cwd: $cwd, initialPrompt: "DUMMY_PRIVATE_PROMPT"}' |
    bash -c '"$HOME/.local/bin/init-worktree"'
}

test_worktree_creation_and_checkouts() {
  local primary="$root/primary checkout" linked="$root/linked checkout"
  create_repo "$primary"
  printf 'DUMMY_ENV=example\n' > "$primary/.env"
  printf 'touch "%s"\n' "$root/unexpected-execution" > "$primary/.envrc"
  mkdir -p "$primary/.secrets/nested"
  printf 'dummy secret\n' > "$primary/.secrets/nested/token"
  ln -s nested/token "$primary/.secrets/link"
  printf 'not on allowlist\n' > "$primary/.env.local"
  add_worktree "$primary" "$linked"
  assert_missing "$linked/.env"
  assert_missing "$linked/.envrc"
  assert_missing "$linked/.secrets"
  mkdir "$root/unrelated cwd"
  mkdir "$linked/nested cwd"
  (cd "$root/unrelated cwd" && run_session_hook "$linked/nested cwd") > "$root/output" 2>&1
  [[ ! -s "$root/output" ]] || fail 'successful initialization printed output'
  assert_same "$primary/.env" "$linked/.env"
  assert_same "$primary/.envrc" "$linked/.envrc"
  assert_same "$primary/.secrets/nested/token" "$linked/.secrets/nested/token"
  [[ $(readlink "$linked/.secrets/link") == nested/token ]] || fail 'source symlink changed'
  assert_missing "$linked/.env.local"
  assert_missing "$root/unexpected-execution"
  rm -- "$linked/.env"
  git -C "$linked" checkout --quiet -b ordinary
  git -C "$linked" checkout --quiet -- tracked
  assert_missing "$linked/.env"
  git -C "$linked" checkout --quiet --orphan unborn
  git -C "$linked" checkout --quiet --detach main
  assert_missing "$linked/.env"
  git clone --quiet --template="$root/template" "$primary" "$root/primary clone"
  assert_missing "$root/primary clone/.env"
  add_worktree "$linked" "$root/from linked"
  assert_missing "$root/from linked/.env"
  run_session_hook "$root/from linked"
  assert_same "$primary/.env" "$root/from linked/.env"
}

test_primary_checkout_is_skipped() {
  local primary="$root/primary guard"
  create_repo "$primary"
  printf 'keep primary\n' > "$primary/.env"
  run_session_hook "$primary"
  ln -s "$primary" "$root/primary alias"
  run_session_hook "$root/primary alias"
  printf 'keep primary\n' > "$root/expected"
  assert_same "$root/expected" "$primary/.env"
}

test_invalid_payloads_and_non_git_cwd() {
  local payload
  for payload in '' '{' '{}' '{"cwd":null}' '{"cwd":42}' '{"cwd":""}'; do
    if printf '%s' "$payload" | "$HOME/.local/bin/init-worktree" > "$root/output" 2>&1; then
      fail 'invalid hook payload accepted'
    fi
    grep -q 'init-worktree: expected' "$root/output" || fail 'invalid payload not reported'
  done
  if run_session_hook "$root/nonexistent cwd" > "$root/output" 2>&1; then
    fail 'nonexistent cwd accepted'
  fi
  grep -q 'cannot inspect Git checkout' "$root/output" || fail 'Git lookup failure not reported'
  run_session_hook "$root" > "$root/output" 2>&1
  [[ ! -s "$root/output" ]] || fail 'non-Git startup reported as an error'
}

test_bare_and_separate_gitdirs() {
  local primary="$root/layout primary" bare="$root/bare.git" linked="$root/bare linked"
  create_repo "$primary"
  git clone --quiet --bare --template="$root/template" "$primary" "$bare"
  printf 'not a checkout source\n' > "$bare/.env"
  add_worktree "$bare" "$linked"
  run_session_hook "$linked"
  assert_missing "$linked/.env"
  git -C "$primary" init --quiet --template="$root/template" --separate-git-dir="$root/separate metadata"
  add_worktree "$primary" "$root/separate linked"
  if run_session_hook "$root/separate linked" > "$root/output" 2>&1; then
    fail 'unsupported primary layout accepted'
  fi
  grep -q 'separate gitdirs' "$root/output" || fail 'unsupported layout not reported'
}

test_missing_sources_and_secrets_file() {
  local primary="$root/missing" name
  create_repo "$primary"
  add_worktree "$primary" "$root/missing linked"
  run_session_hook "$root/missing linked" > "$root/output" 2>&1
  [[ ! -s "$root/output" ]] || fail 'missing sources reported as errors'
  for name in .env .envrc .secrets; do
    assert_missing "$root/missing linked/$name"
  done
  printf 'dummy secret file\n' > "$primary/.secrets"
  add_worktree "$primary" "$root/file linked"
  ln -s absent-source "$primary/.env"
  run_session_hook "$root/file linked"
  assert_same "$primary/.secrets" "$root/file linked/.secrets"
  [[ $(readlink "$root/file linked/.env") == absent-source ]] || fail 'source symlink changed'
}

test_existing_destinations() {
  local primary="$root/destinations primary" target kind name link_to
  create_repo "$primary"
  printf 'dummy source\n' > "$primary/.env"
  printf 'dummy source\n' > "$primary/.envrc"
  mkdir "$primary/.secrets"
  printf 'dummy secret\n' > "$primary/.secrets/token"
  for kind in file directory symlink dangling; do
    target="$root/existing $kind"
    git -C "$primary" worktree add --quiet --no-checkout --detach "$target"
    printf 'keep destination\n' > "$target/keep"
    link_to=keep
    [[ "$kind" != dangling ]] || link_to=absent
    for name in .env .envrc .secrets; do
      case "$kind" in
        file) cp "$target/keep" "$target/$name" ;;
        directory) mkdir "$target/$name"; cp "$target/keep" "$target/$name/keep" ;;
        *) ln -s "$link_to" "$target/$name" ;;
      esac
    done
    run_session_hook "$target"
    for name in .env .envrc .secrets; do
      case "$kind" in
        file) assert_same "$target/keep" "$target/$name" ;;
        directory)
          assert_same "$target/keep" "$target/$name/keep"
          [[ $(find "$target/$name" -mindepth 1 -maxdepth 1 | wc -l) -eq 1 ]] ||
            fail 'existing directory modified'
          ;;
        *) [[ $(readlink "$target/$name") == "$link_to" ]] || fail 'destination symlink changed' ;;
      esac
    done
  done
}

test_copy_failures() {
  local primary="$root/failure"
  create_repo "$primary"
  printf 'DUMMY_DO_NOT_PRINT\n' > "$primary/.env"
  add_worktree "$primary" "$root/failure linked"
  mkdir "$root/failing-bin"
  printf '#!/bin/sh\nexit 25\n' > "$root/failing-bin/cp"
  chmod +x "$root/failing-bin/cp"
  if PATH="$root/failing-bin:$PATH" run_session_hook "$root/failure linked" > "$root/output" 2>&1; then
    fail 'copy failure ignored'
  fi
  grep -q 'failed to copy .env' "$root/output" || fail 'copy failure not reported'
  if grep -qE 'DUMMY_DO_NOT_PRINT|DUMMY_PRIVATE_PROMPT' "$root/output"; then
    fail 'private contents printed'
  fi
}

test_git_hooks_are_untouched() {
  local kind primary linked hooks events hook
  for kind in default custom; do
    primary="$root/$kind hooks primary"
    linked="$root/$kind hooks linked"
    events="$root/$kind hook events"
    create_repo "$primary"
    hooks="$primary/.git/hooks"
    if [[ "$kind" == custom ]]; then
      hooks="$root/custom hooks"
      git -C "$primary" config core.hooksPath "$hooks"
    fi
    mkdir -p "$hooks"
    for hook in post-checkout pre-commit; do
      printf '#!/bin/sh\nprintf "%%s\\n" "%s" >> "%s"\n' "$hook" "$events" > "$hooks/$hook"
      chmod +x "$hooks/$hook"
    done
    printf 'dummy environment\n' > "$primary/.env"
    add_worktree "$primary" "$linked"
    grep -q post-checkout "$events" || fail 'existing checkout hook did not run'
    assert_missing "$linked/.env"
    run_session_hook "$linked"
    assert_same "$primary/.env" "$linked/.env"
    git -C "$linked" -c user.name='Worktree test' -c user.email='test@example.invalid' \
      commit --quiet --allow-empty -m 'existing hook test'
    grep -q pre-commit "$events" || fail 'existing commit hook did not run'
    if [[ "$kind" == custom ]]; then
      [[ $(git -C "$linked" config core.hooksPath) == "$hooks" ]] || fail 'custom hooks path changed'
    fi
  done
}

test_stow_removal() {
  assert_missing "$HOME/.config/git/hooks"
  assert_same "$root/expected-personal.json" "$HOME/.copilot/hooks/personal.json"
  stow --dir "$repo_root" --target "$HOME" --delete worktree
  assert_missing "$HOME/.local/bin/init-worktree"
  assert_missing "$HOME/.copilot/hooks/init-worktree.json"
  assert_same "$root/expected-personal.json" "$HOME/.copilot/hooks/personal.json"
}

main() {
  setup
  local test_case
  for test_case in \
    test_worktree_creation_and_checkouts \
    test_primary_checkout_is_skipped \
    test_invalid_payloads_and_non_git_cwd \
    test_bare_and_separate_gitdirs \
    test_missing_sources_and_secrets_file \
    test_existing_destinations \
    test_copy_failures \
    test_git_hooks_are_untouched \
    test_stow_removal; do
    "$test_case"
    printf 'PASS: %s\n' "$test_case"
  done
}

main

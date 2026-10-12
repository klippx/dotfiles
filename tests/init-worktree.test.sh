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

test_nested_sources_and_discovery_exclusions() {
  local primary="$root/nested primary" linked="$root/nested linked"
  local workspace='dgs/car-configuration' spaced='packages/with spaces'
  local newline=$'packages/with\nnewline'
  create_repo "$primary"
  mkdir -p "$primary/$workspace" "$primary/$spaced/.secrets/nested" "$primary/$newline"
  printf 'DUMMY_ENV=nested\n' > "$primary/$workspace/.env"
  printf 'dummy workspace secret\n' > "$primary/$workspace/.secrets"
  ln -s absent-config "$primary/$workspace/.envrc"
  printf 'dummy directory secret\n' > "$primary/$spaced/.secrets/nested/token"
  ln -s nested/token "$primary/$spaced/.secrets/link"
  printf 'dummy newline environment\n' > "$primary/$newline/.env"
  printf 'not on allowlist\n' > "$primary/$workspace/.env.local"
  mkdir -p "$primary/.git/scan fixture" "$primary/node_modules/dependency" \
    "$primary/$workspace/node_modules/dependency" "$primary/$workspace/.git" \
    "$root/external source"
  printf 'excluded metadata\n' > "$primary/.git/scan fixture/.env"
  printf 'excluded dependency\n' > "$primary/node_modules/dependency/.env"
  printf 'excluded nested dependency\n' > "$primary/$workspace/node_modules/dependency/.secrets"
  printf 'excluded nested metadata\n' > "$primary/$workspace/.git/.envrc"
  printf 'excluded external environment\n' > "$root/external source/.env"
  ln -s "$root/external source" "$primary/external alias"
  ln -s dgs "$primary/workspace alias"
  add_worktree "$primary" "$linked"
  run_session_hook "$linked" > "$root/output" 2>&1
  [[ ! -s "$root/output" ]] || fail 'nested initialization printed output'
  assert_same "$primary/$workspace/.env" "$linked/$workspace/.env"
  assert_same "$primary/$workspace/.secrets" "$linked/$workspace/.secrets"
  [[ $(readlink "$linked/$workspace/.envrc") == absent-config ]] || fail 'nested source symlink changed'
  assert_same "$primary/$spaced/.secrets/nested/token" "$linked/$spaced/.secrets/nested/token"
  [[ $(readlink "$linked/$spaced/.secrets/link") == nested/token ]] || fail 'nested secret symlink changed'
  assert_same "$primary/$newline/.env" "$linked/$newline/.env"
  assert_missing "$linked/$workspace/.env.local"
  assert_missing "$linked/$workspace/.git"
  assert_missing "$linked/node_modules"
  assert_missing "$linked/$workspace/node_modules"
  assert_missing "$linked/external alias"
  assert_missing "$linked/workspace alias"
}

test_primary_directory_name_is_not_a_candidate() {
  local name primary linked
  for name in .secrets node_modules; do
    primary="$root/named primary/$name"
    linked="$root/named linked/$name"
    create_repo "$primary"
    printf 'dummy root environment\n' > "$primary/.env"
    add_worktree "$primary" "$linked"
    run_session_hook "$linked"
    assert_same "$primary/.env" "$linked/.env"
  done
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

test_existing_nested_destinations() {
  local primary="$root/nested destinations primary" linked="$root/nested destinations linked"
  local kind name relative target link_to
  create_repo "$primary"
  add_worktree "$primary" "$linked"
  printf 'keep destination\n' > "$root/nested expected"
  for kind in file directory symlink dangling; do
    relative="dgs/$kind workspace"
    target="$linked/$relative"
    mkdir -p "$primary/$relative/.secrets/nested" "$target"
    printf 'dummy source\n' > "$primary/$relative/.env"
    printf 'dummy source\n' > "$primary/$relative/.envrc"
    printf 'dummy nested secret\n' > "$primary/$relative/.secrets/nested/.env"
    cp "$root/nested expected" "$target/keep"
    link_to=keep
    [[ "$kind" != dangling ]] || link_to=absent
    for name in .env .envrc .secrets; do
      case "$kind" in
        file) cp "$target/keep" "$target/$name" ;;
        directory) mkdir "$target/$name"; cp "$target/keep" "$target/$name/keep" ;;
        *) ln -s "$link_to" "$target/$name" ;;
      esac
    done
  done
  run_session_hook "$linked"
  for kind in file directory symlink dangling; do
    target="$linked/dgs/$kind workspace"
    link_to=keep
    [[ "$kind" != dangling ]] || link_to=absent
    for name in .env .envrc .secrets; do
      case "$kind" in
        file) assert_same "$root/nested expected" "$target/$name" ;;
        directory)
          assert_same "$root/nested expected" "$target/$name/keep"
          [[ $(find "$target/$name" -mindepth 1 -maxdepth 1 | wc -l) -eq 1 ]] ||
            fail 'existing nested directory modified'
          ;;
        *) [[ $(readlink "$target/$name") == "$link_to" ]] || fail 'nested destination symlink changed' ;;
      esac
    done
  done
}

test_unsafe_nested_parents() {
  local primary="$root/unsafe primary" linked="$root/unsafe linked" kind
  create_repo "$primary"
  printf 'dummy root environment\n' > "$primary/.env"
  for kind in outside dangling file inside; do
    mkdir -p "$primary/dgs/$kind"
    printf 'dummy nested environment\n' > "$primary/dgs/$kind/.env"
  done
  add_worktree "$primary" "$linked"
  mkdir -p "$linked/dgs/real directory" "$root/outside destination"
  printf 'keep existing file\n' > "$linked/dgs/file"
  cp "$linked/dgs/file" "$root/unsafe expected"
  ln -s "$root/outside destination" "$linked/dgs/outside"
  ln -s "$root/absent destination" "$linked/dgs/dangling"
  ln -s 'real directory' "$linked/dgs/inside"
  if run_session_hook "$linked" > "$root/output" 2>&1; then
    fail 'unsafe nested parents accepted'
  fi
  for kind in outside dangling file inside; do
    grep -Fq "unsafe destination parent $linked/dgs/$kind" "$root/output" ||
      fail "unsafe $kind parent not reported"
  done
  assert_same "$root/unsafe expected" "$linked/dgs/file"
  [[ $(readlink "$linked/dgs/outside") == "$root/outside destination" ]] || fail 'outside symlink changed'
  [[ $(readlink "$linked/dgs/dangling") == "$root/absent destination" ]] || fail 'dangling parent changed'
  [[ $(readlink "$linked/dgs/inside") == 'real directory' ]] || fail 'inside symlink changed'
  assert_missing "$root/outside destination/.env"
  assert_missing "$root/absent destination"
  assert_missing "$linked/dgs/real directory/.env"
  assert_same "$primary/.env" "$linked/.env"
}

test_copy_failures() {
  local primary="$root/failure"
  create_repo "$primary"
  printf 'DUMMY_DO_NOT_PRINT\n' > "$primary/.env"
  mkdir -p "$primary/dgs/car-configuration"
  printf 'DUMMY_DO_NOT_PRINT\n' > "$primary/dgs/car-configuration/.env"
  add_worktree "$primary" "$root/failure linked"
  mkdir "$root/failing-bin"
  printf '#!/bin/sh\nexit 25\n' > "$root/failing-bin/cp"
  chmod +x "$root/failing-bin/cp"
  if PATH="$root/failing-bin:$PATH" run_session_hook "$root/failure linked" > "$root/output" 2>&1; then
    fail 'copy failure ignored'
  fi
  grep -q 'failed to copy .env' "$root/output" || fail 'copy failure not reported'
  grep -q 'failed to copy dgs/car-configuration/.env' "$root/output" || fail 'nested copy failure not reported'
  if grep -qE 'DUMMY_DO_NOT_PRINT|DUMMY_PRIVATE_PROMPT' "$root/output"; then
    fail 'private contents printed'
  fi
  add_worktree "$primary" "$root/parent failure linked"
  printf '#!/bin/sh\nexit 25\n' > "$root/failing-bin/mkdir"
  chmod +x "$root/failing-bin/mkdir"
  if PATH="$root/failing-bin:$PATH" run_session_hook "$root/parent failure linked" > "$root/output" 2>&1; then
    fail 'parent creation failure ignored'
  fi
  grep -q 'failed to create destination parent' "$root/output" || fail 'parent creation failure not reported'
  printf '#!/bin/sh\nexit 25\n' > "$root/failing-bin/find"
  chmod +x "$root/failing-bin/find"
  if PATH="$root/failing-bin:$PATH" run_session_hook "$root/failure linked" > "$root/output" 2>&1; then
    fail 'source discovery failure ignored'
  fi
  grep -q 'failed to scan primary checkout' "$root/output" || fail 'source discovery failure not reported'
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
    test_nested_sources_and_discovery_exclusions \
    test_primary_directory_name_is_not_a_candidate \
    test_existing_destinations \
    test_existing_nested_destinations \
    test_unsafe_nested_parents \
    test_copy_failures \
    test_git_hooks_are_untouched \
    test_stow_removal; do
    "$test_case"
    printf 'PASS: %s\n' "$test_case"
  done
}

main

# Upstream pull requests

How a pull request to `philippe44/lms-deezer` looks. This overrides the `/pr` skill's template for upstream pull requests.

## Identity

Every commit on an upstream pull request branch is authored and committed as the user's GitHub identity:

```sh
export GIT_AUTHOR_NAME=themmm GIT_AUTHOR_EMAIL=5096160+themmm@users.noreply.github.com
export GIT_COMMITTER_NAME=themmm GIT_COMMITTER_EMAIL=5096160+themmm@users.noreply.github.com
```

The local git identity on this machine is derived from the hostname and stays out of upstream. For commits that already exist, re-stamp before pushing: `git rebase upstream/main --exec 'git commit --amend --no-edit --reset-author'` with the variables above exported. Done when `git log --format='%an <%ae> | %cn <%ce>' upstream/main..` shows only the identity above.

## Title

`Fix/<short description>` or `Feat/<short description>`, lowercase after the slash, as in upstream #80–#84. Example: `Fix/keep ARL and session tokens out of server.log`.

## Body

Short and in English: the disclaimer, a heading, the root cause, the fix, one verification line. Reference fork issues as `themmm/lms-deezer#<n>`; a bare `#<n>` links to upstream's issue of that number. `Fixes #<n>` only for an upstream issue.

```markdown
**Disclaimer:**

**All code-changes have been made with Claude-code.**

## Fix: <what was broken, in user terms>

<one or two sentences: the symptom and why it matters>

### Root cause

- <where and why, one bullet per cause>

### Fix

- <what changed, one bullet per change>

Verified on LMS <version>: <what was run, before and after in one line>.
```

For a feature, the heading is `## <feature>` and `### Root cause` / `### Fix` become one `###` section per user-visible change, as in upstream #82.

## Before posting

The title and body go to the user as a draft. Open the pull request only after the user's OK on that draft.

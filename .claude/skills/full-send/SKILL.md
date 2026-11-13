---
name: full-send
description: Take the work from its current state to a merged PR with nobody watching. Use only when the user says 'full send'.
---

# Full send

The user is not watching this thread. Your updates and your final message go unread until long after you stop, so you own the work from its current state to a merged PR.

Without a clear "full send" from the user, none of this applies and the normal rules stand.

A full send is the user asking, in the conversation, for:

- The PR to be squash-merged once the merge gate passes. This is the ask `CLAUDE.md` requires before a merge.
- Whatever check Proof needs, without asking first: running the game, `capture`, `export`, a preview scene.

It doesn't cover anything under "Asking the user", and it doesn't answer a permission prompt from the harness.

## Steps

1. **Finish the change** with the smallest change that does what was asked. Fix the case that happened, not every case that could. On `main`, branch first.
2. **Add the tests it needs.** See Tests.
3. **Prove it.** See Proof. End with one `uv run tools/check.py all`.
4. **Open a draft PR** against the latest `main`. The title is a Conventional Commit, since it becomes the squash commit. The body follows `.github/pull_request_template.md`, and Evidence says how you proved each part.
5. **Wait for CI**, fix what fails, and prove each fix before pushing it.
6. **Mark the PR ready for review** once the required checks are green on the head commit. That is what starts the review, so do it once, and not while CI is red or running.
7. **Wait for the review**, then deal with every finding. See Review.
8. **Merge** when the merge gate passes.
9. **Report**: the PR link, the merge commit, your proof, each decision you made for the user, and anything left unproven or unfixed.

Never end your turn between steps 4 and 8 without something set to wake you: nobody will prompt you again. See Waiting.

## Tests

The `gdunit-tests` skill decides whether the change gets a test and which kind. Follow it; in short:

- A fixed bug gets a regression test in the same PR. Write it first and watch it fail without the fix.
- Logic or a flow that is settled (a core system, a menu, anything the ticket or the user calls settled) gets its tests in the same PR.
- A feature still taking shape gets none. Name each untested flow under Evidence.
- A test the change breaks gets fixed in the same PR. Never skip or delete one to get green.

When you decide a change needs no test, say why in the PR body.

## Proof

Proof is something you observed yourself in this session. Use the most direct kind the change allows:

- A bug: reproduce it, apply the fix, watch the same reproduction pass. The regression test is that reproduction when it can be.
- Logic: the suites for what you touched, then `check.py all`.
- A balance number: `uv run tools/balance.py`, before and after.
- Anything the player sees: `check.py capture` the scene (or its preview scene), open the frame and look at it. Green tests don't prove the screen looks right. Publish the frame with `check.py evidence` and put the line under Evidence.

A frame can't show motion or sound. When that is all that's unproven and the rest of the gate passes, merge, and write "Needs a visual check: `<scene>`" in the PR body and the report. When you can't prove that the behaviour itself works, you can't merge: ask the user.

## Waiting

- **Cloud session:** subscribe to the PR's activity right after opening it. CI results and review comments arrive as events and wake you. Also schedule a check-in a few minutes out as a safety net each time you go idle, in case an event is missed.
- **Local session:** wait for CI with `gh pr checks <n> --watch`. Nothing watches for the review, so schedule a wake-up about three minutes after marking the PR ready and read the PR's comments then.

When a wait runs past 30 minutes with nothing new, look at the PR directly before waiting longer. A review that hasn't arrived an hour after the PR was marked ready isn't coming: ask the user.

## Review

Marking the PR ready starts the user's scheduled code review. It usually lands within a few minutes and posts under the user's own GitHub account, so tell it apart by time, not author: it is whatever arrives after you marked the PR ready. It is finished when either of these exists:

- one or more inline review comments, each tagged **Important**, **Nit** or **Pre-existing**, or
- a PR comment saying no issues were found.

Read the inline comments and the PR's plain comments both. Then, for each finding:

1. **Check it against the code.** The reviewer is sometimes wrong, and sometimes retracts a finding in a reply; read the whole thread.
2. **Important and real:** fix it, with a regression test when it's a bug, and prove the fix.
3. **Nit and real:** fix it when the fix is small and safe. Otherwise say why not.
4. **Pre-existing:** leave it out of this PR and list it in the report.
5. **Wrong:** change nothing and say why.
6. **Reply on the thread** with what you did, one or two lines, then resolve the thread.

Push all fixes as one commit when you can, then wait for CI on the new head. Pushing doesn't start a second review, and you don't ask for one: your proof and CI cover the fixes. Never flip the PR back to draft to get another round.

A finding you can neither fix nor show to be wrong blocks the merge: ask the user.

## Merge gate

All of these hold on the head commit:

- Your proof covers every change in the diff, review fixes included.
- The required checks are green: `gdUnit4 tests` and `Lint, load check, smoke run`. The preview build isn't required; a red one still gets a look, since it means the Web export broke.
- The review has finished, and every finding is fixed or answered and its thread resolved.
- No human review requests changes, and no human comment is unanswered.
- The PR is open, not a draft, and GitHub reports it mergeable. When it conflicts with `main`, merge `main` into the branch, resolve, prove again and wait for CI. Never force-push.

Then squash-merge, and confirm GitHub reports the PR merged. Never bypass branch protection.

## Asking the user

A question in a normal message goes unseen and the thread looks done. Ask with the harness's question tool (`AskUserQuestion`) so the thread shows it is waiting. Put everything in the question: the PR link, what blocks you, the options, your recommendation first.

Ask only when you can't continue alone:

- You can't prove the change.
- The merge gate can't pass and you can't fix why.
- The next step is outside the grant: deleting data, changing anything outside the repo, closing a PR, force-pushing, touching another PR's branch.
- The goal is ambiguous in a way that changes the result.
- Another PR makes this one obsolete.

Decide everything else yourself and list those decisions in the report.

When there's no question tool, or it returns no answer, take the safe path: leave the PR open and unmerged, and start your final message with the question.

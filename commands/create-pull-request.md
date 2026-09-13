Create a pull request for the current branch.

# PREPARE
1. Check current branch and status
   - !git branch --show-current
   - !git status --short
2. Verify remote tracking
   - !git branch -vv | grep "^*"
3. Show uncommitted changes if any
   - !git diff --stat
4. Show commits to be included
   - !git log origin/main..HEAD --oneline

# CREATE PR
1. Push branch if needed
   - !git push -u origin HEAD
2. Create pull request
   ```bash
   gh pr create --title "Brief description of changes" --body "$(cat <<'EOF'
   ## Summary
   - Key change 1
   - Key change 2
   - Key change 3

   ## Test plan
   - [ ] Test step 1
   - [ ] Test step 2
   - [ ] Test step 3

   Generated with [Devin](https://devin.ai)
   EOF
   )"
   ```

# VERIFY
1. Check PR status
   - !gh pr status
2. View PR in browser
   - !gh pr view --web
3. Request reviewers if needed
   - !gh pr edit --add-reviewer @username
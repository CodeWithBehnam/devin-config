Analyze git history and identify patterns in development.

GATHER DATA:
! git shortlog -sn --all | head -10
! git log --format="%ad" --date=format:"%Y-%m-%d" | sort | uniq -c | tail -20
! git log --pretty=format: --name-only | sort | uniq -c | sort -rg | head -10
! git log --oneline --all | head -20
! git branch -a --sort=-committerdate | head -10

ANALYZE:
- Examine commit frequency trends and identify peak development periods
- Review commit message quality and consistency
- Identify files with highest change frequency (potential refactoring candidates)
- Analyze author contribution patterns and collaboration
- Check for large commits that might indicate bulk changes
- Look for patterns in branch naming and lifecycle

REPORT:
- Provide summary statistics (total commits, active contributors, average commits/day)
- Highlight development velocity trends
- Identify potential technical debt areas (frequently changed files)
- Note any concerning patterns (e.g., unclear commit messages, irregular activity)
- Suggest improvements for commit practices and collaboration
- Flag any anomalies in development patterns
# Currently fetches in a very inefficient way:

- last week number of prs in state open
- percentage of reviewed prs per user
- average time to resolve a pr

# Depends on octokit gem

`gem install octokit`

# Run

`ruby fetch_prs.rb <github org>/<repo> <github personal token> (<cut_off_date>)`

e.g.

`ruby fetch_prs.rb PerxTech/perx-api your-personal-token 2020-07-01`

# Getting a PAT (personal access token)

visit <https://github.com/settings/tokens> and create one with `repo` access

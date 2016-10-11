# GitHub Authorized Keys
Sync your `authorized_keys` file with your GitHub team

##Public Key Management
Public key management is pretty terrible. A new hire comes onboard, someone leaves the company for greener pastures, or it's 3am and you have to pull out your personal laptop to do some work... If you have more than one server, a team larger than one, or more than one physical device... it's just not that much fun.

People already manage their personal keys through GitHub. And GitHub already manages team member access to your code. This script attempts to bridge the gap and sync the public keys associated with your team members' GitHub profiles with your server's `authorized_keys` file.

###How It Works
There needs to be one constant user that is a member of your organization that can create an access code with the `read:org` scope. I highly recommend this constant user be a bot account (Jenkins user or other build bot, perhaps?). Mostly because bots can't give notice.

That user's access code is then used to query GitHub's API to return the list of users of a specific team. Once you know all the members of a specific team, you can get a list of their public keys by making a GET request to https://github.com/USERNAME.keys

For example, my public keys can be found at https://github.com/sturgill.keys

You can find out your team's numeric ID by making a GET request to:
https://api.github.com/orgs/YOUR_ORG_NAME_HERE/teams?access_token=USER_ACCESS_TOKEN_HERE

###How It Works (2)
In addition to grabbing public keys from team members, there is also a need to have some persistent keys. For example, when you associate an AWS managed key pair with a specific EC2 instance. Simply put all keys that should exist outside of GitHub (and should always persist) in `~/.ssh/static_authorized_keys`. This script copies the contents of that file directly into `~/.ssh/authorized_keys` and then adds the keys found from GitHub.

###Environment Variables
There are four environment variables that control this script:

- ghkeys_ignore_users
  - Comma-separated list of GitHub users within the team that should _not_ be added to the `authorized_keys` file
  - e.g., a bot
  - Optional
- ghkeys_teams
  - Comma-separated list of GitHub teams that you want to import membership
  - e.g., 1234,5678
  - Required
- ghkeys_access_token
  - The access token that has `read:org` scope
  - Required
- ghkeys_ssh_directory
  - The full unqualified path to the user's .ssh directory
  - E.g., /home/ubuntu/ssh
  - Required

###Example
```
ghkeys_ignore_users=deploy-bot ghkeys_teams=1234 ghkeys_access_token=canyoukeepasecret ghkeys_ssh_directory=/home/ubuntu/.ssh ruby /path/to/sync-keys.rb
```

Crontab
```
ghkeys_ignore_users=deploy-bot
ghkeys_teams=1234
ghkeys_access_token=canyoukeepasecret
ghkeys_ssh_directory=/home/ubuntu/.ssh

@hourly ruby /path/to/sync-keys.rb
```

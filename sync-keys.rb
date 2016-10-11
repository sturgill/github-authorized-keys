#!/usr/bin/env ruby

require "json"
require "net/http"
require "uri"

def team_member_keys(access_token, team_id, ignore)
  uri = URI.parse("https://api.github.com/teams/#{team_id}/members?access_token=#{access_token}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new(uri.request_uri)
  response = http.request(request)
  return [] unless response.code == "200"

  result = JSON.parse(response.body)

  result.inject({}) do |hsh, member|
    unless ignore.include?(member["login"])
      key_uri = URI.parse("https://github.com/#{member["login"]}.keys")
      key_http = Net::HTTP.new(key_uri.host, key_uri.port)
      key_http.use_ssl = true

      key_request = Net::HTTP::Get.new(key_uri.request_uri)
      key_response = key_http.request(key_request)

      if key_response.code == "200"
        hsh[member["login"]] = key_response.body.split("\n")
      end
    end

    hsh
  end
end

ignore = (ENV['ghkeys_ignore_users'] || '').split(',')
teams = (ENV['ghkeys_teams'] || '').split(',')
access_token = ENV['ghkeys_access_token']
ssh_directory = ENV['ghkeys_ssh_directory']

raise "At least one team is required" unless teams.length > 0
raise "Access token required" if access_token.nil? || access_token == ""
raise "Path to ssh directory required" if ssh_directory.nil? || ssh_directory == ""

github_data = teams.inject({}) do |hsh, team|
  hsh.merge team_member_keys(access_token, team, ignore)
end

github_keys = github_data.keys.sort.collect do |username|
  ["", "# GitHub User: #{username}", github_data[username]]
end.flatten

# We only want to modify the authorized_keys file if there are keys to
# authorize. If the array is empty, it probably means something got screwed
# up along the way (network issues, etc). And if our team _really_ has
# zero members, no one will be around to care about this any way...
if github_keys.length > 0
  # ~/.ssh/static_authorized_keys contains a list of keys that should
  # always be present, even if not associated with a member of any
  # GitHub team we just processed. We'll add that file in its entirety
  # to the top of ~/.ssh/authorized_keys and then add the keys we
  # got back from GitHub.
  #
  # A use case would be a public key associated with a shared private
  # key that's stored in LastPass (e.g., an AWS generated key pair).
  static_keys_path = "#{ssh_directory}/static_authorized_keys"
  static_keys = File.exist?(static_keys_path) ? File.read(static_keys_path).split("\n") : []

  File.open("#{ssh_directory}/authorized_keys", "w+") do |authorized|
    authorized.puts static_keys
    authorized.puts github_keys
  end
else
  # TODO: log to Slack or similar
end

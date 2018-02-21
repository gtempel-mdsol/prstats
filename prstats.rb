#!/usr/bin/env ruby
# frozen_string_literal: true

# print stats who applied 'ready to merge' label to last group of closed PRs
# TODO:
# * the first/last timestamps are from when the issues were created, not the event stream
# * if you apply same label a few times, you get credit a few times. as long as there are ENGs with zero... that's fine
# * tag only PRs count too, should cut those out

require 'octokit' # gem install octokit -v 4.2.0
require 'pry-byebug'
require 'set' # gft 2018-02-14

# list of ENGs to include in stats
ENGS = %w[batter cherbst-medidata Dennis-mdsol gayarra-mdsol jstauter-mdsol mahmed-mdsol oromanova-mdsol
          shelfgott-mdsol umerkulovb yzhangmedidata gtempel-mdsol].freeze

# the tag we check for
TAG = 'Ready to Build'

class Result < Hash
  def <<(issue_event)
    self[issue_event['actor']['login']] ||= 0
    self[issue_event['actor']['login']] += 1
  end
end

client = Octokit::Client.new(access_token: ENV['GITHUB_AUTH_TOKEN'])

issues = client.issues('mdsol/balance', per_page: 50, state: 'closed')

puts "found #{issues.count} issue(s)"
puts "first issue: #{issues.first['created_at']}"
puts "last issue: #{issues.last['created_at']}"

# define a starting count for all ENGs, so if they did zero we see it
results = Result.new(0)

# gft 2018-02-14
event_types = SortedSet.new
events_by_engineer = ENGS.each_with_object({}) { |eng, collection| collection[eng] = SortedSet.new; }

issues.each do |issue|
  puts "working on issue #{issue['number']}"

  issue_events = client.issue_events('mdsol/balance', issue[:number])
  # get events for that issue
  issue_events.each do |issue_event|
    eng = issue_event['actor']['login']

    event_types << issue_event['event']
    events_by_engineer[eng] << issue_event['event'] if events_by_engineer.key?(eng)

    if issue_event['event'] == 'labeled' && issue_event['label']['name'] == TAG
      puts "issue #{issue['number']}: found label event for #{issue_event['actor']['login']}"
      results << issue_event
    end
  end
end

leader_board = ENGS.sort_by { |eng| results[eng] }.reverse

div = '#' * 74

puts div
puts "number of tagged PRs since #{issues.last['created_at']}"
puts div

leader_board.each do |eng|
  puts "#{results[eng]} #{eng}"
end

puts div

# gft 2018-02-14
puts 'event types: ' + event_types.to_a.to_s

puts div

puts 'detail info: '
leader_board.each do |eng|
  puts "#{results[eng]} #{eng}: #{events_by_engineer[eng].to_a}"
end

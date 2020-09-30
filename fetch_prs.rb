require 'octokit'
require 'byebug'

class PerxGitMetrics
  attr_reader :client, :repo, :people_percent, :people_count

  def initialize(repo, token, cut_off_date)
    @repo = repo
    @client = Octokit::Client.new(access_token: token)
    @client.auto_paginate = true
    @cut_off_date = cut_off_date
  end

  def open_prs_count
    from = Date.today - 7
    to = Date.today
    open_during_last_week_count = {}

    (from...to).each do |date|
      non_draft_prs.each do |perx_pr|
        if perx_pr.created_at < (date+1).to_time
          if !perx_pr.resolved? || !(perx_pr.resolved_at < (date+1).to_time)
            open_during_last_week_count[date] ||= DailyPrCount.new(date)
            open_during_last_week_count[date].increment_count
          end
        end
      end
    end
    open_during_last_week_count.values
  end

  def reviewers_count
    @people_count = {}
    reviewed_prs.each do |pr_number, stats|
      stats[:total].each do |person|
        @people_count[person] ||= 0
        @people_count[person] += 1
      end
    end

    @people_percent = {}
    @people_count.each do |person, value|
      @people_percent[person] = (value*1.0/non_draft_prs.count)*100
    end
    @people_percent
  end

  def percentage_of_prs_with_min_review_count(minimum_count)
    prs_count_with_min_review = reviewed_resolved_prs.values.count { |pr| pr[:count] >= minimum_count }
    (prs_count_with_min_review*1.0/reviewed_resolved_prs.count)*100
  end

  def average_time_to_resolve
    res = resolved_prs.map do |pr|
      (pr.resolved_at - pr.created_at)/60
    end
    res.compact!
    res.sum / res.count
  end

  def non_draft_prs
    return @non_draft_prs if @non_draft_prs

    issues = client.search_issues(search_string)
    @non_draft_prs = issues.items.map { |pr| Pr.new(pr) }
    @non_draft_prs
  end

  def reviewed_resolved_prs
    return @reviewed_resolved_prs if @reviewed_resolved_prs

    @reviewed_resolved_prs = {}
    resolved_prs.each do |pr|
      pr_reviews = client.pull_request_reviews(@repo, pr.number)
      reviewers = pr_reviews.map do |pr_review|
        pr_review[:user][:login]
      end.uniq

      @reviewed_resolved_prs[pr.number] = { count: reviewers.count, total: reviewers }
    end
    @reviewed_resolved_prs
  end

  def reviewed_prs
    return @reviewed_prs if @reviewed_prs
    @reviewed_prs = {}
    non_draft_prs.each do |pr|
      pr_reviews = client.pull_request_reviews(@repo, pr.number)
      reviewers = pr_reviews.map do |pr_review|
        pr_review[:user][:login]
      end.uniq

      @reviewed_prs[pr.number] = { count: reviewers.count, total: reviewers }
    end
    @reviewed_prs
  end

  def search_string
    str = "repo:#{@repo} is:pr"
    str += " created:>#{@cut_off_date}" if @cut_off_date
    str
  end

  def resolved_prs
    non_draft_prs.filter(&:resolved?)
  end

  class DailyPrCount
    def initialize(date)
      @date = date
      @count = 0
    end

    def increment_count
      @count += 1
    end

    def to_s
      "#{@date} -> #{@count}"
    end
  end

  class Pr
    def initialize(gh_pr)
      @gh_obj = gh_pr
    end

    def number
      @number ||= @gh_obj.number
    end

    def draft?
      draft
    end

    def resolved?
      !resolved_at.nil?
    end

    def resolved_at
      closed_at || merged_at
    end

    def draft
      @draft ||= @gh_obj.draft
    end

    def created_at
      @gh_obj.created_at
    end

    def closed_at
      @gh_obj.closed_at
    end

    def merged_at
      @gh_obj.merged_at
    end
  end
end

def run(repo, token, cut_off_date)
  perx_prs = PerxGitMetrics.new(repo, token, cut_off_date)
  puts perx_prs.open_prs_count
  puts perx_prs.reviewers_count
  puts perx_prs.average_time_to_resolve
end

if ARGV.count < 2 || ARGV.count > 3
  puts 'wrong args! ruby fetch_prs.rb <github org>/<repo> <github personal token> (<cut_off_date>)'
  exit 1
end

repo = ARGV[0]
token = ARGV[1]
cut_off_date = ARGV[2]
run(repo, token, cut_off_date)

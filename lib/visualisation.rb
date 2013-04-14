class Visualisation
  require 'grit'

  attr_accessor :repo

  #initialize a repo object
  def initialize
    @repo = Grit::Repo.new("#{Rails.root}")
  end

  def branches
    @repo.refs
  end

  def number_of_branches
    @repo.heads.size
  end

  # this does not work...
  def parent_branch_of(branch_name)
    commit_sha1s = `git log #{branch_name} --pretty=format:"%H"`.split("\n")
    commit_sha1s.each do |commit|
      branches = `git branch --contains #{commit}`.split("\n")
      branches.each do |b|
        b.gsub!(/[*]?\s/, '')
        return b if branch_name != b
      end
    end
    return false 
  end

  def branch_contains_commit(branch, commit_sha)
    `git branch --contains #{commit_sha}`.split("\n").each {|b| b.gsub!(/[*]?\s/, '')}.include?(branch)
  end

  def branches_containing_commit(commit_sha)
    `git branch --contains #{commit_sha}`.split("\n").each { |b| b.gsub!(/[*]?\s/, '') }
  end

  def branch_diff_number_commits(branch)
    `git cherry master #{branch}`.split("\n").size
  end  
  
  def branch_diff_size(branch)
    raw_diff_stats = `git diff --numstat master..#{branch}`
    diff_stats = raw_diff_stats.split(/\n/)
    additions = deletions = 0
    diff_stats.each do |line|
      cols = line.split
      additions += cols[0].to_i 
      deletions += cols[1].to_i 
    end

    return additions, deletions
  end

end
class Visualisation
  require 'grit'

  attr_accessor :repo

  #initialize a repo object
  def initialize
    @repo = Grit::Repo.new("#{Rails.root}")
  end

  def branches
    branches_with_remotes
  end

  def branches_with_remotes
    `git branch -a`.split("\n").each { |b| b.gsub!(/[*]?\s/, '') and b.gsub!(/remotes\//, '') }
  end

  def local_branches
    @repo.heads
  end

  def number_of_branches
    @repo.heads.size
  end

  def head_commit_sha(branch)
    `git rev-parse #{branch}`
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

  def repo_branches_merged(remotes = true)
    merged_branches = {}
    compare_branches = remotes ? branches_with_remotes : @repo.heads
    compare_branches.each do |b1|
      b1_merges = {}
      compare_branches.each do |b2|
        next if b1 == b2 || b2.split("/").last == b1 || 
            (merged_branches.has_key?(b2.to_sym) && merged_branches[b2.to_sym].has_key?(b1.to_sym))
        #puts "comparing #{b1} with #{b2}"
        directions = {}
        directions.merge!(:left => true) if branch_merged_with_base?(b1, b2, remotes)
        directions.merge!(:right => true) if right = branch_merged_with_base?(b2, b1, remotes)
        b1_merges.merge!(b2.to_sym => directions)
      end
      merged_branches.merge!(b1.to_sym => b1_merges)
    end
    merged_branches
  end

  def branch_merged_with_base?(base, branch, remotes)
    if remotes 
      `git branch -a --merged #{base} #{branch}`.length > 0
    else
      `git branch --merged #{base} #{branch}`.length > 0
    end
  end
  
  #printout merge commits between base and topic branch
  #`git log #{branch} #{base} --oneline --date-order --merges --reverse -1`

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
class Visualisation
  require 'grit'
  require 'csv'

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

  def branches_containing_commit(commit_sha, remotes = false)
    puts "git branch -a --contains #{commit_sha}"
    if remotes 
      return `git branch -a --contains #{commit_sha}`.split("\n").each { |b| b.gsub!(/[*]?\s/, '') }
    else 
      return `git branch --contains #{commit_sha}`.split("\n").each { |b| b.gsub!(/[*]?\s/, '') }
    end
  end

  def branches_excluding_commit(commit_sha, remotes = false)
    if remotes
      return branches - `git branch --contains #{commit_sha}`.split("\n").each { |b| b.gsub!(/[*]?\s/, '') }
    else
      return branches - `git branch --contains #{commit_sha}`.split("\n").each { |b| b.gsub!(/[*]?\s/, '') }
    end
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
    merge_base_commit = `git merge-base master #{branch}`.gsub("/\n/", '').strip!
    raw_diff_stats = `git diff --numstat #{merge_base_commit} #{branch}`
    diff_stats = raw_diff_stats.split(/\n/)
    additions = deletions = 0
    diff_stats.each do |line|
      cols = line.split
      additions += cols[0].to_i 
      deletions += cols[1].to_i 
    end

    return additions, deletions
  end

  def commits_for_branch(branch_name)
    commits = []
    raw_log = `git log  master..#{branch_name} --max-count 15 --date=short --pretty="%H, %an, %ad, %s"`
    commit_lines = CSV.parse(raw_log)
    i = 1
    last_date = nil
    commit_lines.each_with_index do |commit, id|
      sha1 = commit[0]
      author = commit[1].strip!
      commit_date = commit[2].strip!
      message = commit.slice(3..commit.length-1).join(",").strip!
      if !last_date.nil? && commit_date.to_date == last_date.to_date
        i += 1
      else
        i = 1
      end
      last_date = commit_date
      commit_stats = {:id => id, :date => commit_date, :num => i, :sha => sha1, 
                      :author => author, :message => message}
      commits << commit_stats
      puts commits
    end
    commits
  end

  def merge_base_file_stats(branch_name)
    merge_base_commit = `git merge-base master #{branch_name}`.gsub("/\n/", '').strip!
    `git diff --numstat #{merge_base_commit}`
  end

  def commit_diff_stats(commit_sha)
    `git show #{commit_sha} --numstat --pretty="%n"`.strip!
  end


  def branch_diff_commit_files(commit_sha = nil)
    merge_base_commit = `git merge-base master #{commit_sha}`.gsub("/\n/", '').strip!
    diff_stats = `git diff --numstat #{merge_base_commit} #{commit_sha}`.split(/\n/)
    files = {}
    additions = deletions = 0
    diff_stats.each do |line|
      cols = line.split
      additions += cols[0].to_i 
      deletions += cols[1].to_i 
      files.merge!(cols[2].to_sym => { :add => additions, :del => deletions })
    end
    files.merge!(:total => { :add => additions, :del => deletions })
  end

end
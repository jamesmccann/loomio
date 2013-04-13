class Visualisation
  require 'grit'

  attr_accessor :repo

  #initialize a repo object
  def initialize
    @repo = Grit::Repo.new("#{Rails.root}")
  end

  def branches
    @repo.heads
  end

  def number_of_branches
    @repo.heads.size
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
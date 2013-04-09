class Visualisation
  require 'grit'

  attr_accessor :repo

  vis = Visualisation.new

  #initialize a repo object
  def initialize
    @repo = Grit::Repo.new("#{Rails.root}")
  end

  def number_of_branches
    @repo.heads.size
  end

  def branches
    @repo.heads
  end

  def branch_diff_size(branch)
    raw_diff = `git diff master..#{branch}`
    diff = raw_diff.split(/\n/)
    additions = deletions = 0
    diff.each do |line|
      additions += 1 if line.start_with?("+") && !line.start_with?("+++")
      deletions += 1 if line.start_with?("-") && !line.start_with?("---")
    end

    require 'ruby-debug'    
    debugger

    raw_diff = `git diff master..#{branch} -- Gemfile.lock`
    diff = raw_diff.split(/\n/)
    additions = deletions = 0
    diff.each do |line|
      additions += 1 if line.start_with?("+") && !line.start_with?("+++")
      deletions += 1 if line.start_with?("-") && !line.start_with?("---")
    end

    debugger

    diff
  end

end
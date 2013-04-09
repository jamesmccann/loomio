class Visualisation::BranchStatistics

  attr_reader :repo

  def number_of_branches
    repo.heads.size
  end

end
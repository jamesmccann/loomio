class VisualisationsController < ApplicationController
  require './lib/visualisation'

  def index
    @visualisation = Visualisation.new
  end

  #GET /branches.json
  def branches
    @visualisation = Visualisation.new
    branches = [] 
    total_additions = total_deletions = 0
    @visualisation.branches.each do |branch|
      diff = @visualisation.branch_diff_size(branch.name)
      total_additions += diff.first
      total_deletions += diff.last
      branches << {:name => branch.name, :diff => {:add => diff.first, :del => diff.last}}
    end

    result = {:branches => branches, :diff => {:add => total_additions, :del => total_deletions}}
    respond_to do |format|
      format.json { render :json => result.to_json }
    end
  end

  #GET /contained_branches.json
  def containing_branches
    @visualisation = Visualisation.new
    branches = @visualisation.branches
    contained_branches = {}
    for i in 0..branches.size - 1
      target_branch = branches[i]
      head_sha = target_branch.commit.sha
      for j in 0..branches.size - 1
        next if j == i
        containing_branch = branches[j]
        if @visualisation.branch_contains_commit(containing_branch, head_sha)
          contained_branches.merge!(containing_branch.name.to_sym => target_branch.name)
        end
      end
    end

    respond_to do |format|
      format.json { render :json => contained_branches.to_json }
    end
  end

end

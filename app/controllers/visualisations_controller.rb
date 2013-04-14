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
    branches.each do |target_branch|
      head_sha = target_branch.commit.sha
      branch_names_with_commit = @visualisation.branches_containing_commit(head_sha)
      found_branches = []
      branch_names_with_commit.each do |branch_name|
        found_branches.push(branch_name) unless branch_name == target_branch.name
      end
      contained_branches.merge!(target_branch.name.to_sym => found_branches) unless found_branches.empty?
    end

    respond_to do |format|
      format.json { render :json => contained_branches.to_json }
    end
  end

end

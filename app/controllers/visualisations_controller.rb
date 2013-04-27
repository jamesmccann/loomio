class VisualisationsController < ApplicationController
  require './lib/visualisation'
  layout 'visualisation'

  def index
    @visualisation = Visualisation.new
  end

  #GET /branches.json
  def branches
    @visualisation = Visualisation.new
    branches = [] 
    total_additions = total_deletions = 0
    @visualisation.branches.each do |branch|
      diff = @visualisation.branch_diff_size(branch)
      head_commit = @visualisation.head_commit_sha(branch)
      merged_with_master = @visualisation.branch_contains_commit("master", head_commit)
      total_additions += diff.first
      total_deletions += diff.last
      branches << {:name => branch, :diff => {:add => diff.first, :del => diff.last}, 
                    :merged_with_master => merged_with_master, :hidden => false}
    end

    result = {:branches => branches, :diff => {:add => total_additions, :del => total_deletions}}
    respond_to do |format|
      format.json { render :json => result.to_json }
    end
  end

  #GET /containing_branches.json
  def containing_branches
    @visualisation = Visualisation.new
    branches = @visualisation.branches
    contained_branches = {}
    branches.each do |target_branch|
      head_sha = @visualisation.head_commit_sha(target_branch)
      branch_names_with_commit = @visualisation.branches_containing_commit(head_sha)
      found_branches = []
      branch_names_with_commit.each do |branch_name|
        found_branches.push(branch_name) unless branch_name == target_branch
      end
      contained_branches.merge!(target_branch.to_sym => found_branches) unless found_branches.empty?
    end

    respond_to do |format|
      format.json { render :json => contained_branches.to_json }
    end
  end

  def merged_branches
    @visualisation = Visualisation.new
    merged_branches = @visualisation.repo_branches_merged

    respond_to do |format|
      format.json { render :json => merged_branches.to_json }
    end
  end

end

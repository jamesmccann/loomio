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

  def branches_commit_filters
    @visualisation = Visualisation.new
    include_commit_sha = params[:include]
    exclude_commit_sha = params[:exclude]

    branches = branches_include = branches_exclude = []

    branches_include = @visualisation.branches_containing_commit(include_commit_sha) if include_commit_sha.present?
    branches_exclude = @visualisation.branches_excluding_commit(exclude_commit_sha) if exclude_commit_sha.present?
    puts branches_exclude

    if !branches_include.empty? 
      branches = branches_include - branches_exclude
    else
      branches = branches_exclude
    end

    respond_to do |format|
      format.json { render :json => branches.to_json }
    end
  end

  def branches_excluding_commit
    @visualisation = Visualisation.new
    commit_sha = params[:data][:commit]
    branch_names = @visualisation.branches_excluding_commit(commit_sha)

    respond_to do |format|
      format.json { render :json => branch_names.to_json }
    end
  end

  def commits
    @visualisation = Visualisation.new
    ref = params[:ref]

    #by default we are looking for the last 15 commits
    commits = @visualisation.commits_for_branch(ref)

    respond_to do |format|
      format.json { render :json => commits.to_json }
    end
  end

  def diff_stats
    @visualisation = Visualisation.new
    ref = params[:ref]

    diff_stats = @visualisation.diff_file_stats(ref)

    respond_to do |format|
      format.json { render :json => diff_stats.to_json }
    end    
  end

end

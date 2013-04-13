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

end

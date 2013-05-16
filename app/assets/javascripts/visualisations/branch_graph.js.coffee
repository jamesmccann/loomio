class BranchGraph 
  constructor: ->
    # @initializeD3()
    # @getGraphData()
    # @initializeControls()
    @commitGraph =  new Visualisation.CommitGraph()
    @commitGraph.load("git-vis-2")

  initializeD3: ->
    # set up SVG for D3
    @width = $("#branches-display").width();
    @height = $("#branches-display").height();
    tcolors = d3.scale.category10()
    @body = d3.select("body")
    @svg = @body.select("#branches-display")
              .append("svg")
              .attr("width", @width)
              .attr("height", @height)
    @lastKeyDown = -1;

  getGraphData: ->
    # set up initial nodes and links
    #  - nodes are known by 'id', not by index in array.
    #  - links are always source < target; edge directions are set by 'left' and 'right'.
    $.get "/visualisations/branches.json", (data) ->
      branch_data = data
      $.get "/visualisations/merged_branches.json", (merge_data) ->
        Visualisation.branchGraph.initGraphData(branch_data, merge_data)

  initializeControls: ->
    $("#apply-filters-btn").click () =>
      @apply_filters()
      false

  initGraphData: (branch_data, merge_data) =>
    @branches = branch_data.branches;
    @diff_lines = branch_data.diff;
    console.log(@branches)
    console.log(merge_data)

    @master = undefined
    #remove the master branch from branches array 
    @branches = $.grep(@branches, (el, i) =>
      if el.name is "master"
        @master = el
        return false
      true
    ) 

    percent_diff = 0.0
    total_diff = @diff_lines.add + @diff_lines.del
    average_diff = total_diff / @branches.length
    
    @nodes = []
    @links = []
    @branch_names = {}
    @nodes.push
      id: 0
      branch: @master
      size: 5.0
      reflexive: false
      fixed: true
      x: @width / 2
      y: @height / 2
    @branch_names["master"] = 0
    $.each @branches, (i, obj) =>
      #calculate the percentage diff for this branch
      percent_diff = (obj.diff.add + obj.diff.del) / average_diff
      @nodes.push id: i + 1, branch: obj, size: percent_diff, reflexive: false, hidden: false
      @branch_names[obj.name] = i + 1

    #check for merges/edges for each branch/node
    @linked_nodes = {}
    $.each merge_data, (base_key, base) =>
      $.each base, (branch_key, merged_branch) =>
        if merged_branch.left || merged_branch.right
          @linked_nodes[@branch_names[base_key] + ", " + @branch_names[branch_key]] = 1
          @links.push
            source: @branch_names[base_key]
            target: @branch_names[branch_key]
            left: merged_branch.left
            right: merged_branch.right
            hidden: false

    #store original state
    @all_nodes = @nodes
    @all_links = @links
    @all_branches = @branches
    @all_branch_names = @branch_names

    @initGraph(false)

  initGraph: (redraw) ->
    if redraw is true
      d3.select("svg").remove() 
      @svg = @body.select("#vis-display")
              .append("svg")
              .attr("width", @width)
              .attr("height", @height)
      @recalculate_node_sizes()

    lastNodeId = @nodes.length - 1

    # init D3 force layout
    @force = d3.layout.force()
      .nodes(@nodes)
      .links(@links)
      .size([@width, @height])
      .linkDistance(150)
      .charge(-500)
      .on("tick", @tick)

    # define arrow markers for graph links
    @svg.append('svg:defs').append('svg:marker')
        .attr('id', 'end-arrow')
        .attr('viewBox', '0 -5 10 10')
        .attr('refX', 6)
        .attr('markerWidth', 3)
        .attr('markerHeight', 3)
        .attr('orient', 'auto')
      .append('svg:path')
        .attr('d', 'M0,-5L10,0L0,5')
        .attr('fill', '#999');

    @svg.append('svg:defs').append('svg:marker')
        .attr('id', 'start-arrow')
        .attr('viewBox', '0 -5 10 10')
        .attr('refX', 4)
        .attr('markerWidth', 3)
        .attr('markerHeight', 3)
        .attr('orient', 'auto')
      .append('svg:path')
        .attr('d', 'M10,-5L0,0L10,5')
        .attr('fill', '#999');

    # handles to link and node element groups
    @path = @svg.append('svg:g').selectAll('path')
    @circle = @svg.append('svg:g').selectAll('g');

    # mouse event vars
    @selected_node = null
    @selected_link = null
    @mousedown_link = null
    @mousedown_node = null
    @mouseup_node = null

    @svg.on('mousedown', @mousedown)
      .on('mousemove', @mousemove)
      .on('mouseup', @mouseup)

    #remove the loading div here
    $("#vis-loading").hide();
    @restart()

  resetMouseVars: -> 
    @mousedown_node = null
    @mouseup_node = null
    @mousedown_link = null

  # update force layout (called automatically each iteration)
  tick: -> 
    # draw directed edges with proper padding from node centers
    Visualisation.branchGraph.path.attr "d", (d) ->
      deltaX = d.target.x - d.source.x
      deltaY = d.target.y - d.source.y
      dist = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
      normX = deltaX / dist
      normY = deltaY / dist
      sourcePadding = node_size(d.source) + 7
      targetPadding = node_size(d.target) + 7
      sourceX = d.source.x + (sourcePadding * normX)
      sourceY = d.source.y + (sourcePadding * normY)
      targetX = d.target.x - (targetPadding * normX)
      targetY = d.target.y - (targetPadding * normY)
      "M" + sourceX + "," + sourceY + "L" + targetX + "," + targetY

    Visualisation.branchGraph.circle.attr "transform", (d) ->
      "translate(" + d.x + "," + d.y + ")"

  mousedown: ->
    return
    # prevent I-bar on drag
    #d3.event.preventDefault();
    # because :active only works in WebKit?
    @svg.classed "active", true
    return  if d3.event.ctrlKey or @mousedown_node or @mousedown_link
    @restart()

  mouseup: ->
    return
    # hide drag line
    @drag_line.classed("hidden", true).style "marker-end", ""  if @mousedown_node
    # because :active only works in WebKit?
    @svg.classed "active", false
    # clear mouse event vars
    @resetMouseVars()

  keydown: ->
    d3.event.preventDefault()
    return  if @lastKeyDown isnt -1
    @lastKeyDown = d3.event.keyCode

  # update graph (called when needed)
  restart: ->
    # path (link) group
    @path = @path.data(@links)
    
    # update existing links
    @path.classed("selected", (d) ->
      d is @selected_link
    ).style("marker-start", (d) ->
      (if d.left then "url(#start-arrow)" else "")
    ).style "marker-end", (d) ->
      (if d.right then "url(#end-arrow)" else "")
    
    # add new links
    @path.enter().append("svg:path").attr("class", "link").classed("selected", (d) ->
      d is @selected_link
    ).style("marker-start", (d) ->
      (if d.left then "url(#start-arrow)" else "")
    ).style("marker-end", (d) ->
      (if d.right then "url(#end-arrow)" else "")
    )
    
    # remove old links
    @path.exit().remove()

    # circle (node) group
    # NB: the function arg is crucial here! nodes are known by id, not by index!
    @circle = @circle.data(@nodes, (d) ->
      d.id
    )

    #hide filtered nodes
    @circle.selectAll("circle").select((d) ->
      d.branch.hidden == false ? this : null
    )

    # update existing nodes (reflexive & selected visual states)
    @circle.selectAll("circle").style("fill", (d) ->
      (if (d is @selected_node) then d3.rgb(branch_color(d)).brighter().toString() else d3.rgb(branch_color(d)))
    ).classed "reflexive", (d) ->
      d.reflexive

    @circle.selectAll("text")
      .attr("x", (d) -> node_size(d)+5)
      .attr("y", (d) -> node_size(d)/2)
    
    # add new nodes
    g = @circle.enter().append("svg:g")
    
    # reposition drag line
    vis = @
    g.append("svg:circle").attr("class", "node")
      .attr("branch", (d) -> d.branch.name)
      .attr("r", (d) -> node_size(d))
      .style("fill", (d) -> (d3.rgb(branch_color(d))))
      .style("stroke", (d) -> d3.rgb(branch_color(d)).darker().toString())
      .classed("reflexive", (d) -> d.reflexive)
      .on("mouseover", (d) ->
        d3.selectAll("circle").filter((d2) -> d != d2).transition().style "opacity", "0.25"
        d3.selectAll("text").filter((d2) -> d != d2).transition().style "opacity", "0.10"
        d3.selectAll("path.link").filter((d2) -> d != d2).transition().style "opacity", "0.10")
      .on("mouseout", (d) ->
        d3.selectAll("circle").transition().style "opacity", "1"
        d3.selectAll("text").transition().style "opacity", "1"
        d3.selectAll("path").transition().style "opacity", "1")
      .on("mousedown", (d) ->
        vis.mousedown_node = d
        d3.selectAll("circle").filter((d2) -> 
          vis.neighbouring(vis.dom_node(d)[0].__data__.id, vis.dom_node(d2)[0].__data__.id)
          ).transition().style "opacity", "1"
        d3.selectAll("text").filter((d2) -> 
          vis.neighbouring(vis.dom_node(d)[0].__data__.id, vis.dom_node(d2)[0].__data__.id)
        ).transition().style "opacity", "1"
        d3.selectAll("path.link").filter((d2) -> 
          return false if d2 is undefined
          return true if d2.source == vis.mousedown_node || d2.target == vis.mousedown_node
        ).transition().style "opacity", "1")
      .on("dblclick", (d) ->
        vis.commitGraph.load(d.branch.name) 
      )
      .call(@force.drag())
    
    # show node IDs
    g.append("svg:text")
      .attr("x", (d) -> node_size(d)+5)
      .attr("y", (d) -> node_size(d)/2)
      .attr("class", "name").text (d) ->
        d.branch.name + " " + d.branch.diff.add + " / " + d.branch.diff.del
    
    # remove old nodes
    @circle.exit().remove()
    
    # set the graph in motion
    @force.start()

  clear_filters : () ->
    @nodes = @all_nodes
    @links = @all_links
    @branches = @all_branches
    @branch_names = @all_branch_names

  apply_filters: () ->
    @clear_filters()

    #filter branches merged with master
    if $("#filter_merged_checkbox").is(":checked")
      @filter_merged_with_master()

    #filter branches merged with master
    if $("#filter_remotes_checkbox").is(":checked")
      @filter_remotes()

    #filter branches by name
    filter_name_query = $("#filter_names_input").val()
    @filter_branch_names(filter_name_query) if filter_name_query.length > 0

    additional_requests = false
    #filter branches containing commit
    show_commit_sha = $("#show_commit_input").val()
    exclude_commit_sha = $("#exclude_commit_input").val()

    if show_commit_sha.length > 0 || exclude_commit_sha.length > 0
      additional_requests = true
      @filter_branch_commits(show_commit_sha, exclude_commit_sha)
    
    # if we arent making any more requests for this data then
    # restart, otherwise the additional requests callback will make restart call
    if !additional_requests
      @restart()

  dom_node: (data) ->
    return if !data.branch
    $("circle[branch=" + "'#{data.branch.name}'" + "]")

  filter_merged_with_master: () ->
    @nodes = $.grep @nodes, (node, i) =>
      if node.branch.merged_with_master is true
        return true if node.branch.name == "master"
        @links = $.grep @links, (link, i) ->
          return false if link.source == node or link.target == node
          true
        @branches = $.grep @branches, (branch, i) ->
          return false if branch == node.branch
          true
        @branch_names = $.grep @branch_names, (name, i) ->
          return false if name == node.branch.name
          true
        return false
      true

  filter_remotes: () ->
    @nodes = $.grep @nodes, (node, i) =>
      if node.branch.remote is true
        return true if node.branch.name == "master"
        @links = $.grep @links, (link, i) ->
          return false if link.source == node or link.target == node
          true
        @branches = $.grep @branches, (branch, i) ->
          return false if branch == node.branch
          true
        @branch_names = $.grep @branch_names, (name, i) ->
          return false if name == node.branch.name
          true
        return false
      true

  filter_branch_names: (query) ->
    @nodes = $.grep @nodes, (node, i) =>
      if node.branch.name.indexOf(query) == -1
        return true if node.branch.name == "master"
        @links = $.grep @links, (link, i) ->
          return false if link.source == node or link.target == node
          true
        @branches = $.grep @branches, (branch, i) ->
          return false if branch == node.branch
          true
        @branch_names = $.grep @branch_names, (name, i) ->
          return false if name == node.branch.name
          true
        return false
      true        

  filter_branch_commits: (include_commit_sha, exclude_commit_sha) ->
    json_data = {include: include_commit_sha, exclude: exclude_commit_sha}
    $.get "/visualisations/branches_commit_filters.json", json_data, (data) =>
      branch_names = data
      @nodes = $.grep @nodes, (node, i) =>
        if $.inArray(node.branch.name, branch_names) is -1
          return true if node.branch.name == "master"
          @links = $.grep @links, (link, i) ->
            return false if link.source == node or link.target == node
            true
          @branches = $.grep @branches, (branch, i) ->
            return false if branch == node.branch
            true
          @branch_names = $.grep @branch_names, (name, i) ->
            return false if name == node.branch.name
            true
          return false
        true
      @restart() 

  branch_color = (node) ->
    return "#1f77b4"  if node.branch.name is "master"
    return "#9CDECD" if node.branch.merged_with_master
    #color based on additions and deletions
    branch_diff = node.branch.diff.add - node.branch.diff.del
    if branch_diff > 100
      "#6ACD72"
    else if branch_diff > 0 && branch_diff <= 100
      "#FFF48F"
    else
      "#C3554B"

  node_size = (node_data) ->
    rad = 5 * node_data.size

    rad = 5 if rad < 5 
    rad = 20 if rad > 20
    return rad

  recalculate_node_sizes: () ->
    percent_diff = 0.0
    total_diff = 0.0
    # recalculate total diff of all filtered branches
    $.each @branches, (i, branch) ->
      total_diff += branch.diff.add + branch.diff.del
    average_diff = total_diff / @branches.length

    # recalculate size for each node based on new average
    $.each @nodes, (i, node) ->
      if node.branch.name != "master"
        node.size = (node.branch.diff.add + node.branch.diff.del) / average_diff

  neighbouring: (node_id, other_id) ->
    @linked_nodes[node_id + ", " + other_id] == 1 ||
      @linked_nodes[other_id + ", " + node_id] == 1 ||
        node_id == other_id


Visualisation.BranchGraph = BranchGraph
Visualisation.branchGraph = new BranchGraph()

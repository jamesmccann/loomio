class BranchGraph 
  constructor: ->
    @initializeD3()
    @initializeGraphData()

  initializeD3: ->
    # set up SVG for D3
    @width = 960
    @height = 900
    tcolors = d3.scale.category10()
    @body = d3.select("body")
    @svg = @body.select("#vis-display")
              .append("svg")
              .attr("width", @width)
              .attr("height", @height)
    @lastKeyDown = -1;

  initializeGraphData: ->
    # set up initial nodes and links
    #  - nodes are known by 'id', not by index in array.
    #  - links are always source < target; edge directions are set by 'left' and 'right'.
    $.get "/visualisations/branches.json", (data) ->
      branch_data = data
      $.get "/visualisations/merged_branches.json", (merge_data) ->
        Visualisation.branchGraph.initGraphData(branch_data, merge_data)

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
      size: 1.0
      reflexive: false
    @branch_names["master"] = 0
    $.each @branches, (i, obj) =>
      #calculate the percentage diff for this branch
      percent_diff = (obj.diff.add + obj.diff.del) / average_diff
      @nodes.push id: i + 1, branch: obj, size: percent_diff, reflexive: false
      @branch_names[obj.name] = i + 1

    #check for merges/edges for each branch/node
    $.each merge_data, (base_key, base) =>
      $.each base, (branch_key, merged_branch) =>
        if merged_branch.left || merged_branch.right
          @links.push
            source: @branch_names[base_key]
            target: @branch_names[branch_key]
            left: merged_branch.left
            right: merged_branch.right

    console.log("links")
    console.log(@links)

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
        .attr('fill', '#000');

    @svg.append('svg:defs').append('svg:marker')
        .attr('id', 'start-arrow')
        .attr('viewBox', '0 -5 10 10')
        .attr('refX', 4)
        .attr('markerWidth', 3)
        .attr('markerHeight', 3)
        .attr('orient', 'auto')
      .append('svg:path')
        .attr('d', 'M10,-5L0,0L10,5')
        .attr('fill', '#000');

    # line displayed when dragging new nodes
    @drag_line = @svg.append('svg:path')
      .attr('class', 'link dragline hidden')
      .attr('d', 'M0,0L0,0');

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
      sourcePadding = (if d.left then 17 else 12)
      targetPadding = (if d.right then 17 else 12)
      sourceX = d.source.x + (sourcePadding * normX)
      sourceY = d.source.y + (sourcePadding * normY)
      targetX = d.target.x - (targetPadding * normX)
      targetY = d.target.y - (targetPadding * normY)
      "M" + sourceX + "," + sourceY + "L" + targetX + "," + targetY

    Visualisation.branchGraph.circle.attr "transform", (d) ->
      "translate(" + d.x + "," + d.y + ")"

  mousedown: ->
    # prevent I-bar on drag
    #d3.event.preventDefault();
    # because :active only works in WebKit?
    @svg.classed "active", true
    return  if d3.event.ctrlKey or @mousedown_node or @mousedown_link
    @restart()

  mousemove: ->
    return  unless Visualisation.branchGraph.mousedown_node
    # update drag line
    Visualisation.branch_graph.drag_line.attr "d", "M" + @mousedown_node.x + "," + @mousedown_node.y + "L" + d3.mouse(this)[0] + "," + d3.mouse(this)[1]
    @restart()

  mouseup: ->
    # hide drag line
    @drag_line.classed("hidden", true).style "marker-end", ""  if @mousedown_node
    # because :active only works in WebKit?
    @svg.classed "active", false
    # clear mouse event vars
    @resetMouseVars()

  spliceLinksForNode: (node) ->
    toSplice = @links.filter((l) ->
      l.source is node or l.target is node
    )
    toSplice.map (l) ->
      @links.splice @links.indexOf(l), 1

  keydown: ->
    d3.event.preventDefault()
    return  if @lastKeyDown isnt -1
    @lastKeyDown = d3.event.keyCode
    # # ctrl
    # if d3.event.keyCode is 17
    #   circle.call force.drag
    #   svg.classed "ctrl", true
    # return  if not selected_node and not selected_link
    # switch d3.event.keyCode
    #   # backspace
    #   when 8, 46 # delete
    #     if selected_node
    #       nodes.splice nodes.indexOf(selected_node), 1
    #       spliceLinksForNode selected_node
    #     else links.splice links.indexOf(selected_link), 1  if selected_link
    #     selected_link = null
    #     selected_node = null
    #     restart()

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
    ).on "mousedown", (d) ->
      return  if d3.event.ctrlKey
      # select link
      @mousedown_link = d
      if @mousedown_link is @selected_link
        @selected_link = null
      else
        @selected_link = @mousedown_link
      @selected_node = null
      restart()
    
    # remove old links
    @path.exit().remove()
    
    # circle (node) group
    # NB: the function arg is crucial here! nodes are known by id, not by index!
    @circle = @circle.data(@nodes, (d) ->
      d.id
    )
    
    # update existing nodes (reflexive & selected visual states)
    @circle.selectAll("circle").style("fill", (d) ->
      (if (d is @selected_node) then d3.rgb(branch_color(d)).brighter().toString() else d3.rgb(branch_color(d)))
    ).classed "reflexive", (d) ->
      d.reflexive
    
    # add new nodes
    g = @circle.enter().append("svg:g")
    
    # reposition drag line
    g.append("svg:circle").attr("class", "node")
      .attr("r", (d) -> 10 * d.size)
      .style("fill", (d) -> (if (d is @selected_node) then d3.rgb(branch_color(d)).toString() else d3.rgb(branch_color(d))))
      .style("stroke", (d) -> d3.rgb(branch_color(d)).darker().toString())
      .classed("reflexive", (d) -> d.reflexive)
      .on("mouseover", (d) ->
        return  if not @mousedown_node or d is @mousedown_node
        d3.select(this).attr "transform", "scale(1.1)")
      .on("mouseout", (d) ->
        return  if not @mousedown_node or d is @mousedown_node
        d3.select(this).attr "transform", "")
      .on("mousedown", (d) ->
        return  if d3.event.ctrlKey
        @mousedown_node = d
        if @mousedown_node is @selected_node
          @selected_node = null
        else
          @selected_node = @mousedown_node
        @selected_link = null
        @drag_line.style("marker-end", "url(#end-arrow)").classed("hidden", false).attr "d", "M" + mousedown_node.x + "," + mousedown_node.y + "L" + mousedown_node.x + "," + mousedown_node.y
        @restart())
      .on "mouseup", (d) ->
        return  unless @mousedown_node
        # needed by FF
        @drag_line.classed("hidden", true).style "marker-end", ""
        # check for drag-to-self
        @mouseup_node = d
        if @mouseup_node is @mousedown_node
          resetMouseVars()
          return
        # unenlarge target node
        d3.select(this).attr "transform", ""
        
        # add link to graph (update if exists)
        # NB: links are strictly source < target; arrows separately specified by booleans
        source = undefined
        target = undefined
        direction = undefined
        if @mousedown_node.id < @mouseup_node.id
          source = @mousedown_node
          target = @mouseup_node
          direction = "right"
        else
          source = @mouseup_node
          target = @mousedown_node
          direction = "left"
        link = undefined
        link = @links.filter((l) ->
          l.source is source and l.target is target
        )[0]
        if link
          link[direction] = true
        else
          link =
            source: source
            target: target
            left: false
            right: false

          link[direction] = true
          @links.push link
        
        # select new link
        @selected_link = link
        @selected_node = null
        @restart()
    
    # show node IDs
    g.append("svg:text").attr("x", 30).attr("y", 4).attr("class", "name").text (d) ->
      d.branch.name + " " + d.branch.diff.add + " / " + d.branch.diff.del
    
    # remove old nodes
    @circle.exit().remove()
    
    # set the graph in motion
    @force.start()

  filter_merged_with_master: ->
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
    @initGraph(true)
    return true

  branch_color = (node) ->
    return "#1f77b4"  if node.branch.name is "master"
    #color based on additions and deletions
    branch_diff = node.branch.diff.add - node.branch.diff.del
    if branch_diff > 0
      "#6ACD72"
    else if branch_diff < 0
      "#C3554B"
    else
      "#9CDECD"

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


Visualisation.BranchGraph = BranchGraph
Visualisation.branchGraph = new BranchGraph()

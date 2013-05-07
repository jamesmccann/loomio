class CommitGraph 
  constructor: (@branch_name) ->
    @initializeD3()
    @getGraphData()
    @initializeControls()

  initializeD3: ->
    # set up SVG for D3
    @width = $("#vis-display").width();
    @height = $("#vis-display").height();
    tcolors = d3.scale.category10()
    @body = d3.select("body")

    @svg = @body.select("#vis-display")
              .append("svg")
              .attr("width", @width)
              .attr("height", @height)

    @force = d3.layout.force().on("tick", @tick).charge((d) ->
      #(if d._children then -d.size / 100 else -40)
      -500
    ).linkDistance((d) ->
      (if d.target.children then 50 else 25)
      #30
    ).size([@height, @width])
    @lastKeyDown = -1;

  getGraphData: ->
    # set up initial nodes and links
    #  - nodes are known by 'id', not by index in array.
    #  - links are always source < target; edge directions are set by 'left' and 'right'.
    vis = @
    $.get "/visualisations/diff_stats.json", {branch: @branch_name}, (data) ->
      vis.update(data)
      # $.get "/visualisations/commit_tree.json", (merge_data) ->
      #   Visualisation.branchGraph.initGraphData(branch_data, merge_data)

  initializeControls: ->
    $("#apply-filters-btn").click () =>
      @apply_filters()
      false

  update: (diff_stats) =>
    @diff_stats = diff_stats
    diff_tree = Visualisation.convertDiffStatsToTree(diff_stats)

    @diff_tree = diff_tree

    #fix the root node
    @diff_tree.fixed = true
    @diff_tree.root = true
    @diff_tree.x = @width / 2
    @diff_tree.y = @height / 2
    @diff_tree.name = @branch_name

    @nodes = @flatten(@diff_tree)
    @links = d3.layout.tree().links(@nodes)

    console.log(@nodes)
    console.log(@links)

    @total = @nodes.length || 1

    # remove existing text (will readd it afterwards to be sure it's on top)
    @svg.selectAll("text").remove()

    # Restart the force layout
    @force.gravity(Math.atan(@total / 50) / Math.PI * 0.4)
      .nodes(@nodes)
      .links(@links)

    # Update the links
    @link = @svg.selectAll("path.link").data(@links, (d) ->
      d.target.name
    )

    # Enter any new links
    @link.enter().insert("svg:path", ".node").attr("class", "link").attr("x1", (d) ->
      d.source.x
    ).attr("y1", (d) ->
      d.source.y
    ).attr("x2", (d) ->
      d.target.x
    ).attr "y2", (d) ->
      d.target.y

    vis = @
    # Exit any old links.
    @link.exit().remove()

    # Update the nodes
    @node = @svg.selectAll("circle.node").data(@nodes, (d) ->
      d.name
    ).classed("collapsed", (d) ->
      (if d._children then 1 else 0)
    )
    @node.transition().attr "r", (d) -> node_size(d) 

    # Enter any new nodes
    g = @node.enter().append("svg:g")
    g.append("svg:circle").attr("class", "node")
      .classed("directory", (d) ->
        (if (d._children or d.children) then 1 else 0)
      ).attr("r", (d) ->
        node_size(d)
      ).style("fill", (d) -> (d3.rgb(vis.node_colour(d))))
      .style("stroke", (d) -> d3.rgb(vis.node_colour(d)).darker().toString())
      .call(@force.drag)
      .on("mouseover", (d) ->
        d3.selectAll("circle").filter((d2) -> d != d2).transition().style "opacity", "0.25"
        d3.selectAll("text").filter((d2) -> d != d2).transition().style "opacity", "0.10"
        d3.selectAll("path").filter((d2) -> d != d2).transition().style "opacity", "0.10")
      .on("mouseout", (d) ->
        d3.selectAll("circle").transition().style "opacity", "1"
        d3.selectAll("text").transition().style "opacity", "1"
        d3.selectAll("path").transition().style "opacity", "1")
      # .on("click", @click)
      # .on("mouseover", @mouseover)
      # .on("mouseout", @mouseout)

    # show node IDs
    g.append("svg:text").attr("x", 30).attr("y", 4).attr("class", "name").text (d) ->
      d.name + " " + d.add + " / " + d.del

    # Exit any old nodes
    @node.exit().remove()

    #remove the loading div here
    $("#vis-loading").hide();
    @force.start()

    # @all_nodes = @nodes
    # @all_links = @links
    # @all_branches = @branches
    # @all_branch_names = @branch_names

  flatten: (root) ->
    nodes = [] 
    i = 0

    recurse = (node) ->
      if node.children
        stats = node.children.reduce((p, v) ->
          p = {add: 0, del: 0} if p == 0 
          stat = recurse(v)
          addv = p.add + stat.add
          delv = p.del + stat.del
          return {add: addv, del: delv}
        , 0)
        node.add = stats.add
        node.del = stats.del
      node.id = ++i if !node.id
      nodes.push(node)
      return {add: node.add, del: node.del}

    root_stats = recurse(root)
    root.add = root_stats.add 
    root.del = root_stats.del
    nodes

  resetMouseVars: -> 
    @mousedown_node = null
    @mouseup_node = null
    @mousedown_link = null

  # update force layout (called automatically each iteration)
  tick: => 
    h = @height
    w = @width
    @link.attr "d", (d) ->
      deltaX = d.target.x - d.source.x
      deltaY = d.target.y - d.source.y
      dist = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
      normX = deltaX / dist
      normY = deltaY / dist
      sourcePadding = node_size(d.source)
      targetPadding = node_size(d.target)
      sourceX = d.source.x + (sourcePadding * normX)
      sourceY = d.source.y + (sourcePadding * normY)
      targetX = d.target.x - (targetPadding * normX)
      targetY = d.target.y - (targetPadding * normY)
      "M" + sourceX + "," + sourceY + "L" + targetX + "," + targetY

    @node.attr "transform", (d) ->
      "translate(" + Math.max(5, Math.min(w - 5, d.x)) + "," + Math.max(5, Math.min(h - 5, d.y)) + ")"

  clear_filters : () ->

  apply_filters: () ->
    @clear_filters()
    @restart()

  node_colour: (node) ->
    return "hsl(" + parseInt(360 / @total * node.id, 10) + ",90%,70%)"
    return "#1f77b4"  if node.root
    #color based on additions and deletions
    diff = node.add - node.del
    if diff > 0
      "#6ACD72"
    else if diff <= 0
      "#C3554B"

  node_size = (node_data) ->
    return 10 if node_data.children
    size = node_data.add + node_data.del

    rad = 5 if rad < 5 
    rad = 20 if rad > 20
    return 5 if !rad
    return rad


Visualisation.CommitGraph = CommitGraph

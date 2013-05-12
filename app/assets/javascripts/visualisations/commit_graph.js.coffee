class CommitGraph 
  constructor: (@branch_name) ->
    @initializeControls()
    @initializeD3()
    @getGraphData()

  initializeD3: ->
    # set up SVG for D3
    @width = @height = $("#commits-display").width()
    tcolors = d3.scale.category10()
    @body = d3.select("body")

    @svg = @body.select("#commits-display")
              .append("svg")
              .attr("width", @width)
              .attr("height", @height)

    @force = d3.layout.force().on("tick", @tick).charge((d) ->
      #(if d._children then -d.size / 100 else -40)
      -400
    ).linkDistance((d) ->
      # (if d.target._children then 50 else 25)
      30
    ).size([@height, @width])
    @mouseover = false
    @drag_in_progress = false

  getGraphData: ->
    # set up initial nodes and links
    #  - nodes are known by 'id', not by index in array.
    #  - links are always source < target; edge directions are set by 'left' and 'right'.
    vis = @
    $.get "/visualisations/diff_stats.json", {ref: @branch_name}, (data) ->
      vis.initializeGraphData(data)
      # $.get "/visualisations/commit_tree.json", (merge_data) ->
      #   Visualisation.branchGraph.initGraphData(branch_data, merge_data)

  initializeControls: ->
    Visualisation.showCommitsSidebar()
    Visualisation.hideBranchesGraph()
    Visualisation.showCommitsGraph()
    Visualisation.hideBranchesSidebar(Visualisation.showCommitsToolbar)
    $("#branch_name").text("Commits for " + @branch_name)

  initializeGraphData: (diff_stats) ->
    @diff_stats = diff_stats
    diff_tree = Visualisation.convertDiffStatsToTree(diff_stats)

    @diff_tree = diff_tree

    #fix the root node
    @diff_tree.fixed = true
    @diff_tree.root = true
    @diff_tree.x = @width / 2
    @diff_tree.y = window.innerHeight / 2
    @diff_tree.name = @branch_name

    @link = @svg.append('svg:g').selectAll('path')
    @node = @svg.append('svg:g').selectAll('g');

    @update()

  update: () =>
    @nodes = @flatten(@diff_tree)
    @links = d3.layout.tree().links(@nodes)
    @total = @nodes.length || 1

    # remove existing text (will readd it afterwards to be sure it's on top)
    # @svg.selectAll("text").remove()

    # Restart the force layout
    @force.gravity(0.1)
      .nodes(@nodes)
      .links(@links)
    
    # Update the links
    @link = @link.data(@links, (d) ->
      d.target.id #link by id not name
    )

    # Enter any new links
    @link.enter().append("svg:path").attr("class", "link").attr("x1", (d) ->
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
    @node = @node.data(@nodes, (d) ->
      d.id #nodes are known by id
    )

    @node.selectAll("circle")
    .classed("collapsed", (d) ->
      (if d._children then 1 else 0)
    ).classed("fixed", (d) ->
      d.fixed
    ).attr("r", (d) ->
      node_size(d)
    )

    @node.transition().attr "r", (d) -> node_size(d) 

    @node_drag = d3.behavior.drag().on("dragstart", @dragstart).on("drag", @dragmove).on("dragend", @dragend)

    # Enter any new nodes
    g = @node.enter().append("svg:g")
    g.append("svg:circle").attr("class", "node")
      .classed("directory", (d) ->
        (if (d._children or d.children) then 1 else 0)
      ).classed("fixed", (d) ->
        d.fixed
      ).attr("r", (d) ->
        node_size(d)
      ).style("fill", (d) -> (d3.rgb(vis.node_colour(d))))
      .style("stroke", (d) -> d3.rgb(vis.node_colour(d)).darker().toString())
      .on("mouseover", (d) ->
        return if vis.drag_in_progress
        vis.mouseover = true
        vis.mouseover_node = d
        d3.selectAll("circle").filter((d2) -> d != d2).transition().style "opacity", "0.25"
        d3.selectAll("text").filter((d2) -> d != d2).transition().style "opacity", "0.10"
        d3.selectAll("path").filter((d2) -> d != d2).transition().style "opacity", "0.10")
      .on("mouseout", (d) ->
        return if vis.drag_in_progress
        vis.mouseover = false
        d3.selectAll("circle").transition().style "opacity", "1"
        d3.selectAll("text").transition().style "opacity", "1"
        d3.selectAll("path").transition().style "opacity", "1")
      .on("click", (d) ->
        d.fixed = false if !d.root && d.fixed 
        vis.update()
      ).on("dblclick", (d) ->
        vis.toggle_children(d)
      )

      g.call(@node_drag)
      # .on("mouseover", @mouseover)
      # .on("mouseout", @mouseout)

    # show node IDs
    g.append("svg:text")
      .attr("x", 30)
      .attr("y", 4)
      .attr("class", "name")
      .text (d) ->
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

  toggle_children: (node) ->
    # Toggle children on click.
    if node.children
      node._children = node.children
      node.children = null
    else
      node.children = node._children
      node._children = null
    @update()

  dragstart: (d, i) =>
    @drag_in_progress = true
    @force.stop() # stops the force auto positioning before you start dragging

  dragmove: (d, i) =>
    d.px += d3.event.dx
    d.py += d3.event.dy
    d.x += d3.event.dx
    d.y += d3.event.dy
    @tick() # this is the key to make it work together with updating both px,py,x,y on d !

  dragend: (d, i) =>
    d.fixed = true # of course set the node to fixed so the force doesn't include the node in its auto positioning stuff
    @mouseover = true #still inside the dropped node
    @drag_in_progress = false
    @update()
    @force.resume()

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
    root.add = root_stats.add || 0
    root.del = root_stats.del || 0
    nodes

  resetMouseVars: -> 
    @mousedown_node = null
    @mouseup_node = null
    @mousedown_link = null

  # update force layout (called automatically each iteration)
  tick: => 
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
      "translate(" + d.x + "," + d.y + ")"

  clear_filters : () ->

  apply_filters: () ->
    @clear_filters()
    @restart()

  node_colour: (node) ->
    if !node.colour
      if node.root
        node.colour = "#1f77b4"
      else
        node.colour = "hsl(" + parseInt(360 / @total * node.id, 10) + ",90%,70%)"
    return node.colour 

  node_size = (node_data) ->
    return 10 if node_data.children
    size = node_data.add + node_data.del
    return Math.pow(size, 2/5) if node_data._children

    rad = 5 if rad < 5 
    rad = 20 if rad > 20
    return 5 if !rad
    return rad


Visualisation.CommitGraph = CommitGraph

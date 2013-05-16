class CommitGraph 
  constructor: () ->
    @initializeControls()
    
  load: (@branch_name) ->
    @initializeD3()
    @getGraphData()
    @getHistData()    
    @loadUI()

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
    vis = @
    $.get "/visualisations/diff_stats.json", {ref: @branch_name}, (data) ->
      vis.initializeGraphData(data)
   
  getHistData: ->
    vis = @
    $.get "/visualisations/commits.json", {ref: @branch_name}, (history_data) ->
      vis.initHistoryGraph(history_data) 

  loadUI: ->
    Visualisation.hideBranchesGraph()
    Visualisation.showCommitsGraph()
    Visualisation.hideBranchesSidebar(Visualisation.showCommitsToolbar)
    $("#branch_name").text("Commits for " + @branch_name)
    $("#commit_sha").text('')
    $("#commit_author").text('')
    $("#commit_message").text('')
    if @branch_name.length > 30
      $("#branch_name").css("font-size": "18px")
    if @branch_name.length > 48
      $("#branch_name").css("font-size": "15px")

  initializeControls: ->
    vis = @
    $("#clear_history_filters").click (event) ->
      event.preventDefault()
      vis.clear_filter()

    $("#back-to-branches-btn").click (event) ->
      event.preventDefault()
      vis.svg.remove()
      vis.history_svg.remove()
      Visualisation.hideCommitsGraph()
      Visualisation.showBranchesGraph()
      Visualisation.hideCommitsToolbar(Visualisation.showBranchesSidebar)

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
    @node = @svg.append('svg:g').selectAll('g')

    @update()

  update: () =>
    @nodes = @flatten(@diff_tree)
    @links = d3.layout.tree().links(@nodes)
    @total = @nodes.length || 1
    @root = @nodes[@nodes.length-1]
    @total_size = @root.add + @root.del

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
      vis.node_size(d)
    )

    @node.selectAll("text")
      .attr("x", (d) -> vis.node_size(d)+5)
      .attr("y", (d) -> vis.node_size(d)/2)

    @node.transition().attr "r", (d) -> vis.node_size(d) 

    @node_drag = d3.behavior.drag().on("dragstart", @dragstart).on("drag", @dragmove).on("dragend", @dragend)

    # Enter any new nodes
    g = @node.enter().append("svg:g")
    g.attr("id", (d) -> nodeId(d.name))
     .attr("class", "node_group")
     .append("svg:circle")
      .attr("class", "node")
      .classed("fixed", (d) -> d.fixed)
      .attr("r", (d) -> vis.node_size(d))
      .style("fill", (d) -> (d3.rgb(vis.node_colour(d))))
      .style("stroke", (d) -> d3.rgb(vis.node_colour(d)).darker().toString())
      .on("mouseover", (d) ->
        return if vis.drag_in_progress || vis.filter_active
        vis.mouseover = true
        vis.mouseover_node = d
        d3.selectAll("circle").filter((d2) -> d != d2).transition().style "opacity", "0.25"
        d3.selectAll("text").filter((d2) -> d != d2).transition().style "opacity", "0.10"
        d3.selectAll("path").filter((d2) -> d != d2).transition().style "opacity", "0.10")
      .on("mouseout", (d) ->
        return if vis.drag_in_progress || vis.filter_active
        vis.mouseover = false
        d3.selectAll("circle").transition().style "opacity", "1"
        d3.selectAll("text").transition().style "opacity", "1"
        d3.selectAll("path").transition().style "opacity", "1")
      .on("click", (d) ->
        if d.root
          vis.svg.selectAll("circle").each (d, i) ->
            d.fixed = false if !d.root
        else
          d.fixed = false if d.fixed 
        vis.update()
      ).on("dblclick", (d) ->
        vis.toggle_children(d)
      )

      g.call(@node_drag)
      # .on("mouseover", @mouseover)
      # .on("mouseout", @mouseout)

    # show node IDs
    g.append("svg:text")
      .attr("x", (d) -> vis.node_size(d)+5)
      .attr("y", (d) -> vis.node_size(d)/2)
      .attr("class", "name")
      .text (d) ->
        if (d.children || d._children) && !d.root
          dir = '/ '
        else
          dir = ' '
        d.name + dir + d.add + " / " + d.del

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
    vis = @
    @link.attr "d", (d) ->
      deltaX = d.target.x - d.source.x
      deltaY = d.target.y - d.source.y
      dist = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
      normX = deltaX / dist
      normY = deltaY / dist
      sourcePadding = vis.node_size(d.source)
      targetPadding = vis.node_size(d.target)
      sourceX = d.source.x + (sourcePadding * normX)
      sourceY = d.source.y + (sourcePadding * normY)
      targetX = d.target.x - (targetPadding * normX)
      targetY = d.target.y - (targetPadding * normY)
      "M" + sourceX + "," + sourceY + "L" + targetX + "," + targetY

    @node.attr "transform", (d) ->
      "translate(" + d.x + "," + d.y + ")"

  initHistoryGraph: (commit_history) ->
    # id => {sha, date, num, author, message}
    # num is the commit number for a date, 1 <= num <= count(commits_for_date)

    wd = $("#history-graph").width()
    ht = $("#history-graph").height()

    # get min/max dates in range, date is sorted in descending date order (newest first)
    max_date = new Date()#getDate(commit_history[0])
    min_date = getDate(commit_history[commit_history.length-1])

    #map dates/nums onto x and y scales
    x_scale = d3.time.scale()
          .domain([d3.time.day.offset(min_date, -1), d3.time.day.offset(max_date, 1)])
          .range([20, wd])

    y_scale = d3.scale.linear()
          .domain([0, 10])
          .range([ht-20, 0])

    xAxis = d3.svg.axis()
                  .scale(x_scale)
                  .orient('bottom')
                  .ticks(5)
                  .tickFormat(d3.time.format('%d %b %y'))
                  .tickSize(1)

    yAxis = d3.svg.axis()
                  .scale(y_scale)
                  .ticks(4)
                  .orient("left")
                  .tickSize(1)

    #create scatterplot
    @history_svg = d3.select("#history-graph")
                     .append("svg")
                     .attr("width", wd+40)
                     .attr("height", ht+20)

    #add x axis
    @history_svg.append('svg:g')
                .attr("transform", "translate(0," + ht + ")")
                .attr("class", "x axis")
                .call(xAxis)

    #add y axis
    @history_svg.append('svg:g')
                .attr("transform", "translate(20, 20)")
                .attr("class", "y axis")
                .call(yAxis)

    @hist_node = @history_svg.append('svg:g').selectAll("g")

    #nodes are known by sha hash
    @hist_node = @hist_node.data commit_history, (d) -> d.id

    vis = @
    g = @hist_node.enter().append('svg:g')
    g.append('svg:circle')
      .attr('cx', (d) -> x_scale(getDate(d)))
      .attr('cy', (d) -> y_scale(d.num)+20)
      .attr("class", "hist_node")
      .attr("id", (d) -> d.id)
      .attr("r", (d) -> 5)
      .style("fill", (d) -> '#1F77B4')
      .style("opacity", (d) -> d.selected ? '100%' : '50%')
      #.style("stroke", (d) -> d3.rgb(vis.node_colour(d)).darker().toString())
      .on("mouseover", (d) ->
        # vis.history_svg.selectAll("circle").filter((d2) -> d != d2).transition().style "opacity", "0.25"
        # append("svg:text").attr("x", 30).attr("y", 4).attr("class", "name").text (d) ->
        #   d.sha
      )
      .on("mouseout", (d) ->
        # vis.history_svg.selectAll("circle").filter((d2) -> d != d2).transition().style "opacity", "1"
      )
      .on("click", (d) ->
        vis.history_svg.selectAll("circle").filter((d2) -> d != d2).transition().style "fill", "#1F77B4"
        d3.select(this).transition().style "fill", "#6ACD72"
        $("#commit_sha").text("Commit: " + d.sha)
        $("#commit_author").text("Made by: " + d.author + ", on " + moment(getDate(d)).format("dddd MMMM Do YYYY"))
        $("#commit_message").text(d.message)
        vis.filter_commit(d.sha)
      )

  clear_filter: () ->
    $("#commit_sha").text('')
    $("#commit_author").text('')
    $("#commit_message").text('')
    @svg.selectAll('g.node_group').transition().style "opacity", "1"
    @svg.selectAll('g.node_group').select('text').transition().style "opacity", "1"
    @svg.selectAll('path').transition().style "opacity", "1"
    @history_svg.selectAll('circle').transition().style 'fill', '#1F77B4'

  filter_commit: (commit_sha) ->
    vis = @
    filter_nodes = null

    $.get "/visualisations/commit_diff_stats.json", {ref: commit_sha}, (history_data) ->
      # simple filter, replaces current graph with commit graph
      # vis.svg.selectAll('g').remove()
      # vis.initializeGraphData(history_data)
      vis.filter_commit_nodes(history_data)

  filter_commit_nodes: (commit_stats) ->
    return if commit_stats == null
    filter_nodes = @flatten(Visualisation.convertDiffStatsToTree(commit_stats))
    vis = @
    # filter out all nodes
    vis.svg.selectAll('g.node_group').transition().style "opacity", "0.25"
    vis.svg.selectAll('g.node_group').select('text').transition().style "opacity", "0"
    vis.svg.selectAll('path').transition().style "opacity", "0.1"

    filtered_names = $.map(filter_nodes, (node) -> 
      return if !node.name
      nodeId(node.name)
    )
    filtered_names.push(nodeId(@branch_name))

    $.each filtered_names, (i, id_name) ->
      return if $("#" + id_name) == []
      dom_node = vis.svg.selectAll(('#' + id_name))
      dom_node.transition().style "opacity", "1"
      dom_node.select('text').transition().style "opacity", "1"

    vis.svg.selectAll('path').filter((d) -> 
      source_name = nodeId(d.source.name)
      target_name = nodeId(d.target.name)
      return true if ($.inArray(source_name, filtered_names) > -1 && $.inArray(target_name, filtered_names) > -1)
      false
    ).transition().style "opacity", "1"

    @filter_active = true

  node_colour: (node) ->
    if !node.colour
      if node.root
        node.colour = "#1f77b4"
      else
        node.colour = "hsl(" + parseInt(360 / @total * node.id, 10) + ",90%,70%)"
    return node.colour 

  node_size: (node_data) ->
    return 10 if node_data.children
    # rad = node_data.add + node_data.del
    # if node_data._children
    #   size = Math.pow(size, 2/5) if node_data._children
    rad = ((node_data.add + node_data.del) / @total_size) * 100

    rad = 5 if rad < 5 
    rad = 30 if rad > 30
    return 5 if !rad
    return rad

  getDate = (d) ->
    new Date(d.date)

  nodeId = (name) ->
    "node_" + name.replace(/[.\/]/g, '-')


Visualisation.CommitGraph = CommitGraph

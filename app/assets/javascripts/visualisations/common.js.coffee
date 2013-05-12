Visualisation.showBranchesSidebar = () ->
  sidebar = $("#sidebar-branches")
  showSidebar(sidebar)

Visualisation.hideBranchesSidebar = (callback) ->
  sidebar = $("#sidebar-branches")
  hideSidebar(sidebar, callback)

Visualisation.showCommitsSidebar = () ->
  sidebar = $("#sidebar-commits")
  showSidebar(sidebar)

Visualisation.hideCommitsSidebar = (callback) ->
  sidebar = $("#sidebar-commits")
  hideSidebar(sidebar, callback)

Visualisation.showBranchesGraph = () ->
  $("#branches-display").show()

Visualisation.hideBranchesGraph = () ->
  $("#branches-display").css("position": "absolute").hide()

Visualisation.showCommitsGraph = () ->
  $("#commits-display").show()

Visualisation.hideCommitsGraph = () ->
  $("#commits-display").hide()

Visualisation.showCommitsToolbar = () ->
  $("#commits-toolbar").show()
  ht = $("#commits-toolbar").outerHeight() 
  $("#commits-toolbar").css("bottom": "#{-ht}px").animate({bottom: "0px"}, 1000)

Visualisation.hideCommitsToolbar = (callback) ->
  ht = $("#commits-toolbar").outerHeight() 
  $("#commits-toolbar").css("position": "absolute").animate({bottom: -ht}, 1000, callback)

hideSidebar = (sidebar, callback) ->
  wd = sidebar.outerWidth()
  sidebar.css("position": "absolute")
  sidebar.animate({ left: -wd } , 500, callback)

showSidebar = (sidebar) ->
  sidebar.css("position": "fixed", "display": "block")
  sidebar.animate({ left: "0px"}, 500)

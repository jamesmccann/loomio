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
  $("#commits-toolbar").css("bottom": "#{-ht}px").animate({bottom: "0px"}, 500).css("display": "block")

Visualisation.hideCommitsToolbar = (callback) ->
  ht = $("#commits-toolbar").outerHeight() 
  $("#commits-toolbar").css("top": "auto")
  $("#commits-toolbar").animate({bottom: -ht}, 500, ->
    $(this).css("display": "none")
    callback.call()
  )

hideSidebar = (sidebar, callback) ->
  wd = sidebar.outerWidth()
  sidebar.css("position": "absolute")
  sidebar.animate({ left: -wd } , 500, callback)

showSidebar = (sidebar) ->
  wd = sidebar.outerWidth()
  sidebar.css("position": "fixed", "display": "block", "left": "#{-wd}px")
  sidebar.animate({ left: "0px"}, 500)

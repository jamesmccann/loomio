Visualisation.convertDiffStatsToTree = (data) ->
  lines = data.split("\n")
  json = {}
  filename = undefined
  size = undefined
  cols = undefined
  elements = undefined
  current = undefined
  lines.forEach (line) ->
    cols = line.split(/\s/)
    add = parseInt(cols[0])
    del = parseInt(cols[1])
    return if !add && !del
    filename = cols[2]
    return if filename is "total"
    return unless filename
    elements = filename.split(/[\/\\]/)
    current = json
    elements.forEach (element) ->
      current[element] = {}  unless current[element]
      current = current[element]

    current.add = add
    current.del = del

  json.children = getChildren(json)
  json

Visualisation.convertAuthorStatsToTree = (data) ->
  lines = data.split("\n")
  json = {}
  filename = undefined
  size = undefined
  cols = undefined
  elements = undefined
  current = undefined
  current_author = undefined
  lines.forEach (line) ->
    return if !line 
    cols = line.split(/\s/)
    console.log cols
    if isNaN(parseInt(cols[0]))
      #author line
      current_author = { email: cols[cols.length-1], name: cols.slice(0, cols.length-2).join(" ") }
      return 

    #parse file line
    add = parseInt(cols[0])
    del = parseInt(cols[1])
    return if !add && !del
    filename = cols[2]
    return if filename is "total"
    return unless filename
    elements = filename.split(/[\/\\]/)
    current = json
    elements.forEach (element) ->
      current[element] = {}  unless current[element]
      current = current[element]

    if current[current_author.email]
      current[current_author.email].add += add
      current[current_author.email].del += del
    else
      current[current_author.email] = {}
      current[current_author.email].add = add
      current[current_author.email].del = del

  json.children = getChildren(json)
  Visualisation.json = json
  json

getChildren = (json) ->
  children = []
  return children  if json.language
  for key of json
    child = name: key
    if json[key].add || json[key].del
      
      # value node
      child.add = json[key].add
      child.del = json[key].del
      child.language = json[key].language
    else
      
      # children node
      childChildren = getChildren(json[key])
      child.children = childChildren  if childChildren
    children.push child
    delete json[key]
  children

getChildrenWithAuthor = (json) ->
  children = []
  return children  if json.language
  for key of json
    child = name: key
    if json[key].add || json[key].del
      
      # value node
      child.add = json[key].add
      child.del = json[key].del
      child.language = json[key].language
    else
      
      # children node
      childChildren = getChildren(json[key])
      child.children = childChildren  if childChildren
    children.push child
    delete json[key]
  children


# Recursively count all elements in a tree
countElements = (node) ->
  nbElements = 1
  if node.children
    nbElements += node.children.reduce((p, v) ->
      p + countElements(v)
    , 0)
  nbElements